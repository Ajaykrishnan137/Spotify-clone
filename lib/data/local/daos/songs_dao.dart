import 'package:drift/drift.dart';
import '../database.dart';
import '../../../models/song_model.dart';

part 'songs_dao.g.dart';

@DriftAccessor(tables: [Songs])
class SongsDao extends DatabaseAccessor<AppDatabase> with _$SongsDaoMixin {
  SongsDao(AppDatabase db) : super(db);

  Stream<List<SongModel>> watchAllSongs() {
    return select(songs).watch().map((rows) => rows.map(_toModel).toList());
  }

  Stream<List<SongModel>> watchDownloadedSongs() {
    return (select(songs)..where((tbl) => tbl.isDownloaded.equals(true)))
        .watch()
        .map((rows) => rows.map(_toModel).toList());
  }

  Future<List<SongModel>> getAllSongs() async {
    final rows = await select(songs).get();
    return rows.map(_toModel).toList();
  }

  Future<SongModel?> getSongById(String id) async {
    final row = await (select(songs)..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
    return row != null ? _toModel(row) : null;
  }

  Future<List<SongModel>> searchLocalSongs(String query) async {
    final pattern = '%$query%';
    final rows = await (select(songs)
          ..where((tbl) =>
              tbl.title.like(pattern) |
              tbl.artist.like(pattern) |
              tbl.album.like(pattern)))
        .get();
    return rows.map(_toModel).toList();
  }

  Future<void> upsertSong(SongModel model) async {
    await into(songs).insertOnConflictUpdate(
      SongsCompanion.insert(
        id: model.id,
        title: model.title,
        artist: model.artist,
        album: model.album,
        durationMs: model.durationMs,
        coverUrl: model.coverUrl,
        storagePath: model.storagePath,
        fileHash: Value(model.fileHash),
        localPath: Value(model.localPath),
        isDownloaded: Value(model.isDownloaded),
        downloadedAt: Value(model.downloadedAt),
        genre: Value(model.genre),
      ),
    );
  }

  Future<void> upsertSongs(List<SongModel> songList) async {
    await batch((batch) {
      for (final s in songList) {
        batch.insert(
          songs,
          SongsCompanion.insert(
            id: s.id,
            title: s.title,
            artist: s.artist,
            album: s.album,
            durationMs: s.durationMs,
            coverUrl: s.coverUrl,
            storagePath: s.storagePath,
            fileHash: Value(s.fileHash),
            localPath: Value(s.localPath),
            isDownloaded: Value(s.isDownloaded),
            downloadedAt: Value(s.downloadedAt),
            genre: Value(s.genre),
          ),
          mode: InsertMode.insertOrReplace,
        );
      }
    });
  }

  Future<void> markDownloaded(String id, String localPath) async {
    await (update(songs)..where((tbl) => tbl.id.equals(id))).write(
      SongsCompanion(
        isDownloaded: const Value(true),
        localPath: Value(localPath),
        downloadedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> deleteDownload(String id) async {
    await (update(songs)..where((tbl) => tbl.id.equals(id))).write(
      const SongsCompanion(
        isDownloaded: Value(false),
        localPath: Value(null),
        downloadedAt: Value(null),
      ),
    );
  }

  Future<void> clearAllDownloads() async {
    await (update(songs)..where((tbl) => tbl.isDownloaded.equals(true))).write(
      const SongsCompanion(
        isDownloaded: Value(false),
        localPath: Value(null),
        downloadedAt: Value(null),
      ),
    );
  }

  SongModel _toModel(Song data) {
    return SongModel(
      id: data.id,
      title: data.title,
      artist: data.artist,
      album: data.album,
      durationMs: data.durationMs,
      coverUrl: data.coverUrl,
      storagePath: data.storagePath,
      fileHash: data.fileHash,
      localPath: data.localPath,
      isDownloaded: data.isDownloaded,
      downloadedAt: data.downloadedAt,
      genre: data.genre,
    );
  }
}
