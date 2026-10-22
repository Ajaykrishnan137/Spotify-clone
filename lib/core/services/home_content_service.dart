import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../../models/song_model.dart';
import 'online_music_search_service.dart';

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

class HomeContentService {
  HomeContentService._();

  static const String _tamilCacheFile = 'home_trending_tamil.json';
  static List<SongModel>? _memoryTamilCache;

  /// Curated popular artists from legal and global catalogs
  static const List<ArtistInfo> popularArtists = [
    ArtistInfo(
      name: 'Sid Sriram',
      avatarUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/2/22/Sid_Sriram_at_Mersal_Audio_Launch.jpg/500px-Sid_Sriram_at_Mersal_Audio_Launch.jpg',
    ),
    ArtistInfo(
      name: 'Pradeep Kumar',
      avatarUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/e/e0/Pradeep_Kumar_Singer.jpg/500px-Pradeep_Kumar_Singer.jpg',
    ),
    ArtistInfo(
      name: 'Harris Jayaraj',
      avatarUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/9/90/Harris_Jayaraj_at_Kaappaan_Audio_Launch.jpg/500px-Harris_Jayaraj_at_Kaappaan_Audio_Launch.jpg',
    ),
    ArtistInfo(
      name: 'Sai Abhyankar',
      avatarUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/d/d4/Sai_Abhyankkar.jpg/500px-Sai_Abhyankkar.jpg',
    ),
    ArtistInfo(
      name: 'Anirudh Ravichander',
      avatarUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/9/97/Anirudh_Ravichander_at_Audi_Ritz_Style_Awards_2015.jpg/500px-Anirudh_Ravichander_at_Audi_Ritz_Style_Awards_2015.jpg',
    ),
    ArtistInfo(
      name: 'Lana Del Rey',
      avatarUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/4/4c/Lana_Del_Rey_at_the_2019_Grammy_Awards.jpg/500px-Lana_Del_Rey_at_the_2019_Grammy_Awards.jpg',
    ),
    ArtistInfo(
      name: 'A.R. Rahman',
      avatarUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/b/b3/A._R._Rahman_at_the_Global_Indian_Music_Awards_2012.jpg/500px-A._R._Rahman_at_the_Global_Indian_Music_Awards_2012.jpg',
    ),
    ArtistInfo(
      name: 'K.S. Chithra',
      avatarUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/7/7b/K._S._Chithra_2019.jpg/500px-K._S._Chithra_2019.jpg',
    ),
  ];

  /// Auto-generated mixes for "Made for you"
  static List<Map<String, dynamic>> getMadeForYouMixes(List<SongModel> history, List<SongModel> allCatalog) {
    return [
      {
        'title': 'Daily Mix 1',
        'subtitle': 'Acoustic & Melodies',
        'colors': [const Color(0xFF38D6FF), const Color(0xFF1E90FF), const Color(0xFF151B3B)],
        'songs': _extractSongsForKeywords(history, allCatalog, ['melody', 'acoustic', 'love', 'chill']),
      },
      {
        'title': 'Chill Mix',
        'subtitle': 'Relaxing rhythms & vibes',
        'colors': [const Color(0xFF00E676), const Color(0xFF00B0FF), const Color(0xFF0B1026)],
        'songs': _extractSongsForKeywords(history, allCatalog, ['chill', 'peace', 'slow', 'breeze']),
      },
      {
        'title': 'Throwback Mix',
        'subtitle': 'Timeless hits you love',
        'colors': [const Color(0xFFFF6B6B), const Color(0xFF7C4DFF), const Color(0xFF0B1026)],
        'songs': _extractSongsForKeywords(history, allCatalog, ['hits', 'classic', 'harris', 'rey']),
      },
      {
        'title': 'Focus Flow',
        'subtitle': 'Instruments & concentration',
        'colors': [const Color(0xFFFFC857), const Color(0xFFFF7043), const Color(0xFF151B3B)],
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

  /// Load Trending Tamil songs loaded online from global search with daily caching
  static Future<List<SongModel>> getTrendingTamilSongs() async {
    if (_memoryTamilCache != null && _memoryTamilCache!.isNotEmpty) {
      return _memoryTamilCache!;
    }

    try {
      final dir = await getApplicationDocumentsDirectory();
      final cacheFile = File(p.join(dir.path, _tamilCacheFile));

      // Read from disk cache if fresh (within 24 hours)
      if (cacheFile.existsSync()) {
        final lastModified = cacheFile.lastModifiedSync();
        final isFresh = DateTime.now().difference(lastModified).inHours < 24;
        final raw = await cacheFile.readAsString();
        if (raw.isNotEmpty) {
          final List<dynamic> list = jsonDecode(raw);
          final cachedSongs = list.map((e) => SongModel.fromJson(e as Map<String, dynamic>)).toList();
          if (cachedSongs.isNotEmpty) {
            _memoryTamilCache = cachedSongs;
            if (isFresh) {
              return cachedSongs;
            }
          }
        }
      }

      // Fetch fresh online results
      final onlineSongs = await OnlineMusicSearchService.searchOnline('Tamil Trending Hits', limit: 20);
      if (onlineSongs.isNotEmpty) {
        _memoryTamilCache = onlineSongs;
        await cacheFile.writeAsString(
          jsonEncode(onlineSongs.map((s) => s.toJson()).toList()),
          flush: true,
        );
        return onlineSongs;
      }
    } catch (_) {}

    return _memoryTamilCache ?? [];
  }
}

final homeContentServiceProvider = Provider<HomeContentService>((ref) {
  return HomeContentService._();
});
