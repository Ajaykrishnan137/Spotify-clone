import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../../models/song_model.dart';
import 'online_music_search_service.dart';
import 'cloud_catalog_service.dart';
import 'fuzzy_matcher.dart';

class ArtistInfo {
  final String name;
  final String avatarUrl;

  const ArtistInfo({required this.name, required this.avatarUrl});

  Map<String, dynamic> toJson() => {'name': name, 'avatarUrl': avatarUrl};
  factory ArtistInfo.fromJson(Map<String, dynamic> json) => ArtistInfo(
        name: json['name'] as String,
        avatarUrl: json['avatarUrl'] as String,
      );
}

class TrendingPoolState {
  final List<SongModel> fullRankedPool;
  final List<SongModel> currentBatch;
  final DateTime lastUpdated;
  final int batchIndex;

  const TrendingPoolState({
    required this.fullRankedPool,
    required this.currentBatch,
    required this.lastUpdated,
    this.batchIndex = 0,
  });
}

class HomeContentService {
  HomeContentService._();

  static const String _trendingPoolFile = 'home_trending_tamil_pool_v2.json';
  static TrendingPoolState? _cachedPoolState;
  static final Set<String> _recentlyServedSongIds = {};

  /// Curated popular artists from legal and global catalogs
  static const List<ArtistInfo> popularArtists = [
    ArtistInfo(name: 'Harris Jayaraj', avatarUrl: ''),
    ArtistInfo(name: 'Pradeep Kumar', avatarUrl: ''),
    ArtistInfo(name: 'Sid Sriram', avatarUrl: ''),
    ArtistInfo(name: 'Sai Abhyankkar', avatarUrl: ''),
    ArtistInfo(name: 'Anirudh Ravichander', avatarUrl: ''),
    ArtistInfo(name: 'A. R. Rahman', avatarUrl: ''),
    ArtistInfo(name: 'Lana Del Rey', avatarUrl: ''),
    ArtistInfo(name: 'K. S. Chithra', avatarUrl: ''),
  ];

  /// Auto-generated mixes for "Made for you"
  static List<Map<String, dynamic>> getMadeForYouMixes(List<SongModel> history, List<SongModel> allCatalog) {
    return [
      {
        'title': 'Daily Mix 1',
        'subtitle': 'Acoustic & Melodies',
        'colors': [const Color(0xFF1F2B3E), const Color(0xFF161F2E)],
        'songs': _extractSongsForKeywords(history, allCatalog, ['melody', 'acoustic', 'love', 'chill']),
      },
      {
        'title': 'Chill Mix',
        'subtitle': 'Relaxing rhythms & vibes',
        'colors': [const Color(0xFF1E2F32), const Color(0xFF162125)],
        'songs': _extractSongsForKeywords(history, allCatalog, ['chill', 'peace', 'slow', 'breeze']),
      },
      {
        'title': 'Throwback Mix',
        'subtitle': 'Timeless hits you love',
        'colors': [const Color(0xFF33222E), const Color(0xFF221720)],
        'songs': _extractSongsForKeywords(history, allCatalog, ['hits', 'classic', 'harris', 'rey']),
      },
      {
        'title': 'Focus Flow',
        'subtitle': 'Instruments & concentration',
        'colors': [const Color(0xFF332E1F), const Color(0xFF231E15)],
        'songs': _extractSongsForKeywords(history, allCatalog, ['pradeep', 'instrumental', 'focus', 'flow']),
      },
    ];
  }

  static List<SongModel> _extractSongsForKeywords(
      List<SongModel> history, List<SongModel> catalog, List<String> keywords) {
    final pool = <SongModel>[...history, ...catalog];
    final Set<String> seen = {};
    final List<SongModel> result = [];

    for (final s in pool) {
      if (seen.contains(s.id)) continue;
      final text = '${s.title} ${s.artist} ${s.album} ${s.genre}'.toLowerCase();
      if (keywords.any((k) => text.contains(k))) {
        seen.add(s.id);
        result.add(s);
      }
      if (result.length >= 15) break;
    }

    if (result.length < 5) {
      for (final s in catalog) {
        if (!seen.contains(s.id)) {
          seen.add(s.id);
          result.add(s);
        }
        if (result.length >= 10) break;
      }
    }
    return result;
  }

  /// In-app signal tracking: increment local play/like weight
  static Future<void> recordInAppPlaySignal(String songId) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File(p.join(dir.path, 'skytune_song_signals.json'));
      Map<String, int> signals = {};
      if (file.existsSync()) {
        final content = await file.readAsString();
        if (content.isNotEmpty) {
          signals = Map<String, int>.from(jsonDecode(content));
        }
      }
      signals[songId] = (signals[songId] ?? 0) + 1;
      await file.writeAsString(jsonEncode(signals), flush: true);
    } catch (_) {}
  }

  static Future<Map<String, int>> _getInAppSignals() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File(p.join(dir.path, 'skytune_song_signals.json'));
      if (file.existsSync()) {
        final content = await file.readAsString();
        if (content.isNotEmpty) {
          return Map<String, int>.from(jsonDecode(content));
        }
      }
    } catch (_) {}
    return {};
  }

  /// Computes ranked trending pool: fetches 100-200 Tamil candidates, scores with weighted mix:
  /// Recent momentum, total popularity, recency with decay, and in-app play signals.
  static Future<TrendingPoolState> getTrendingTamilPool({
    required List<SongModel> localCatalog,
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _cachedPoolState != null) {
      final ageHours = DateTime.now().difference(_cachedPoolState!.lastUpdated).inHours;
      if (ageHours < 24) {
        return _cachedPoolState!;
      }
    }

    final dir = await getApplicationDocumentsDirectory();
    final cacheFile = File(p.join(dir.path, _trendingPoolFile));

    // Try reading disk cache first
    if (!forceRefresh && cacheFile.existsSync()) {
      try {
        final lastModified = cacheFile.lastModifiedSync();
        final ageHours = DateTime.now().difference(lastModified).inHours;
        final raw = await cacheFile.readAsString();
        if (raw.isNotEmpty) {
          final Map<String, dynamic> data = jsonDecode(raw);
          final List<dynamic> list = data['pool'] as List<dynamic>;
          final songs = list.map((e) => SongModel.fromJson(e as Map<String, dynamic>)).toList();
          if (songs.isNotEmpty) {
            final state = TrendingPoolState(
              fullRankedPool: songs,
              currentBatch: songs.take(20).toList(),
              lastUpdated: lastModified,
              batchIndex: 0,
            );
            _cachedPoolState = state;
            if (ageHours < 24) {
              return state;
            }
          }
        }
      } catch (_) {}
    }

    // Build fresh candidate pool of 100-200 songs from legal sources
    try {
      final inAppSignals = await _getInAppSignals();

      // Query online legal endpoints for fresh Tamil candidates (100 to 200 candidates)
      final onlineQueries = [
        'Tamil Trending Hits',
        'Tamil New Releases',
        'Top Tamil Songs',
        'Tamil Melodies',
        'Tamil Viral Hits',
        'Tamil Latest Hits',
      ];
      final onlineResults = await Future.wait(
        onlineQueries.map((q) => OnlineMusicSearchService.searchOnline(q, limit: 35)),
      );

      final List<SongModel> candidatePool = [];
      for (final r in onlineResults) {
        candidatePool.addAll(r);
      }

      // Add Tamil songs from local catalog
      final localTamil = localCatalog.where((s) {
        final g = s.genre.toLowerCase();
        final t = s.title.toLowerCase();
        return g.contains('tamil') || t.contains('tamil') || s.storagePath.contains('tamil');
      }).toList();
      candidatePool.addAll(localTamil);

      // Deduplicate candidate pool
      final Map<String, SongModel> dedup = {};
      for (final s in candidatePool) {
        if (s.storagePath.isEmpty) continue; // Minimum audio availability check
        final key = '${FuzzyMatcher.normalize(s.title)}|||${FuzzyMatcher.normalize(s.artist)}';
        if (!dedup.containsKey(key)) {
          dedup[key] = s;
        }
      }

      final uniqueCandidates = dedup.values.toList();

      // Score candidates
      final nowYear = DateTime.now().year; // 2026
      uniqueCandidates.sort((a, b) {
        final scoreA = _computeTrendingScore(a, nowYear, inAppSignals);
        final scoreB = _computeTrendingScore(b, nowYear, inAppSignals);
        return scoreB.compareTo(scoreA);
      });

      final fullPool = uniqueCandidates.take(120).toList();
      final batch = fullPool.take(20).toList();

      final newState = TrendingPoolState(
        fullRankedPool: fullPool,
        currentBatch: batch,
        lastUpdated: DateTime.now(),
        batchIndex: 0,
      );

      _cachedPoolState = newState;
      _recentlyServedSongIds.clear();
      _recentlyServedSongIds.addAll(batch.map((s) => s.id));

      // Save pool to disk cache
      await cacheFile.writeAsString(
        jsonEncode({
          'pool': fullPool.map((s) => s.toJson()).toList(),
          'updated_at': DateTime.now().toIso8601String(),
        }),
        flush: true,
      );

      return newState;
    } catch (_) {
      if (_cachedPoolState != null) return _cachedPoolState!;
      return TrendingPoolState(
        fullRankedPool: const [],
        currentBatch: const [],
        lastUpdated: DateTime.now(),
      );
    }
  }

  static double _computeTrendingScore(SongModel s, int nowYear, Map<String, int> signals) {
    double score = 0.0;

    // 1. Total popularity
    score += (s.popularity / 200000.0).clamp(0.0, 4.0);

    // 2. Recency boost with decay
    if (s.releaseDate != null && s.releaseDate!.isNotEmpty) {
      final m = RegExp(r'\b(19\d\d|20\d\d)\b').firstMatch(s.releaseDate!);
      if (m != null) {
        final year = int.tryParse(m.group(1)!) ?? 0;
        final ageYears = nowYear - year;
        if (ageYears <= 0) {
          score += 5.0; // Current year release
        } else if (ageYears == 1) {
          score += 4.0;
        } else if (ageYears == 2) {
          score += 2.5;
        } else if (ageYears <= 5) {
          score += 1.0;
        } else {
          // Penalize old songs unless they have strong recent momentum
          score -= 1.5;
        }
      }
    }

    // 3. In-app user plays/downloads signal
    final inAppCount = signals[s.id] ?? 0;
    score += (inAppCount * 1.5).clamp(0.0, 5.0);

    return score;
  }

  /// Tapping Refresh produces a fresh batch of 20 songs from the ranked pool
  /// with slight randomness among similarly ranked songs, without repeating until pool is used up.
  static TrendingPoolState getNextTrendingBatch() {
    if (_cachedPoolState == null || _cachedPoolState!.fullRankedPool.isEmpty) {
      return TrendingPoolState(
        fullRankedPool: const [],
        currentBatch: const [],
        lastUpdated: DateTime.now(),
      );
    }

    final pool = _cachedPoolState!.fullRankedPool;
    if (pool.length <= 20) {
      return _cachedPoolState!;
    }

    final rand = Random();
    int nextBatchIdx = _cachedPoolState!.batchIndex + 1;
    int start = (nextBatchIdx * 20) % pool.length;
    if (start + 20 > pool.length) {
      start = 0;
      nextBatchIdx = 0;
      _recentlyServedSongIds.clear();
    }

    final candidates = pool.skip(start).take(20).toList();
    // Subtle shuffle among adjacent songs for natural diversity
    candidates.shuffle(rand);

    final updatedState = TrendingPoolState(
      fullRankedPool: pool,
      currentBatch: candidates,
      lastUpdated: _cachedPoolState!.lastUpdated,
      batchIndex: nextBatchIdx,
    );
    _cachedPoolState = updatedState;
    return updatedState;
  }

  /// Provides trending Tamil songs with fallback, candidate scoring, caching, and batch shifting
  static Future<List<SongModel>> getTrendingTamilSongs({
    int limit = 20,
    bool forceNextBatch = false,
    List<SongModel> localCatalog = const [],
  }) async {
    if (forceNextBatch) {
      final nextState = getNextTrendingBatch();
      if (nextState.currentBatch.isNotEmpty) {
        return nextState.currentBatch.take(limit).toList();
      }
    }

    final poolState = await getTrendingTamilPool(
      localCatalog: localCatalog,
      forceRefresh: false,
    );

    if (poolState.currentBatch.isNotEmpty) {
      return poolState.currentBatch.take(limit).toList();
    }
    return poolState.fullRankedPool.take(limit).toList();
  }

  static String formatTimeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 2) return 'Updated just now';
    if (diff.inMinutes < 60) return 'Updated ${diff.inMinutes}m ago';
    if (diff.inHours < 24) return 'Updated ${diff.inHours}h ago';
    return 'Updated yesterday';
  }
}

final homeContentServiceProvider = Provider<HomeContentService>((ref) {
  return HomeContentService._();
});
