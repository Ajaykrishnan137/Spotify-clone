import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/song_model.dart';
import '../data/remote/supabase_songs_repository.dart';

class CloudCatalogService {
  List<SongModel>? _cachedSongs;

  Future<List<SongModel>> getCatalog() async {
    if (_cachedSongs != null && _cachedSongs!.isNotEmpty) {
      return _cachedSongs!;
    }

    try {
      final jsonString = await rootBundle.loadString('assets/songs_cloud_catalog.json');
      final List<dynamic> list = json.decode(jsonString) as List<dynamic>;
      _cachedSongs = list.map((item) {
        final map = item as Map<String, dynamic>;
        return SongModel(
          id: map['id'] as String,
          title: map['title'] as String,
          artist: map['artist'] as String,
          album: map['album'] as String,
          durationMs: map['duration_ms'] as int? ?? 0,
          coverUrl: map['cover_url'] as String? ?? 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=500&q=80',
          storagePath: map['storage_path'] as String,
          genre: map['genre'] as String? ?? 'General',
          localPath: map['local_path'] as String?,
        );
      }).toList();
      return _cachedSongs!;
    } catch (_) {
      return [];
    }
  }

  Future<List<SongModel>> getSongsByGenre(String genre) async {
    final all = await getCatalog();
    return all.where((s) => s.genre.toLowerCase() == genre.toLowerCase()).toList();
  }

  Future<List<SongModel>> searchSongs(String query) async {
    if (query.trim().isEmpty) return [];
    final all = await getCatalog();
    final q = query.toLowerCase();
    return all.where((s) =>
      s.title.toLowerCase().contains(q) ||
      s.artist.toLowerCase().contains(q) ||
      s.album.toLowerCase().contains(q)
    ).toList();
  }
}

final cloudCatalogServiceProvider = Provider<CloudCatalogService>((ref) {
  return CloudCatalogService();
});

final allSongsProvider = FutureProvider<List<SongModel>>((ref) async {
  final catalogService = ref.watch(cloudCatalogServiceProvider);
  return catalogService.getCatalog();
});
