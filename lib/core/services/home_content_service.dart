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
      avatarUrl: 'https://images.unsplash.com/photo-1516450360452-9312f5e86fc7?w=300&q=80',
    ),
    ArtistInfo(
      name: 'Pradeep Kumar',
      avatarUrl: 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=300&q=80',
    ),
    ArtistInfo(
      name: 'Harris Jayaraj',
      avatarUrl: 'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=300&q=80',
    ),
    ArtistInfo(
      name: 'Sai Abhyankar',
      avatarUrl: 'https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?w=300&q=80',
    ),
    ArtistInfo(
      name: 'Anirudh Ravichander',
      avatarUrl: 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=300&q=80',
    ),
    ArtistInfo(
      name: 'Lana Del Rey',
      avatarUrl: 'https://images.unsplash.com/photo-1526478806334-5fd488fcaabc?w=300&q=80',
    ),
    ArtistInfo(
      name: 'A.R. Rahman',
      avatarUrl: 'https://images.unsplash.com/photo-1465847899084-d164df4dedc6?w=300&q=80',
    ),
    ArtistInfo(
      name: 'K.S. Chithra',
      avatarUrl: 'https://images.unsplash.com/photo-1508700115892-45ecd05ae2ad?w=300&q=80',
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
