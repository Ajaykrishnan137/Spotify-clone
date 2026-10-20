import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/playlist_model.dart';
import '../../models/song_model.dart';
import '../../data/local/database.dart';
import '../../data/local/daos/playlists_dao.dart';
import '../../data/local/daos/songs_dao.dart';
import '../core/services/playlist_storage_service.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  return AppDatabase();
});

final playlistsDaoProvider = Provider<PlaylistsDao>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return PlaylistsDao(db);
});

final songsDaoProvider = Provider<SongsDao>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return SongsDao(db);
});

class LocalPlaylistController extends StateNotifier<AsyncValue<List<PlaylistModel>>> {
  final PlaylistsDao _playlistsDao;
  final PlaylistStorageService _storageService;
  Map<String, CustomPlaylistData> _cache = {};

  LocalPlaylistController(this._playlistsDao, this._storageService)
      : super(const AsyncValue.loading()) {
    loadPlaylists();
  }

  Future<void> loadPlaylists() async {
    try {
      _cache = await _storageService.loadAllPlaylists();
      
      // Also sync from SQLite if any exist
      try {
        final dbList = await _playlistsDao.getUserPlaylists();
        for (final pl in dbList) {
          if (!_cache.containsKey(pl.id)) {
            final songs = await _playlistsDao.getPlaylistSongs(pl.id);
            _cache[pl.id] = CustomPlaylistData(
              playlist: pl.copyWith(songCount: songs.length),
              songs: songs,
            );
          }
        }
      } catch (_) {}

      final list = _cache.values.map((cp) => cp.playlist.copyWith(
        songCount: cp.songs.length,
        coverUrl: cp.songs.isNotEmpty ? cp.songs.first.coverUrl : cp.playlist.coverUrl,
      )).toList();

      state = AsyncValue.data(list);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> createPlaylist(String name, {List<SongModel>? initialSongs, String? id}) async {
    final playlistId = id ?? DateTime.now().millisecondsSinceEpoch.toString();
    final songs = initialSongs ?? [];
    final newPlaylist = PlaylistModel(
      id: playlistId,
      ownerId: 'local-user',
      name: name,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      songCount: songs.length,
      coverUrl: songs.isNotEmpty ? songs.first.coverUrl : null,
    );

    _cache[playlistId] = CustomPlaylistData(playlist: newPlaylist, songs: songs);
    await _storageService.saveAllPlaylists(_cache);

    try {
      await _playlistsDao.upsertPlaylist(newPlaylist);
      for (int i = 0; i < songs.length; i++) {
        await _playlistsDao.addSongToPlaylist(playlistId, songs[i].id, i);
      }
    } catch (_) {}

    await loadPlaylists();
  }

  Future<void> renamePlaylist(String id, String newName) async {
    if (_cache.containsKey(id)) {
      final existing = _cache[id]!;
      final updated = existing.playlist.copyWith(name: newName, updatedAt: DateTime.now());
      _cache[id] = CustomPlaylistData(playlist: updated, songs: existing.songs);
      await _storageService.saveAllPlaylists(_cache);
    }

    try {
      await _playlistsDao.upsertPlaylist(PlaylistModel(
        id: id,
        ownerId: 'local-user',
        name: newName,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));
    } catch (_) {}

    await loadPlaylists();
  }

  Future<void> deletePlaylist(String id) async {
    _cache.remove(id);
    await _storageService.saveAllPlaylists(_cache);
    try {
      await _playlistsDao.deletePlaylist(id);
    } catch (_) {}
    await loadPlaylists();
  }

  Future<void> addSongToPlaylist(String playlistId, SongModel song) async {
    if (_cache.containsKey(playlistId)) {
      final existing = _cache[playlistId]!;
      final list = List<SongModel>.from(existing.songs)..add(song);
      final updatedPl = existing.playlist.copyWith(
        songCount: list.length,
        coverUrl: list.isNotEmpty ? list.first.coverUrl : existing.playlist.coverUrl,
        updatedAt: DateTime.now(),
      );
      _cache[playlistId] = CustomPlaylistData(playlist: updatedPl, songs: list);
      await _storageService.saveAllPlaylists(_cache);
    }

    try {
      await _playlistsDao.addSongToPlaylist(playlistId, song.id, DateTime.now().millisecondsSinceEpoch);
    } catch (_) {}

    await loadPlaylists();
  }

  Future<void> addMultipleSongsToPlaylist(String playlistId, List<SongModel> songs) async {
    if (_cache.containsKey(playlistId)) {
      final existing = _cache[playlistId]!;
      final list = List<SongModel>.from(existing.songs)..addAll(songs);
      final updatedPl = existing.playlist.copyWith(
        songCount: list.length,
        coverUrl: list.isNotEmpty ? list.first.coverUrl : existing.playlist.coverUrl,
        updatedAt: DateTime.now(),
      );
      _cache[playlistId] = CustomPlaylistData(playlist: updatedPl, songs: list);
      await _storageService.saveAllPlaylists(_cache);
    }

    try {
      for (final song in songs) {
        await _playlistsDao.addSongToPlaylist(playlistId, song.id, DateTime.now().millisecondsSinceEpoch);
      }
    } catch (_) {}

    await loadPlaylists();
  }

  Future<void> removeSongFromPlaylist(String playlistId, String songId) async {
    if (_cache.containsKey(playlistId)) {
      final existing = _cache[playlistId]!;
      final list = List<SongModel>.from(existing.songs)..removeWhere((s) => s.id == songId);
      final updatedPl = existing.playlist.copyWith(
        songCount: list.length,
        coverUrl: list.isNotEmpty ? list.first.coverUrl : null,
        updatedAt: DateTime.now(),
      );
      _cache[playlistId] = CustomPlaylistData(playlist: updatedPl, songs: list);
      await _storageService.saveAllPlaylists(_cache);
    }

    try {
      await _playlistsDao.removeSongFromPlaylist(playlistId, songId);
    } catch (_) {}

    await loadPlaylists();
  }

  Future<void> reorderSongs(String playlistId, int oldIndex, int newIndex) async {
    if (!_cache.containsKey(playlistId)) return;
    final existing = _cache[playlistId]!;
    final list = List<SongModel>.from(existing.songs);
    if (oldIndex < 0 || oldIndex >= list.length) return;
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    final moved = list.removeAt(oldIndex);
    list.insert(newIndex, moved);

    final updatedPl = existing.playlist.copyWith(
      coverUrl: list.isNotEmpty ? list.first.coverUrl : null,
      updatedAt: DateTime.now(),
    );
    _cache[playlistId] = CustomPlaylistData(playlist: updatedPl, songs: list);
    await _storageService.saveAllPlaylists(_cache);
    await loadPlaylists();
  }

  Future<void> setPlaylistSongs(String playlistId, List<SongModel> songs) async {
    if (!_cache.containsKey(playlistId)) return;
    final existing = _cache[playlistId]!;
    final updatedPl = existing.playlist.copyWith(
      songCount: songs.length,
      coverUrl: songs.isNotEmpty ? songs.first.coverUrl : null,
      updatedAt: DateTime.now(),
    );
    _cache[playlistId] = CustomPlaylistData(playlist: updatedPl, songs: songs);
    await _storageService.saveAllPlaylists(_cache);
    await loadPlaylists();
  }

  Future<List<SongModel>> getPlaylistSongs(String playlistId) async {
    if (_cache.containsKey(playlistId)) {
      return _cache[playlistId]!.songs;
    }
    try {
      return await _playlistsDao.getPlaylistSongs(playlistId);
    } catch (_) {
      return [];
    }
  }

  bool hasPlaylist(String playlistId) {
    return _cache.containsKey(playlistId);
  }
}

final localPlaylistControllerProvider =
    StateNotifierProvider<LocalPlaylistController, AsyncValue<List<PlaylistModel>>>((ref) {
  final dao = ref.watch(playlistsDaoProvider);
  final storage = ref.watch(playlistStorageServiceProvider);
  return LocalPlaylistController(dao, storage);
});
