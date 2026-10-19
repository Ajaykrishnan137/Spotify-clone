import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../models/song_model.dart';
import 'online_music_search_service.dart';

class LegalSearchEngineService {
  LegalSearchEngineService._();

  static final Map<String, List<SongModel>> _cache = {};

  /// Normalizes text: lowercases, removes accents, ignores punctuation
  static String normalize(String input) {
    var text = input.toLowerCase().trim();
    const withAccents = 'áàảãạăắằẳẵặâấầẩẫậéèẻẽẹêếềểễệíìỉĩịóòỏõọôốồổỗộơớờởỡợúùủũụưứừửữựýỳỷỹỵđ';
    const withoutAccents = 'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyyd';
    for (int i = 0; i < withAccents.length; i++) {
      text = text.replaceAll(withAccents[i], withoutAccents[i]);
    }
    text = text.replaceAll(RegExp(r'''[.,\/#!$%\^&\*;:{}=\-_`~()?'"\[\]]'''), ' ');
    return text.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// Calculates a fuzzy similarity score between query and target (0.0 to 1.0)
  static double similarityScore(String queryNorm, String targetNorm) {
    if (queryNorm.isEmpty || targetNorm.isEmpty) return 0.0;
    if (targetNorm == queryNorm) return 1.0;
    if (targetNorm.startsWith(queryNorm)) return 0.9;
    if (targetNorm.contains(queryNorm)) return 0.8;

    // Word intersection score
    final qWords = queryNorm.split(' ');
    final tWords = targetNorm.split(' ');
    int matches = 0;
    for (final q in qWords) {
      if (tWords.any((t) => t.contains(q) || q.contains(t))) {
        matches++;
      }
    }
    if (qWords.isNotEmpty) {
      return (matches / qWords.length) * 0.7;
    }
    return 0.0;
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
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!;
    }

    final queryNorm = normalize(cleanQuery);

    // 1. Query all legal sources in parallel
    final results = await Future.wait([
      _searchLocal(localCatalog, queryNorm),
      _searchJamendo(cleanQuery),
      _searchInternetArchive(cleanQuery),
      OnlineMusicSearchService.searchOnline(cleanQuery),
    ]);

    final List<SongModel> localSongs = results[0];
    final List<SongModel> jamendoSongs = results[1];
    final List<SongModel> archiveSongs = results[2];
    final List<SongModel> licensedOnline = results[3];

    // 2. Merge all sources
    final List<SongModel> rawMerged = [
      ...localSongs,
      ...licensedOnline,
      ...jamendoSongs,
      ...archiveSongs,
    ];

    // 3. Deduplicate by normalized Title + Artist
    final Map<String, SongModel> dedup = {};
    for (final song in rawMerged) {
      final key = '${normalize(song.title)}|||${normalize(song.artist)}';
      if (!dedup.containsKey(key)) {
        dedup[key] = song;
      }
    }

    var merged = dedup.values.toList();

    // 4. Rank by relevance
    merged.sort((a, b) {
      final scoreA = similarityScore(queryNorm, normalize('${a.title} ${a.artist} ${a.album} ${a.genre}'));
      final scoreB = similarityScore(queryNorm, normalize('${b.title} ${b.artist} ${b.album} ${b.genre}'));
      return scoreB.compareTo(scoreA);
    });

    // 5. Apply user filters (source, quality, language)
    if (sourceFilter != null && sourceFilter.isNotEmpty && sourceFilter != 'All') {
      merged = merged.where((s) => s.genre.toLowerCase().contains(sourceFilter.toLowerCase())).toList();
    }
    if (qualityFilter != null && qualityFilter.isNotEmpty && qualityFilter != 'All') {
      if (qualityFilter == 'Lossless') {
        merged = merged.where((s) => s.storagePath.endsWith('.flac')).toList();
      } else if (qualityFilter == 'High (320kbps)') {
        merged = merged.where((s) => !s.storagePath.endsWith('_96.mp4')).toList();
      }
    }

    _cache[cacheKey] = merged;
    return merged;
  }

  // Source 1: Local library search (offline guaranteed, matches song title, artist, album/movie, playlist/genre)
  static Future<List<SongModel>> _searchLocal(List<SongModel> catalog, String queryNorm) async {
    return catalog.where((s) {
      final combined = normalize('${s.title} ${s.artist} ${s.album} ${s.genre}');
      return similarityScore(queryNorm, combined) >= 0.35 || combined.contains(queryNorm);
    }).toList();
  }

  // Source 2: Jamendo Free Music API (Legal Creative Commons / Free Music)
  static Future<List<SongModel>> _searchJamendo(String query) async {
    try {
      final url = Uri.parse(
        'https://api.jamendo.com/v3.0/tracks/?client_id=56d30c95&format=json&limit=15&namesearch=${Uri.encodeComponent(query)}&include=musicinfo&audioformat=mp32',
      );
      final res = await http.get(url).timeout(const Duration(seconds: 4));
      if (res.statusCode != 200) return [];
      final data = json.decode(res.body);
      final results = data['results'] as List?;
      if (results == null) return [];

      return results.map((item) {
        return SongModel(
          id: 'jamendo_${item["id"]}',
          title: item['name'] ?? 'Track',
          artist: item['artist_name'] ?? 'Jamendo Artist',
          album: item['album_name'] ?? 'Creative Commons',
          durationMs: ((item['duration'] as num? ?? 180) * 1000).toInt(),
          coverUrl: item['album_image'] ?? item['image'] ?? 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=500&q=80',
          storagePath: item['audio'] ?? '',
          genre: 'Jamendo (Legal CC)',
        );
      }).where((s) => s.storagePath.isNotEmpty).toList();
    } catch (_) {
      return [];
    }
  }

  // Source 3: Internet Archive Live Music & Audio (Public Domain / Legal Archive)
  static Future<List<SongModel>> _searchInternetArchive(String query) async {
    try {
      final queryEncoded = Uri.encodeComponent('$query AND mediatype:(audio)');
      final url = Uri.parse('https://archive.org/advancedsearch.php?q=$queryEncoded&fl[]=identifier,title,creator,collection,year&sort[]=&rows=12&page=1&output=json');
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
          ),
        );
      }
      return songs;
    } catch (_) {
      return [];
    }
  }
}
