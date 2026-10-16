import 'package:drift/drift.dart';
import '../database.dart';
import '../../../models/playlist_model.dart';
import '../../../models/song_model.dart';

part 'playlists_dao.g.dart';

@DriftAccessor(tables: [Playlists, PlaylistSongs, Songs])
class PlaylistsDao extends DatabaseAccessor<AppDatabase> with _$PlaylistsDaoMixin {
  PlaylistsDao(AppDatabase db) : super(db);

  Stream<List<PlaylistModel>> watchUserPlaylists() {
    return select(playlists).watch().map((rows) => rows.map(_toPlaylistModel).toList());
  }

  Future<List<PlaylistModel>> getUserPlaylists() async {
    final rows = await select(playlists).get();
    return rows.map(_toPlaylistModel).toList();
  }

  Future<void> upsertPlaylist(PlaylistModel model) async {
    await into(playlists).insertOnConflictUpdate(
      PlaylistsCompanion.insert(
        id: model.id,
        ownerId: model.ownerId,
        name: model.name,
        coverUrl: Value(model.coverUrl),
        isLikedSongs: Value(model.isLikedSongs),
        createdAt: model.createdAt,
        updatedAt: model.updatedAt,
      ),
    );
  }

  Future<void> deletePlaylist(String id) async {
    await (delete(playlists)..where((tbl) => tbl.id.equals(id))).go();
  }

  Future<void> addSongToPlaylist(String playlistId, String songId, int position) async {
    await into(playlistSongs).insertOnConflictUpdate(
      PlaylistSongsCompanion.insert(
        playlistId: playlistId,
        songId: songId,
        position: Value(position),
        addedAt: DateTime.now(),
      ),
    );
  }

  Future<void> removeSongFromPlaylist(String playlistId, String songId) async {
    await (delete(playlistSongs)
          ..where((tbl) => tbl.playlistId.equals(playlistId) & tbl.songId.equals(songId)))
        .go();
  }

  Future<List<SongModel>> getPlaylistSongs(String playlistId) async {
    final query = select(playlistSongs).join([
      innerJoin(songs, songs.id.equalsExp(playlistSongs.songId)),
    ])..where(playlistSongs.playlistId.equals(playlistId))
      ..orderBy([OrderingTerm.asc(playlistSongs.position)]);

    final rows = await query.get();
    return rows.map((row) {
      final s = row.readTable(songs);
      return SongModel(
        id: s.id,
        title: s.title,
        artist: s.artist,
        album: s.album,
        durationMs: s.durationMs,
        coverUrl: s.coverUrl,
        storagePath: s.storagePath,
        fileHash: s.fileHash,
        localPath: s.localPath,
        isDownloaded: s.isDownloaded,
        downloadedAt: s.downloadedAt,
        genre: s.genre,
      );
    }).toList();
  }

  PlaylistModel _toPlaylistModel(Playlist p) {
    return PlaylistModel(
      id: p.id,
      ownerId: p.ownerId,
      name: p.name,
      coverUrl: p.coverUrl,
      isLikedSongs: p.isLikedSongs,
      createdAt: p.createdAt,
      updatedAt: p.updatedAt,
    );
  }
}
