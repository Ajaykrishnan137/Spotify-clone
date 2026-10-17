import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import '../models/song_model.dart';
import '../models/download_state.dart';
import '../core/security/key_manager.dart';
import '../core/security/file_cipher.dart';
import '../core/security/integrity_service.dart';
import '../data/local/daos/songs_dao.dart';
import '../data/local/daos/download_tasks_dao.dart';
import '../data/remote/supabase_songs_repository.dart';
import '../core/network/connectivity_service.dart';
import 'playlist_controller.dart';
import 'audio_player_controller.dart';

class BatchDownloadStatus {
  final bool isBatchActive;
  final bool isPaused;
  final int completedCount;
  final int totalCount;
  final String? currentSongTitle;

  const BatchDownloadStatus({
    this.isBatchActive = false,
    this.isPaused = false,
    this.completedCount = 0,
    this.totalCount = 0,
    this.currentSongTitle,
  });

  BatchDownloadStatus copyWith({
    bool? isBatchActive,
    bool? isPaused,
    int? completedCount,
    int? totalCount,
    String? currentSongTitle,
  }) {
    return BatchDownloadStatus(
      isBatchActive: isBatchActive ?? this.isBatchActive,
      isPaused: isPaused ?? this.isPaused,
      completedCount: completedCount ?? this.completedCount,
      totalCount: totalCount ?? this.totalCount,
      currentSongTitle: currentSongTitle ?? this.currentSongTitle,
    );
  }
}

class DownloadController extends StateNotifier<Map<String, DownloadTaskState>> {
  final SupabaseSongsRepository _songsRepo;
  final SongsDao _songsDao;
  final DownloadTasksDao _tasksDao;
  final KeyManager _keyManager;
  final FileCipher _fileCipher = FileCipher();
  final IntegrityService _integrityService = IntegrityService();
  final ConnectivityService _connectivityService;

  // Active cancellation token map per songId
  final Map<String, http.Client> _activeClients = {};
  final Map<String, File> _activeTempFiles = {};

  // Batch download queue
  final List<SongModel> _batchQueue = [];
  bool _isBatchCancelled = false;
  bool _isBatchPaused = false;
  int _batchTotal = 0;
  int _batchCompleted = 0;

  // Stream controller for batch status
  final StreamController<BatchDownloadStatus> _batchStatusController =
      StreamController<BatchDownloadStatus>.broadcast();
  Stream<BatchDownloadStatus> get batchStatusStream => _batchStatusController.stream;
  BatchDownloadStatus _currentBatchStatus = const BatchDownloadStatus();
  BatchDownloadStatus get currentBatchStatus => _currentBatchStatus;

  bool _wifiOnly = false;
  bool get wifiOnly => _wifiOnly;

  DownloadController({
    required SupabaseSongsRepository songsRepo,
    required SongsDao songsDao,
    required DownloadTasksDao tasksDao,
    required KeyManager keyManager,
    required ConnectivityService connectivityService,
  })  : _songsRepo = songsRepo,
        _songsDao = songsDao,
        _tasksDao = tasksDao,
        _keyManager = keyManager,
        _connectivityService = connectivityService,
        super({}) {
    _initTasks();
  }

  Future<void> _initTasks() async {
    try {
      final tasks = await _tasksDao.getAllTasks();
      final map = <String, DownloadTaskState>{};
      for (final t in tasks) {
        map[t.songId] = t;
      }
      state = map;
    } catch (_) {}
  }

  void setWifiOnly(bool value) {
    _wifiOnly = value;
  }

  void _notifyBatchStatus() {
    _batchStatusController.add(_currentBatchStatus);
  }

  void _updateProgress(String songId, double progress) {
    final current = state[songId] ?? DownloadTaskState(songId: songId);
    final updated = current.copyWith(
      status: DownloadStatus.downloading,
      progress: progress,
    );
    state = {...state, songId: updated};
  }

  Future<void> startDownload(SongModel song) async {
    if (_wifiOnly) {
      final isWifi = await _connectivityService.isConnectedWifi();
      if (!isWifi) {
        final err = DownloadTaskState(
          songId: song.id,
          status: DownloadStatus.failed,
          error: 'Wi-Fi only enabled. Connect to Wi-Fi to download.',
        );
        state = {...state, song.id: err};
        return;
      }
    }

    _updateProgress(song.id, 0.05);

    // 1. Fetch streaming or signed URL
    final res = await _songsRepo.getSignedAudioUrl(song.storagePath);
    if (res.isFailure) {
      final err = DownloadTaskState(
        songId: song.id,
        status: DownloadStatus.failed,
        error: res.errorOrNull ?? 'Failed to get signed URL',
      );
      state = {...state, song.id: err};
      return;
    }

    final url = res.dataOrNull!;
    final tempDir = await getTemporaryDirectory();
    final tempFile = File(p.join(tempDir.path, '${song.id}_temp.mp3'));
    _activeTempFiles[song.id] = tempFile;

    final client = http.Client();
    _activeClients[song.id] = client;

    try {
      _updateProgress(song.id, 0.15);
      final request = http.Request('GET', Uri.parse(url));
      final response = await client.send(request);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final totalBytes = response.contentLength ?? 0;
        int receivedBytes = 0;
        final sink = tempFile.openWrite();

        await response.stream.listen(
          (chunk) {
            sink.add(chunk);
            receivedBytes += chunk.length;
            if (totalBytes > 0) {
              _updateProgress(song.id, 0.15 + (0.75 * (receivedBytes / totalBytes)));
            }
          },
          cancelOnError: true,
        ).asFuture();

        await sink.close();
        _activeClients.remove(song.id);

        if (_activeTempFiles.containsKey(song.id)) {
          await _processDownloadedFile(song, tempFile);
        }
      } else {
        throw Exception('Download failed with status ${response.statusCode}');
      }
    } catch (e) {
      _activeClients.remove(song.id);
      _activeTempFiles.remove(song.id);

      // Clean up partial temp file
      if (tempFile.existsSync()) {
        try {
          tempFile.deleteSync();
        } catch (_) {}
      }

      // If intentionally canceled, mark as canceled
      final current = state[song.id];
      if (current?.status == DownloadStatus.canceled) {
        return;
      }

      state = {
        ...state,
        song.id: DownloadTaskState(
          songId: song.id,
          status: DownloadStatus.failed,
          error: e.toString(),
        )
      };
    }
  }

  Future<void> _processDownloadedFile(SongModel songModel, File tempFile) async {
    final songId = songModel.id;
    final cur = state[songId] ?? DownloadTaskState(songId: songId);
    state = {...state, songId: cur.copyWith(status: DownloadStatus.encrypting, progress: 0.95)};

    if (!tempFile.existsSync()) return;

    // Ensure song exists in SQLite DB so markDownloaded works
    await _songsDao.upsertSong(songModel);
    final song = await _songsDao.getSongById(songId);

    // 2. Verify integrity if hash present
    if (song != null && song.fileHash.isNotEmpty) {
      final isValid = await _integrityService.verifyFileHash(tempFile, song.fileHash);
      if (!isValid) {
        state = {
          ...state,
          songId: cur.copyWith(status: DownloadStatus.failed, error: 'SHA-256 Integrity check failed'),
        };
        if (tempFile.existsSync()) tempFile.deleteSync();
        _activeTempFiles.remove(songId);
        return;
      }
    }

    // 3. Save to private offline music storage
    final appDocDir = await getApplicationDocumentsDirectory();
    final offlineMusicDir = Directory(p.join(appDocDir.path, 'offline_music'));
    if (!offlineMusicDir.existsSync()) {
      offlineMusicDir.createSync(recursive: true);
      File(p.join(offlineMusicDir.path, '.nomedia')).createSync();
    }

    final targetFile = File(p.join(offlineMusicDir.path, '$songId.mp3'));
    if (targetFile.existsSync()) {
      targetFile.deleteSync();
    }
    await tempFile.copy(targetFile.path);

    if (tempFile.existsSync()) {
      tempFile.deleteSync();
    }
    _activeTempFiles.remove(songId);

    // 4. Update local SQLite DB
    await _songsDao.markDownloaded(songId, targetFile.path);

    final completeState = DownloadTaskState(
      songId: songId,
      status: DownloadStatus.downloaded,
      progress: 1.0,
    );
    state = {...state, songId: completeState};
    await _tasksDao.upsertTask(completeState);
  }

  /// Cancel individual track download and clean up partial files
  void cancelTrackDownload(String songId) {
    if (_activeClients.containsKey(songId)) {
      _activeClients[songId]?.close();
      _activeClients.remove(songId);
    }
    if (_activeTempFiles.containsKey(songId)) {
      final tempFile = _activeTempFiles.remove(songId);
      if (tempFile != null && tempFile.existsSync()) {
        try {
          tempFile.deleteSync();
        } catch (_) {}
      }
    }
    state = {
      ...state,
      songId: DownloadTaskState(
        songId: songId,
        status: DownloadStatus.canceled,
        progress: 0.0,
      ),
    };
  }

  /// Download multiple songs with full cancel and pause/resume support
  Future<void> downloadMultipleSongs(List<SongModel> songs) async {
    _isBatchCancelled = false;
    _isBatchPaused = false;
    _batchQueue.clear();
    
    // Only queue songs that aren't already downloaded
    for (final s in songs) {
      if (state[s.id]?.status != DownloadStatus.downloaded) {
        _batchQueue.add(s);
      }
    }

    _batchTotal = _batchQueue.length;
    _batchCompleted = 0;

    _currentBatchStatus = BatchDownloadStatus(
      isBatchActive: true,
      isPaused: false,
      completedCount: 0,
      totalCount: _batchTotal,
      currentSongTitle: _batchQueue.isNotEmpty ? _batchQueue.first.title : null,
    );
    _notifyBatchStatus();

    while (_batchQueue.isNotEmpty && !_isBatchCancelled) {
      if (_isBatchPaused) {
        await Future.delayed(const Duration(milliseconds: 500));
        continue;
      }

      final song = _batchQueue.removeAt(0);
      _currentBatchStatus = _currentBatchStatus.copyWith(
        currentSongTitle: song.title,
        completedCount: _batchCompleted,
      );
      _notifyBatchStatus();

      await startDownload(song);

      if (!_isBatchCancelled) {
        _batchCompleted++;
        _currentBatchStatus = _currentBatchStatus.copyWith(
          completedCount: _batchCompleted,
        );
        _notifyBatchStatus();
      }
    }

    _currentBatchStatus = _currentBatchStatus.copyWith(
      isBatchActive: false,
      isPaused: false,
    );
    _notifyBatchStatus();
  }

  /// Cancel all ongoing downloads: stops current file, deletes partial file, clears remaining queue
  void cancelBatchDownload() {
    _isBatchCancelled = true;
    _batchQueue.clear();

    // Abort all active downloads and purge partial files
    for (final songId in _activeClients.keys.toList()) {
      cancelTrackDownload(songId);
    }

    _currentBatchStatus = const BatchDownloadStatus(
      isBatchActive: false,
      isPaused: false,
      completedCount: 0,
      totalCount: 0,
    );
    _notifyBatchStatus();
  }

  /// Pause ongoing batch download
  void pauseBatchDownload() {
    _isBatchPaused = true;
    _currentBatchStatus = _currentBatchStatus.copyWith(isPaused: true);
    _notifyBatchStatus();
  }

  /// Resume ongoing batch download
  void resumeBatchDownload() {
    _isBatchPaused = false;
    _currentBatchStatus = _currentBatchStatus.copyWith(isPaused: false);
    _notifyBatchStatus();
  }

  Future<void> deleteDownload(String songId) async {
    cancelTrackDownload(songId);

    final appDocDir = await getApplicationDocumentsDirectory();
    final f1 = File(p.join(appDocDir.path, 'offline_music', '$songId.mp3'));
    if (f1.existsSync()) f1.deleteSync();
    final f2 = File(p.join(appDocDir.path, 'secure_audio', '$songId.dat'));
    if (f2.existsSync()) f2.deleteSync();

    final song = await _songsDao.getSongById(songId);
    if (song?.localPath != null) {
      final f = File(song!.localPath!);
      if (f.existsSync()) f.deleteSync();
    }
    await _songsDao.deleteDownload(songId);
    await _tasksDao.deleteTask(songId);
    state = {...state, songId: DownloadTaskState(songId: songId, status: DownloadStatus.notDownloaded)};
  }

  Future<void> deleteAllDownloads() async {
    cancelBatchDownload();

    final appDocDir = await getApplicationDocumentsDirectory();
    final offlineDir = Directory(p.join(appDocDir.path, 'offline_music'));
    if (offlineDir.existsSync()) {
      offlineDir.deleteSync(recursive: true);
    }
    final secureMusicDir = Directory(p.join(appDocDir.path, 'secure_audio'));
    if (secureMusicDir.existsSync()) {
      secureMusicDir.deleteSync(recursive: true);
    }
    await _songsDao.clearAllDownloads();
    state = {};
  }
}

final downloadTasksDaoProvider = Provider<DownloadTasksDao>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return DownloadTasksDao(db);
});

final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  return ConnectivityService();
});

final downloadControllerProvider =
    StateNotifierProvider<DownloadController, Map<String, DownloadTaskState>>((ref) {
  return DownloadController(
    songsRepo: ref.watch(supabaseSongsRepoProvider),
    songsDao: ref.watch(songsDaoProvider),
    tasksDao: ref.watch(downloadTasksDaoProvider),
    keyManager: ref.watch(keyManagerProvider),
    connectivityService: ref.watch(connectivityServiceProvider),
  );
});

final batchDownloadStatusStreamProvider = StreamProvider<BatchDownloadStatus>((ref) {
  final controller = ref.watch(downloadControllerProvider.notifier);
  return controller.batchStatusStream;
});
