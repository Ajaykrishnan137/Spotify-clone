import 'package:drift/drift.dart';
import '../database.dart';
import '../../../models/download_state.dart';

part 'download_tasks_dao.g.dart';

@DriftAccessor(tables: [DownloadTasks])
class DownloadTasksDao extends DatabaseAccessor<AppDatabase> with _$DownloadTasksDaoMixin {
  DownloadTasksDao(AppDatabase db) : super(db);

  Stream<List<DownloadTaskState>> watchAllTasks() {
    return select(downloadTasks).watch().map((rows) => rows.map(_toModel).toList());
  }

  Future<DownloadTaskState?> getTask(String songId) async {
    final row = await (select(downloadTasks)..where((tbl) => tbl.songId.equals(songId))).getSingleOrNull();
    return row != null ? _toModel(row) : null;
  }

  Future<void> upsertTask(DownloadTaskState state) async {
    await into(downloadTasks).insertOnConflictUpdate(
      DownloadTasksCompanion.insert(
        songId: state.songId,
        status: state.status.name,
        progress: Value(state.progress),
        error: Value(state.error),
        retries: Value(state.retryCount),
      ),
    );
  }

  Future<void> deleteTask(String songId) async {
    await (delete(downloadTasks)..where((tbl) => tbl.songId.equals(songId))).go();
  }

  DownloadTaskState _toModel(DownloadTask task) {
    final status = DownloadStatus.values.firstWhere(
      (e) => e.name == task.status,
      orElse: () => DownloadStatus.notDownloaded,
    );
    return DownloadTaskState(
      songId: task.songId,
      status: status,
      progress: task.progress,
      error: task.error,
      retryCount: task.retries,
    );
  }
}
