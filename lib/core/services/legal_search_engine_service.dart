import 'dart:convert';
import 'dart:developer' as dev;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../models/song_model.dart';
import 'online_music_search_service.dart';
import 'fuzzy_matcher.dart';
import 'query_intent_engine.dart';
import 'local_search_index.dart';

class SearchStreamBatch {
  final List<SongModel> songs;
  final bool isInitialLocalOrCached;
  final bool isComplete;
  final String sourceName;

  const SearchStreamBatch({
    required this.songs,
    required this.isInitialLocalOrCached,
    required this.isComplete,
    required this.sourceName,
  });
}

class LegalSearchEngineService {
  LegalSearchEngineService._();

  static final http.Client _sharedClient = http.Client();

  // In-memory LRU cache of recent queries and results (10 to 30 min duration)
  static final Map<String, List<SongModel>> _cache = {};
  static final Map<String, DateTime> _cacheTimestamp = {};
  static const int _cacheDurationMinutes = 20;

  static String normalize(String input) {
    return FuzzyMatcher.normalize(input);
  }

  static double similarityScore(String queryNorm, String targetNorm) {
    return FuzzyMatcher.computeCombinedFuzzyScore(queryNorm, targetNorm);
  }

  /// Instant lookup from in-memory cache if available and fresh (< 20 mins)
  static List<SongModel>? getCachedResults(
    String query, {
    String? languageFilter,
    String? sourceFilter,
    String? qualityFilter,
  }) {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return null;
    final cacheKey = '$cleanQuery|$languageFilter|$sourceFilter|$qualityFilter';

    if (_cache.containsKey(cacheKey) && _cacheTimestamp.containsKey(cacheKey)) {
      final age = DateTime.now().difference(_cacheTimestamp[cacheKey]!);
      if (age.inMinutes < _cacheDurationMinutes) {
        return _cache[cacheKey];
      }
    }
    return null;
  }

  /// Progressive search stream: yields local & cached data instantly, then yields batches as network sources resolve
  static Stream<SearchStreamBatch> searchAllSourcesProgressive({
    required String query,
    required List<SongModel> localCatalog,
    String? languageFilter,
    String? sourceFilter,
    String? qualityFilter,
  }) async* {
    final stopwatch = Stopwatch()..start();
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) {
      yield const SearchStreamBatch(songs: [], isInitialLocalOrCached: true, isComplete: true, sourceName: 'empty');
      return;
    }

    final cacheKey = '$cleanQuery|$languageFilter|$sourceFilter|$qualityFilter';

    // 1. Instantly yield cached results if fresh
    final cached = getCachedResults(query, languageFilter: languageFilter, sourceFilter: sourceFilter, qualityFilter: qualityFilter);
    if (cached != null && cached.isNotEmpty) {
      dev.log('[SearchTiming] Time to cached result for "$cleanQuery": ${stopwatch.elapsedMilliseconds} ms (${cached.length} songs)');
      yield SearchStreamBatch(
        songs: cached,
        isInitialLocalOrCached: true,
        isComplete: false,
        sourceName: 'cache',
      );
    }

    // 2. Pre-index local catalog if not already done, and perform instant local search
    LocalSearchIndex.buildIndex(localCatalog);
    final intent = QueryIntentEngine.analyzeQuery(cleanQuery);
    final isArtistStrict = intent.type == QueryIntentType.artistStrictQuery;
    final canonicalArtistNorm = isArtistStrict ? FuzzyMatcher.normalize(intent.matchedArtistName!) : '';

    List<SongModel> localHits;
    if (isArtistStrict) {
      localHits = LocalSearchIndex.searchArtistStrictFast(canonicalArtistNorm);
      if (localHits.isEmpty) {
        localHits = await _searchLocalArtistStrict(localCatalog, canonicalArtistNorm);
      }
    } else {
      localHits = LocalSearchIndex.searchFast(cleanQuery, limit: 30);
      if (localHits.isEmpty) {
        localHits = await _searchLocal(localCatalog, cleanQuery, intent);
      }
    }

    if (localHits.isNotEmpty && (cached == null || cached.isEmpty)) {
      dev.log('[SearchTiming] Time to first result (local) for "$cleanQuery": ${stopwatch.elapsedMilliseconds} ms (${localHits.length} songs)');
      yield SearchStreamBatch(
        songs: localHits,
        isInitialLocalOrCached: true,
        isComplete: false,
        sourceName: 'local',
      );
    }

    // 3. Launch external requests in parallel with strict 3.5s timeout per source
    final List<SongModel> mergedList = [...localHits];
    final Set<String> seenKeys = {
      ...localHits.map((s) => '${FuzzyMatcher.normalize(s.title)}|||${FuzzyMatcher.normalize(s.artist)}')
    };

    if (isArtistStrict) {
      final canonicalArtist = intent.matchedArtistName!;

      final futures = [
        OnlineMusicSearchService.searchOnline(canonicalArtist, limit: 30),
        _searchInternetArchive(canonicalArtist, intent),
      ];

      final results = await Future.wait(futures);
      final onlineSongs = results[0];
      final archiveSongs = results[1];

      final newItems = <SongModel>[];
      for (final s in [...onlineSongs, ...archiveSongs]) {
        if (_matchesArtistStrict(s.artist, canonicalArtistNorm)) {
          final key = '${FuzzyMatcher.normalize(s.title)}|||${FuzzyMatcher.normalize(s.artist)}';
          if (!seenKeys.contains(key)) {
            seenKeys.add(key);
            newItems.add(s);
          }
        }
      }

      mergedList.addAll(newItems);
      // Run sorting on background isolate to keep UI butter smooth
      final sorted = await compute(_sortArtistStrictIsolate, mergedList);

      _cache[cacheKey] = sorted;
      _cacheTimestamp[cacheKey] = DateTime.now();
      LocalSearchIndex.addSongsToIndex(sorted);

      dev.log('[SearchTiming] Time to full results for "$cleanQuery": ${stopwatch.elapsedMilliseconds} ms (${sorted.length} total)');
      yield SearchStreamBatch(
        songs: sorted,
        isInitialLocalOrCached: false,
        isComplete: true,
        sourceName: 'all_sources',
      );
    } else {
      String effectiveSearchTerm = cleanQuery;
      if (intent.type == QueryIntentType.playlistType && intent.tags.isNotEmpty) {
        if (cleanQuery.toLowerCase().contains('tamil')) {
          effectiveSearchTerm = 'tamil ${intent.tags.take(3).join(' ')}';
        } else {
          effectiveSearchTerm = intent.tags.take(3).join(' ');
        }
      }

      final futures = [
        OnlineMusicSearchService.searchOnline(cleanQuery, limit: 25),
        _searchJamendo(cleanQuery, intent),
        _searchInternetArchive(cleanQuery, intent),
        if (effectiveSearchTerm != cleanQuery)
          OnlineMusicSearchService.searchOnline(effectiveSearchTerm, limit: 20)
        else
          Future.value(<SongModel>[]),
      ];

      final results = await Future.wait(futures);
      final newItems = <SongModel>[];
      for (final r in results) {
        for (final song in r) {
          final key = '${FuzzyMatcher.normalize(song.title)}|||${FuzzyMatcher.normalize(song.artist)}';
          if (!seenKeys.contains(key)) {
            seenKeys.add(key);
            newItems.add(song);
          }
        }
      }

      mergedList.addAll(newItems);

      // Perform ranking and scoring off UI thread in isolate
      final sorted = await compute(
        _rankAndFilterIsolate,
        _IsolateSortParams(
          songs: mergedList.take(200).toList(),
          rawQuery: cleanQuery,
          queryNorm: FuzzyMatcher.normalize(cleanQuery),
          intentTypeIndex: intent.type.index,
          intentTags: intent.tags,
          intentGenres: intent.genres,
          sortMode: intent.sortMode,
          sourceFilter: sourceFilter,
          qualityFilter: qualityFilter,
        ),
      );

      _cache[cacheKey] = sorted;
      _cacheTimestamp[cacheKey] = DateTime.now();
      LocalSearchIndex.addSongsToIndex(sorted);

      dev.log('[SearchTiming] Time to full results for "$cleanQuery": ${stopwatch.elapsedMilliseconds} ms (${sorted.length} total)');
      yield SearchStreamBatch(
        songs: sorted,
        isInitialLocalOrCached: false,
        isComplete: true,
        sourceName: 'all_sources',
      );
    }
  }

  /// Fallback direct search implementation preserving synchronous backward compatibility
  static Future<List<SongModel>> searchAllSources({
    required String query,
    required List<SongModel> localCatalog,
    String? languageFilter,
    String? sourceFilter,
    String? qualityFilter,
  }) async {
    List<SongModel> last = const [];
    await for (final batch in searchAllSourcesProgressive(
      query: query,
      localCatalog: localCatalog,
      languageFilter: languageFilter,
      sourceFilter: sourceFilter,
      qualityFilter: qualityFilter,
    )) {
      last = batch.songs;
      if (batch.isComplete) break;
    }
    return last;
  }

  static bool _matchesArtistStrict(String songArtist, String canonicalArtistNorm) {
    final norm = FuzzyMatcher.normalize(songArtist);
    if (norm == canonicalArtistNorm) return true;

    final parts = songArtist.split(RegExp(r'[/,&+]|\bfeat\b|\bwith\b|\band\b', caseSensitive: false));
    for (final part in parts) {
      final pNorm = FuzzyMatcher.normalize(part);
      if (pNorm.isEmpty) continue;
      if (pNorm == canonicalArtistNorm) return true;

      final aliasMatch = QueryIntentEngine.matchArtistQuery(pNorm);
      if (aliasMatch != null && FuzzyMatcher.normalize(aliasMatch) == canonicalArtistNorm) {
        return true;
      }

      final sim = FuzzyMatcher.computeCombinedFuzzyScore(pNorm, canonicalArtistNorm);
      if (sim >= 0.85) return true;
    }
    return false;
  }

  static Future<List<SongModel>> _searchLocalArtistStrict(List<SongModel> catalog, String canonicalNorm) async {
    return catalog.where((s) {
      return _matchesArtistStrict(s.artist, canonicalNorm);
    }).map((s) => s.copyWith(source: 'Local Storage')).toList();
  }

  static Future<List<SongModel>> _searchLocal(List<SongModel> catalog, String rawQuery, QueryIntentResult intent) async {
    final queryNorm = FuzzyMatcher.normalize(rawQuery);

    return catalog.where((s) {
      final combined = '${s.title} ${s.artist} ${s.album} ${s.genre}';
      final score = FuzzyMatcher.computeCombinedFuzzyScore(rawQuery, combined);

      if (score >= 0.35 || FuzzyMatcher.normalize(combined).contains(queryNorm)) {
        return true;
      }

      if (intent.type == QueryIntentType.playlistType) {
        final cNorm = FuzzyMatcher.normalize(combined);
        for (final tag in intent.tags) {
          if (cNorm.contains(FuzzyMatcher.normalize(tag))) return true;
        }
        for (final g in intent.genres) {
          if (cNorm.contains(FuzzyMatcher.normalize(g))) return true;
        }
      }

      return false;
    }).map((s) => s.copyWith(source: 'Local Storage')).toList();
  }

  static Future<List<SongModel>> _searchJamendo(String query, QueryIntentResult intent) async {
    try {
      String searchParam = 'namesearch=${Uri.encodeComponent(query)}';
      String orderParam = 'order=popularity_total';

      if (intent.sortMode == 'latest') {
        orderParam = 'order=releasedate_desc';
      } else if (intent.sortMode == 'trending') {
        orderParam = 'order=popularity_month';
      }

      if (intent.type == QueryIntentType.playlistType && intent.tags.isNotEmpty) {
        final tag = intent.tags.first;
        searchParam = 'tags=${Uri.encodeComponent(tag)}';
      }

      final url = Uri.parse(
        'https://api.jamendo.com/v3.0/tracks/?client_id=56d30c95&format=json&limit=15&$searchParam&$orderParam&include=musicinfo&audioformat=mp32',
      );
      final res = await _sharedClient.get(url, headers: {
        'Accept': 'application/json',
        'Accept-Encoding': 'gzip, deflate',
        'Connection': 'keep-alive',
      }).timeout(const Duration(milliseconds: 3500));
      if (res.statusCode != 200) return [];
      final data = json.decode(res.body);
      final results = data['results'] as List?;
      if (results == null) return [];

      return results.map((item) {
        final releaseDate = (item['releasedate'] ?? '').toString();
        final stats = item['stats'] as Map<String, dynamic>?;
        final popularity = (stats?['rate_listened_total'] as num?)?.toInt() ?? 1000;

        return SongModel(
          id: 'jamendo_${item["id"]}',
          title: item['name'] ?? 'Track',
          artist: item['artist_name'] ?? 'Jamendo Artist',
          album: item['album_name'] ?? 'Creative Commons',
          durationMs: ((item['duration'] as num? ?? 180) * 1000).toInt(),
          coverUrl: item['album_image'] ?? item['image'] ?? 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=500&q=80',
          storagePath: item['audio'] ?? '',
          genre: 'Jamendo (Legal CC)',
          releaseDate: releaseDate.isNotEmpty ? releaseDate : null,
          popularity: popularity,
          source: 'Jamendo (Creative Commons)',
        );
      }).where((s) => s.storagePath.isNotEmpty).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<List<SongModel>> _searchInternetArchive(String query, QueryIntentResult intent) async {
    try {
      String queryEncoded = Uri.encodeComponent('$query AND mediatype:(audio)');
      if (intent.type == QueryIntentType.playlistType && intent.tags.isNotEmpty) {
        final tag = intent.tags.first;
        queryEncoded = Uri.encodeComponent('($query OR $tag) AND mediatype:(audio)');
      }

      String sort = '';
      if (intent.sortMode == 'latest') {
        sort = '&sort[]=publicdate+desc';
      } else if (intent.sortMode == 'trending') {
        sort = '&sort[]=downloads+desc';
      }

      final url = Uri.parse(
        'https://archive.org/advancedsearch.php?q=$queryEncoded&fl[]=identifier,title,creator,collection,year,downloads&rows=15&page=1$sort&output=json',
      );
      final res = await _sharedClient.get(url, headers: {
        'Accept': 'application/json',
        'Accept-Encoding': 'gzip, deflate',
        'Connection': 'keep-alive',
      }).timeout(const Duration(milliseconds: 3500));
      if (res.statusCode != 200) return [];
      final data = json.decode(res.body);
      final docs = data['response']?['docs'] as List?;
      if (docs == null) return [];

      final List<SongModel> songs = [];
      for (final doc in docs) {
        final id = doc['identifier']?.toString() ?? '';
        final title = doc['title']?.toString() ?? 'Archive Audio';
        final creator = doc['creator']?.toString() ?? 'Internet Archive';
        final year = doc['year']?.toString();
        final downloads = int.tryParse(doc['downloads']?.toString() ?? '0') ?? 500;
        if (id.isEmpty) continue;

        songs.add(
          SongModel(
            id: 'archive_$id',
            title: title,
            artist: creator,
            album: 'Internet Archive Public Domain',
            durationMs: 240000,
            coverUrl: 'https://archive.org/services/img/$id',
            storagePath: 'https://archive.org/download/$id/$id.mp3',
            genre: 'Internet Archive (Legal)',
            releaseDate: year,
            popularity: downloads,
            source: 'Internet Archive (Public Domain)',
          ),
        );
      }
      return songs;
    } catch (_) {
      return [];
    }
  }
}

// -------------------------------------------------------------
// BACKGROUND ISOLATE HELPERS FOR HEAVY SCORING & SORTING
// -------------------------------------------------------------
List<SongModel> _sortArtistStrictIsolate(List<SongModel> songs) {
  final copy = List<SongModel>.from(songs);
  copy.sort((a, b) => b.popularity.compareTo(a.popularity));
  return copy;
}

class _IsolateSortParams {
  final List<SongModel> songs;
  final String rawQuery;
  final String queryNorm;
  final int intentTypeIndex;
  final List<String> intentTags;
  final List<String> intentGenres;
  final String? sortMode;
  final String? sourceFilter;
  final String? qualityFilter;

  const _IsolateSortParams({
    required this.songs,
    required this.rawQuery,
    required this.queryNorm,
    required this.intentTypeIndex,
    required this.intentTags,
    required this.intentGenres,
    this.sortMode,
    this.sourceFilter,
    this.qualityFilter,
  });
}

List<SongModel> _rankAndFilterIsolate(_IsolateSortParams params) {
  var list = List<SongModel>.from(params.songs);

  if (params.sourceFilter != null && params.sourceFilter!.isNotEmpty && params.sourceFilter != 'All') {
    final filter = params.sourceFilter!.toLowerCase();
    list = list.where((s) {
      final g = s.genre.toLowerCase();
      final src = (s.source ?? '').toLowerCase();
      return g.contains(filter) || src.contains(filter);
    }).toList();
  }

  if (params.qualityFilter != null && params.qualityFilter!.isNotEmpty && params.qualityFilter != 'All') {
    if (params.qualityFilter == 'Lossless') {
      list = list.where((s) => s.storagePath.endsWith('.flac')).toList();
    } else if (params.qualityFilter == 'High (320kbps)') {
      list = list.where((s) => !s.storagePath.endsWith('_96.mp4')).toList();
    }
  }

  list.sort((a, b) {
    final scoreA = _calculateScore(a, params);
    final scoreB = _calculateScore(b, params);
    return scoreB.compareTo(scoreA);
  });

  return list;
}

double _calculateScore(SongModel song, _IsolateSortParams params) {
  final titleNorm = FuzzyMatcher.normalize(song.title);
  final artistNorm = FuzzyMatcher.normalize(song.artist);
  final albumNorm = FuzzyMatcher.normalize(song.album);
  final genreNorm = FuzzyMatcher.normalize(song.genre);
  final combinedNorm = '$titleNorm $artistNorm $albumNorm $genreNorm';

  double relevanceScore = 0.0;
  if (titleNorm == params.queryNorm || combinedNorm.contains(params.queryNorm)) {
    relevanceScore += 1.0;
  } else if (titleNorm.startsWith(params.queryNorm)) {
    relevanceScore += 0.85;
  } else {
    relevanceScore += FuzzyMatcher.computeCombinedFuzzyScore(params.rawQuery, combinedNorm);
  }

  if (params.intentTypeIndex == QueryIntentType.playlistType.index) {
    for (final tag in params.intentTags) {
      if (combinedNorm.contains(FuzzyMatcher.normalize(tag))) relevanceScore += 0.35;
    }
    for (final g in params.intentGenres) {
      if (genreNorm.contains(FuzzyMatcher.normalize(g)) || combinedNorm.contains(FuzzyMatcher.normalize(g))) {
        relevanceScore += 0.35;
      }
    }
  }

  double popularityBonus = 0.0;
  if (song.popularity > 0) {
    popularityBonus = (song.popularity / 500000.0).clamp(0.0, 0.4);
  }

  double recencyBonus = 0.0;
  if (song.releaseDate != null && song.releaseDate!.isNotEmpty) {
    final yearMatch = RegExp(r'\b(19\d\d|20\d\d)\b').firstMatch(song.releaseDate!);
    if (yearMatch != null) {
      final year = int.tryParse(yearMatch.group(1)!) ?? 0;
      final currentYear = 2026;
      if (year >= currentYear - 1) {
        recencyBonus = 0.5;
      } else if (year >= currentYear - 3) {
        recencyBonus = 0.3;
      } else if (year >= currentYear - 5) {
        recencyBonus = 0.15;
      }
    }
  }

  if (params.sortMode == 'latest') {
    return (recencyBonus * 2.0) + (relevanceScore * 0.5) + (popularityBonus * 0.3);
  } else if (params.sortMode == 'trending') {
    return (popularityBonus * 2.0) + (relevanceScore * 0.5) + (recencyBonus * 0.3);
  }

  return relevanceScore + (popularityBonus * 0.2) + (recencyBonus * 0.2);
}
