import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../models/song_model.dart';
import 'online_music_search_service.dart';
import 'fuzzy_matcher.dart';
import 'query_intent_engine.dart';

class LegalSearchEngineService {
  LegalSearchEngineService._();

  static final Map<String, List<SongModel>> _cache = {};
  static final Map<String, DateTime> _cacheTimestamp = {};

  /// Normalizes text using FuzzyMatcher
  static String normalize(String input) {
    return FuzzyMatcher.normalize(input);
  }

  /// Calculates a fuzzy similarity score between query and target (0.0 to 1.0)
  static double similarityScore(String queryNorm, String targetNorm) {
    return FuzzyMatcher.computeCombinedFuzzyScore(queryNorm, targetNorm);
  }

  /// Searches all legal sources in parallel, returning one continuous list of matching SongModels.
  /// Matches the query against song title, artist, album/movie name, and playlist/genre name.
  static Future<List<SongModel>> searchAllSources({
    required String query,
    required List<SongModel> localCatalog,
    String? languageFilter,
    String? sourceFilter,
    String? qualityFilter,
  }) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return const [];

    final cacheKey = '$cleanQuery|$languageFilter|$sourceFilter|$qualityFilter';
    if (_cache.containsKey(cacheKey) && _cacheTimestamp.containsKey(cacheKey)) {
      final age = DateTime.now().difference(_cacheTimestamp[cacheKey]!);
      if (age.inHours < 24) {
        return _cache[cacheKey]!;
      }
    }

    // 1. Analyze query intent
    final intent = QueryIntentEngine.analyzeQuery(cleanQuery);
    final queryNorm = FuzzyMatcher.normalize(cleanQuery);

    // Expand search keywords if mood/genre intent exists
    String effectiveSearchTerm = cleanQuery;
    if (intent.type == QueryIntentType.playlistType && intent.tags.isNotEmpty) {
      if (cleanQuery.toLowerCase().contains('tamil')) {
        effectiveSearchTerm = 'tamil ${intent.tags.take(3).join(' ')}';
      } else {
        effectiveSearchTerm = intent.tags.take(3).join(' ');
      }
    }

    // 2. Query all legal sources in parallel
    final results = await Future.wait([
      _searchLocal(localCatalog, cleanQuery, intent),
      _searchJamendo(cleanQuery, intent),
      _searchInternetArchive(cleanQuery, intent),
      OnlineMusicSearchService.searchOnline(cleanQuery, limit: 25),
      if (effectiveSearchTerm != cleanQuery)
        OnlineMusicSearchService.searchOnline(effectiveSearchTerm, limit: 20)
      else
        Future.value(<SongModel>[]),
    ]);

    final List<SongModel> localSongs = results[0];
    final List<SongModel> jamendoSongs = results[1];
    final List<SongModel> archiveSongs = results[2];
    final List<SongModel> licensedOnline = results[3];
    final List<SongModel> moodOnline = results[4];

    // 3. Merge all sources
    final List<SongModel> rawMerged = [
      ...localSongs,
      ...licensedOnline,
      ...moodOnline,
      ...jamendoSongs,
      ...archiveSongs,
    ];

    // 4. Deduplicate by normalized Title + Artist
    final Map<String, SongModel> dedup = {};
    for (final song in rawMerged) {
      final key = '${FuzzyMatcher.normalize(song.title)}|||${FuzzyMatcher.normalize(song.artist)}';
      if (!dedup.containsKey(key)) {
        dedup[key] = song;
      }
    }

    var merged = dedup.values.toList();

    // 5. Rank by a combined score: exact match, prefix match, fuzzy similarity, popularity, recency, source quality
    merged.sort((a, b) {
      final scoreA = _calculateRankingScore(a, cleanQuery, queryNorm, intent);
      final scoreB = _calculateRankingScore(b, cleanQuery, queryNorm, intent);
      return scoreB.compareTo(scoreA);
    });

    // 6. Apply user filters (source, quality, language)
    if (sourceFilter != null && sourceFilter.isNotEmpty && sourceFilter != 'All') {
      merged = merged.where((s) {
        final g = s.genre.toLowerCase();
        final src = (s.source ?? '').toLowerCase();
        final filter = sourceFilter.toLowerCase();
        return g.contains(filter) || src.contains(filter);
      }).toList();
    }
    if (qualityFilter != null && qualityFilter.isNotEmpty && qualityFilter != 'All') {
      if (qualityFilter == 'Lossless') {
        merged = merged.where((s) => s.storagePath.endsWith('.flac')).toList();
      } else if (qualityFilter == 'High (320kbps)') {
        merged = merged.where((s) => !s.storagePath.endsWith('_96.mp4')).toList();
      }
    }

    _cache[cacheKey] = merged;
    _cacheTimestamp[cacheKey] = DateTime.now();
    return merged;
  }

  /// Calculates combined ranking score for a song
  static double _calculateRankingScore(SongModel song, String rawQuery, String queryNorm, QueryIntentResult intent) {
    final titleNorm = FuzzyMatcher.normalize(song.title);
    final artistNorm = FuzzyMatcher.normalize(song.artist);
    final albumNorm = FuzzyMatcher.normalize(song.album);
    final genreNorm = FuzzyMatcher.normalize(song.genre);
    final combinedNorm = '$titleNorm $artistNorm $albumNorm $genreNorm';

    double relevanceScore = 0.0;

    // Exact match bonus
    if (titleNorm == queryNorm || combinedNorm.contains(queryNorm)) {
      relevanceScore += 1.0;
    } else if (titleNorm.startsWith(queryNorm)) {
      relevanceScore += 0.85;
    } else {
      relevanceScore += FuzzyMatcher.computeCombinedFuzzyScore(rawQuery, combinedNorm);
    }

    // Mood / Tag match bonus for playlist intent
    if (intent.type == QueryIntentType.playlistType) {
      for (final tag in intent.tags) {
        final tagNorm = FuzzyMatcher.normalize(tag);
        if (combinedNorm.contains(tagNorm)) {
          relevanceScore += 0.35;
        }
      }
      for (final g in intent.genres) {
        final gNorm = FuzzyMatcher.normalize(g);
        if (genreNorm.contains(gNorm) || combinedNorm.contains(gNorm)) {
          relevanceScore += 0.35;
        }
      }
    }

    // Popularity score (0.0 to 0.4)
    double popularityBonus = 0.0;
    if (song.popularity > 0) {
      popularityBonus = (song.popularity / 500000.0).clamp(0.0, 0.4);
    }

    // Recency score (0.0 to 0.5)
    double recencyBonus = 0.0;
    if (song.releaseDate != null && song.releaseDate!.isNotEmpty) {
      final yearMatch = RegExp(r'\b(19\d\d|20\d\d)\b').firstMatch(song.releaseDate!);
      if (yearMatch != null) {
        final year = int.tryParse(yearMatch.group(1)!) ?? 0;
        final currentYear = DateTime.now().year; // 2026
        if (year >= currentYear - 1) {
          recencyBonus = 0.5; // Last 12-24 months
        } else if (year >= currentYear - 3) {
          recencyBonus = 0.3;
        } else if (year >= currentYear - 5) {
          recencyBonus = 0.15;
        }
      }
    }

    // If query explicitly demands latest / trending, heavily weigh recency & popularity
    if (intent.sortMode == 'latest') {
      return (recencyBonus * 2.0) + (relevanceScore * 0.5) + (popularityBonus * 0.3);
    } else if (intent.sortMode == 'trending') {
      return (popularityBonus * 2.0) + (relevanceScore * 0.5) + (recencyBonus * 0.3);
    } else if (intent.sortMode == 'mixed') {
      return (recencyBonus * 1.5) + (popularityBonus * 1.5) + (relevanceScore * 0.6);
    }

    return relevanceScore + (popularityBonus * 0.2) + (recencyBonus * 0.2);
  }

  // Source 1: Local library search (offline guaranteed, matches song title, artist, album/movie, playlist/genre)
  static Future<List<SongModel>> _searchLocal(List<SongModel> catalog, String rawQuery, QueryIntentResult intent) async {
    final queryNorm = FuzzyMatcher.normalize(rawQuery);

    return catalog.where((s) {
      final combined = '${s.title} ${s.artist} ${s.album} ${s.genre}';
      final score = FuzzyMatcher.computeCombinedFuzzyScore(rawQuery, combined);

      if (score >= 0.35 || FuzzyMatcher.normalize(combined).contains(queryNorm)) {
        return true;
      }

      // Check intent tags
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

  // Source 2: Jamendo Free Music API (Legal Creative Commons / Free Music)
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
      final res = await http.get(url).timeout(const Duration(seconds: 4));
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

  // Source 3: Internet Archive Live Music & Audio (Public Domain / Legal Archive)
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
      final res = await http.get(url).timeout(const Duration(seconds: 4));
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
