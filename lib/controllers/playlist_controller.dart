import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/playlist_model.dart';
import '../../models/song_model.dart';
import '../../data/local/database.dart';
import '../../data/local/daos/playlists_dao.dart';
import '../../data/local/daos/songs_dao.dart';

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

final userPlaylistsStreamProvider = StreamProvider<List<PlaylistModel>>((ref) {
  final dao = ref.watch(playlistsDaoProvider);
  return dao.watchUserPlaylists();
});

class LocalPlaylistController extends StateNotifier<AsyncValue<List<PlaylistModel>>> {
  final PlaylistsDao _playlistsDao;

  LocalPlaylistController(this._playlistsDao) : super(const AsyncValue.loading()) {
    loadPlaylists();
  }

  Future<void> loadPlaylists() async {
    try {
      final list = await _playlistsDao.getUserPlaylists();
      state = AsyncValue.data(list);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> createPlaylist(String name) async {
    final newPlaylist = PlaylistModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      ownerId: 'local-user',
      name: name,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      songCount: 0,
      coverUrl: null,
    );
    await _playlistsDao.upsertPlaylist(newPlaylist);
    await loadPlaylists();
  }

  Future<void> deletePlaylist(String id) async {
    await _playlistsDao.deletePlaylist(id);
    await loadPlaylists();
  }

  Future<void> addSongToPlaylist(String playlistId, SongModel song) async {
    await _playlistsDao.addSongToPlaylist(playlistId, song.id, DateTime.now().millisecondsSinceEpoch);
    await loadPlaylists();
  }

  Future<List<SongModel>> getPlaylistSongs(String playlistId) async {
    return _playlistsDao.getPlaylistSongs(playlistId);
  }
}

final localPlaylistControllerProvider =
    StateNotifierProvider<LocalPlaylistController, AsyncValue<List<PlaylistModel>>>((ref) {
  final dao = ref.watch(playlistsDaoProvider);
  return LocalPlaylistController(dao);
});
