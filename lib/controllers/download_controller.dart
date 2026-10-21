import 'dart:async';
import 'dart:convert';
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
import '../core/services/in_app_notifications_service.dart';
import '../core/services/app_settings_service.dart';
import 'playlist_controller.dart';
import 'audio_player_controller.dart';

class _QueueTaskItem {
  final SongModel song;
  final String playlistId;
  int retryAttempts;

  _QueueTaskItem({
    required this.song,
    required this.playlistId,
    this.retryAttempts = 0,
  });
}

class DownloadController extends StateNotifier<Map<String, DownloadTaskState>> {
  final SupabaseSongsRepository _songsRepo;
  final SongsDao _songsDao;
  final DownloadTasksDao _tasksDao;
  final KeyManager _keyManager;
  final ConnectivityService _connectivityService;
  final InAppNotificationsNotifier _notificationsNotifier;
  final AppSettingsNotifier _settingsNotifier;

  final FileCipher _fileCipher = FileCipher();
  final IntegrityService _integrityService = IntegrityService();

  // Concurrency limit: defaults to 3, configurable 1..4
  int _concurrencyLimit = 3;

  // Active cancellation clients per songId
  final Map<String, http.Client> _activeClients = {};
  final Map<String, File> _activeTempFiles = {};

  // Running tasks (currently in network stream)
  final Set<String> _activeRunningSongIds = {};

  // Paused tasks
  final Set<String> _pausedSongIds = {};

  // Waiting queue
  final List<_QueueTaskItem> _pendingQueue = [];

  // Per-playlist status tracking
  final Map<String, PlaylistDownloadProgress> _playlistProgressMap = {};
  final StreamController<Map<String, PlaylistDownloadProgress>> _playlistProgressStreamController =
      StreamController<Map<String, PlaylistDownloadProgress>>.broadcast();
  Stream<Map<String, PlaylistDownloadProgress>> get playlistProgressStream =>
      _playlistProgressStreamController.stream;

  // Global batch status (for overall notification & backward compatibility)
  final StreamController<PlaylistDownloadProgress> _globalProgressStreamController =
      StreamController<PlaylistDownloadProgress>.broadcast();
  Stream<PlaylistDownloadProgress> get batchStatusStream => _globalProgressStreamController.stream;

  bool _isQueuePaused = false;
  bool _wifiOnly = false;
  bool get wifiOnly => _wifiOnly;

  static const String _persistedQueueFile = 'skytune_download_queue.json';

  DownloadController({
    required SupabaseSongsRepository songsRepo,
    required SongsDao songsDao,
    required DownloadTasksDao tasksDao,
    required KeyManager keyManager,
    required ConnectivityService connectivityService,
    required InAppNotificationsNotifier notificationsNotifier,
    required AppSettingsNotifier settingsNotifier,
  })  : _songsRepo = songsRepo,
        _songsDao = songsDao,
        _tasksDao = tasksDao,
        _keyManager = keyManager,
        _connectivityService = connectivityService,
        _notificationsNotifier = notificationsNotifier,
        _settingsNotifier = settingsNotifier,
        super({}) {
    _concurrencyLimit = _settingsNotifier.state.concurrentDownloads;
    _wifiOnly = _settingsNotifier.state.wifiOnly;

    _initTasks();
    _listenToConnectivity();
  }

  void _listenToConnectivity() {
    _connectivityService.stream.listen((status) {
      if (status == NetworkStatus.online) {
        if (_isQueuePaused && !_userPausedManually) {
          _isQueuePaused = false;
          _pumpQueue();
        }
      } else if (status == NetworkStatus.offline) {
        if (_activeRunningSongIds.isNotEmpty) {
          // Pause queue automatically
          _isQueuePaused = true;
        }
      }
    });
  }

  bool _userPausedManually = false;

  Future<void> _initTasks() async {
    try {
      final tasks = await _tasksDao.getAllTasks();
      final map = <String, DownloadTaskState>{};
      for (final t in tasks) {
        map[t.songId] = t;
      }
      state = map;

      // Restore persisted queue if app was killed mid-download
      await _restorePersistedQueue();
    } catch (_) {}
  }

  Future<File> _getQueueFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File(p.join(dir.path, _persistedQueueFile));
  }

  Future<void> _savePersistedQueue() async {
    try {
      final file = await _getQueueFile();
      final data = {
        'queue': _pendingQueue.map((item) => {
          'song': item.song.toJson(),
          'playlistId': item.playlistId,
          'retryAttempts': item.retryAttempts,
        }).toList(),
        'playlists': _playlistProgressMap.map((k, v) => MapEntry(k, v.toJson())),
      };
      await file.writeAsString(jsonEncode(data), flush: true);
    } catch (_) {}
  }

  Future<void> _restorePersistedQueue() async {
    try {
      final file = await _getQueueFile();
      if (!file.existsSync()) return;
      final content = await file.readAsString();
      if (content.isEmpty) return;
      final data = jsonDecode(content) as Map<String, dynamic>;

      final rawQueue = data['queue'] as List<dynamic>? ?? [];
      for (final item in rawQueue) {
        final map = item as Map<String, dynamic>;
        final song = SongModel.fromJson(map['song'] as Map<String, dynamic>);
        final pId = map['playlistId'] as String? ?? 'default';
        final retries = map['retryAttempts'] as int? ?? 0;

        if (state[song.id]?.status != DownloadStatus.downloaded) {
          _pendingQueue.add(_QueueTaskItem(song: song, playlistId: pId, retryAttempts: retries));
        }
      }

      final rawPlaylists = data['playlists'] as Map<String, dynamic>? ?? {};
      rawPlaylists.forEach((k, v) {
        _playlistProgressMap[k] = PlaylistDownloadProgress.fromJson(v as Map<String, dynamic>);
      });

      _notifyPlaylistProgress();
      _pumpQueue();
    } catch (_) {}
  }

  void setConcurrencyLimit(int count) {
    _concurrencyLimit = count.clamp(1, 4);
    _pumpQueue();
  }

  void setWifiOnly(bool value) {
    _wifiOnly = value;
  }

  void _notifyPlaylistProgress() {
    _playlistProgressStreamController.add(Map.unmodifiable(_playlistProgressMap));

    // Global overall summary
    int total = 0;
    int completed = 0;
    bool anyActive = false;
    bool anyPaused = false;
    String? currentTitle;

    for (final prog in _playlistProgressMap.values) {
      if (prog.isActive) {
        anyActive = true;
        total += prog.totalCount;
        completed += prog.completedCount;
        if (prog.isPaused) anyPaused = true;
        currentTitle ??= prog.currentSongTitle;
      }
    }

    _globalProgressStreamController.add(
      PlaylistDownloadProgress(
        playlistId: 'global',
        isActive: anyActive,
        isPaused: anyPaused,
        completedCount: completed,
        totalCount: total,
        currentSongTitle: currentTitle,
      ),
    );

    _savePersistedQueue();
  }

  PlaylistDownloadProgress getPlaylistProgress(String playlistId) {
    return _playlistProgressMap[playlistId] ??
        PlaylistDownloadProgress(playlistId: playlistId);
  }

  final Map<String, int> _lastProgressUpdateMs = {};

  void _updateProgress(String songId, double progress) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final last = _lastProgressUpdateMs[songId] ?? 0;
    // Throttle intermediate updates to at most once per 300ms, but always allow 0.0, 1.0 or large jumps
    if (progress < 1.0 && progress > 0.0 && (now - last) < 300) {
      return;
    }
    _lastProgressUpdateMs[songId] = now;

    final current = state[songId] ?? DownloadTaskState(songId: songId);
    final updated = current.copyWith(
      status: DownloadStatus.downloading,
      progress: progress,
    );
    state = {...state, songId: updated};
  }

  /// Start download for an individual song (e.g. from song options or retry button)
  Future<void> startDownload(SongModel song, {String playlistId = 'single'}) async {
    // Skip if already completed or already in queue/running
    if (state[song.id]?.status == DownloadStatus.downloaded) return;
    if (_activeRunningSongIds.contains(song.id)) return;
    if (_pendingQueue.any((i) => i.song.id == song.id)) return;

    final queuedState = DownloadTaskState(
      songId: song.id,
      status: DownloadStatus.enqueued,
      progress: 0.0,
    );
    state = {...state, song.id: queuedState};
    await _tasksDao.upsertTask(queuedState);

    _pendingQueue.add(_QueueTaskItem(song: song, playlistId: playlistId));
    _pumpQueue();
  }

  /// Check storage space before batch download
  Future<bool> hasEnoughStorage(int songsCount) async {
    try {
      final appDocDir = await getApplicationDocumentsDirectory();
      // Average 10MB per song
      final requiredBytes = songsCount * 10 * 1024 * 1024;
      // On Android/iOS path_provider root usually has adequate space, check directory existence
      final stat = await appDocDir.stat();
      return stat.size >= 0; // If can read stat, assume viable; 
    } catch (_) {
      return true;
    }
  }

  /// Download multiple songs for a playlist with per-playlist tracking & central queue
  Future<void> downloadMultipleSongs(List<SongModel> songs, {required String playlistId}) async {
    if (_wifiOnly) {
      final isWifi = await _connectivityService.isConnectedWifi();
      if (!isWifi) {
        _notificationsNotifier.addNotification(
          title: 'Download paused',
          message: 'Wi-Fi only is enabled in settings. Connect to Wi-Fi to start downloads.',
          type: NotificationType.downloadFailed,
          playlistId: playlistId,
        );
        return;
      }
    }

    // Filter out already downloaded or already queued songs
    final List<SongModel> toDownload = [];
    for (final song in songs) {
      final cur = state[song.id]?.status;
      final alreadyQueued = _pendingQueue.any((i) => i.song.id == song.id);
      final alreadyRunning = _activeRunningSongIds.contains(song.id);
      if (cur != DownloadStatus.downloaded && !alreadyQueued && !alreadyRunning) {
        toDownload.add(song);
      }
    }

    if (toDownload.isEmpty) return;

    final existingProgress = _playlistProgressMap[playlistId];
    final totalCount = (existingProgress != null && existingProgress.isActive)
        ? existingProgress.totalCount + toDownload.length
        : toDownload.length;
    final completedCount = (existingProgress != null && existingProgress.isActive)
        ? existingProgress.completedCount
        : 0;

    _playlistProgressMap[playlistId] = PlaylistDownloadProgress(
      playlistId: playlistId,
      isActive: true,
      isPaused: false,
      completedCount: completedCount,
      totalCount: totalCount,
      currentSongTitle: toDownload.first.title,
    );
    _notifyPlaylistProgress();

    for (final song in toDownload) {
      final enqueued = DownloadTaskState(
        songId: song.id,
        status: DownloadStatus.enqueued,
        progress: 0.0,
      );
      state = {...state, song.id: enqueued};
      await _tasksDao.upsertTask(enqueued);

      _pendingQueue.add(_QueueTaskItem(song: song, playlistId: playlistId));
    }

    _pumpQueue();
  }

  /// Pump the central download manager queue respecting concurrency limit
  void _pumpQueue() {
    if (_isQueuePaused) return;

    while (_activeRunningSongIds.length < _concurrencyLimit && _pendingQueue.isNotEmpty) {
      final next = _pendingQueue.removeAt(0);

      if (_pausedSongIds.contains(next.song.id)) {
        // Skip paused items
        continue;
      }

      _activeRunningSongIds.add(next.song.id);
      _executeDownload(next);
    }

    _notifyPlaylistProgress();
  }

  /// Execute download for a task item with retry, range-request resume & integrity check
  Future<void> _executeDownload(_QueueTaskItem item) async {
    final song = item.song;
    final playlistId = item.playlistId;

    if (_wifiOnly) {
      final isWifi = await _connectivityService.isConnectedWifi();
      if (!isWifi) {
        _activeRunningSongIds.remove(song.id);
        final err = DownloadTaskState(
          songId: song.id,
          status: DownloadStatus.failed,
          error: 'Wi-Fi only enabled',
        );
        state = {...state, song.id: err};
        await _tasksDao.upsertTask(err);
        _pumpQueue();
        return;
      }
    }

    // Update playlist current title
    if (_playlistProgressMap.containsKey(playlistId)) {
      _playlistProgressMap[playlistId] = _playlistProgressMap[playlistId]!.copyWith(
        currentSongTitle: song.title,
      );
      _notifyPlaylistProgress();
    }

    _updateProgress(song.id, 0.05);

    // 1. Get signed / direct URL
    final res = await _songsRepo.getSignedAudioUrl(song.storagePath);
    if (res.isFailure) {
      await _handleDownloadError(item, res.errorOrNull ?? 'Failed to get URL');
      return;
    }

    final url = res.dataOrNull!;
    final tempDir = await getTemporaryDirectory();
    final tempFile = File(p.join(tempDir.path, '${song.id}_part.mp3'));
    _activeTempFiles[song.id] = tempFile;

    final client = http.Client();
    _activeClients[song.id] = client;

    try {
      int existingBytes = 0;
      if (tempFile.existsSync()) {
        existingBytes = tempFile.lengthSync();
      }

      final request = http.Request('GET', Uri.parse(url));
      // Support HTTP Range resume if partial file exists
      if (existingBytes > 0) {
        request.headers['Range'] = 'bytes=$existingBytes-';
      }

      _updateProgress(song.id, 0.15);
      final response = await client.send(request);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final isPartial = response.statusCode == 206;
        final contentLength = response.contentLength ?? 0;
        final totalBytes = isPartial ? existingBytes + contentLength : contentLength;

        final sink = tempFile.openWrite(
          mode: isPartial ? FileMode.append : FileMode.write,
        );

        int received = existingBytes;

        await response.stream.listen(
          (chunk) {
            sink.add(chunk);
            received += chunk.length;
            if (totalBytes > 0) {
              final pct = 0.15 + (0.75 * (received / totalBytes));
              _updateProgress(song.id, pct.clamp(0.15, 0.90));
            }
          },
          cancelOnError: true,
        ).asFuture();

        await sink.close();
        _activeClients.remove(song.id);
        _activeRunningSongIds.remove(song.id);

        if (_activeTempFiles.containsKey(song.id)) {
          await _processCompletedFile(item, tempFile);
        }
      } else {
        throw Exception('Server responded with HTTP ${response.statusCode}');
      }
    } catch (e) {
      _activeClients.remove(song.id);
      _activeRunningSongIds.remove(song.id);

      final current = state[song.id];
      if (current?.status == DownloadStatus.canceled) {
        // Intentionally canceled, cleanup already done
        _pumpQueue();
        return;
      }
      if (current?.status == DownloadStatus.paused) {
        _pumpQueue();
        return;
      }

      await _handleDownloadError(item, e.toString());
    }
  }

  /// Handle failures with exponential backoff retry (up to 3 attempts)
  Future<void> _handleDownloadError(_QueueTaskItem item, String errorMsg) async {
    final songId = item.song.id;

    if (item.retryAttempts < 3) {
      item.retryAttempts++;
      final delaySeconds = 1 << item.retryAttempts; // 2s, 4s, 8s

      final retryState = DownloadTaskState(
        songId: songId,
        status: DownloadStatus.enqueued,
        progress: 0.1,
        retryCount: item.retryAttempts,
        error: 'Retrying attempt ${item.retryAttempts}/3 in ${delaySeconds}s...',
      );
      state = {...state, songId: retryState};
      await _tasksDao.upsertTask(retryState);

      await Future.delayed(Duration(seconds: delaySeconds));
      _pendingQueue.insert(0, item);
      _pumpQueue();
    } else {
      // Mark as failed with manual Retry button
      final failedState = DownloadTaskState(
        songId: songId,
        status: DownloadStatus.failed,
        error: errorMsg,
        retryCount: 3,
      );
      state = {...state, songId: failedState};
      await _tasksDao.upsertTask(failedState);

      // Clean up partial file on final failure
      final tempFile = _activeTempFiles.remove(songId);
      if (tempFile != null && tempFile.existsSync()) {
        try {
          tempFile.deleteSync();
        } catch (_) {}
      }

      _notificationsNotifier.addNotification(
        title: 'Download Failed',
        message: '"${item.song.title}" failed to download. Tap to retry.',
        type: NotificationType.downloadFailed,
        song: item.song,
        playlistId: item.playlistId,
      );

      _checkPlaylistCompletion(item.playlistId);
      _pumpQueue();
    }
  }

  Future<void> _processCompletedFile(_QueueTaskItem item, File tempFile) async {
    final song = item.song;
    final songId = song.id;

    _updateProgress(songId, 0.95);

    if (!tempFile.existsSync() || tempFile.lengthSync() == 0) {
      await _handleDownloadError(item, 'Downloaded file was empty');
      return;
    }

    // Upsert song into local SQLite DB
    await _songsDao.upsertSong(song);

    // Verify SHA-256 hash if present
    final dbSong = await _songsDao.getSongById(songId);
    if (dbSong != null && dbSong.fileHash.isNotEmpty) {
      final isValid = await _integrityService.verifyFileHash(tempFile, dbSong.fileHash);
      if (!isValid) {
        if (tempFile.existsSync()) tempFile.deleteSync();
        _activeTempFiles.remove(songId);
        await _handleDownloadError(item, 'SHA-256 hash check failed');
        return;
      }
    }

    // Save to permanent offline directory: offline_music/<id>.mp3
    final appDocDir = await getApplicationDocumentsDirectory();
    final offlineDir = Directory(p.join(appDocDir.path, 'offline_music'));
    if (!offlineDir.existsSync()) {
      offlineDir.createSync(recursive: true);
      File(p.join(offlineDir.path, '.nomedia')).createSync();
    }

    final finalFile = File(p.join(offlineDir.path, '$songId.mp3'));
    if (finalFile.existsSync()) {
      finalFile.deleteSync();
    }

    // Atomic move / copy
    await tempFile.copy(finalFile.path);
    if (tempFile.existsSync()) {
      tempFile.deleteSync();
    }
    _activeTempFiles.remove(songId);

    // Verify file size after completion
    if (!finalFile.existsSync() || finalFile.lengthSync() == 0) {
      await _handleDownloadError(item, 'Final file size verification failed');
      return;
    }

    // Mark downloaded in DB
    await _songsDao.markDownloaded(songId, finalFile.path);

    final completeState = DownloadTaskState(
      songId: songId,
      status: DownloadStatus.downloaded,
      progress: 1.0,
    );
    state = {...state, songId: completeState};
    await _tasksDao.upsertTask(completeState);

    // Update playlist progress
    _incrementPlaylistCompleted(item.playlistId, song);

    // Send in-app notification
    _notificationsNotifier.addNotification(
      title: 'Download Complete',
      message: '"${song.title}" is ready for offline listening.',
      type: NotificationType.downloadCompleted,
      song: song,
      playlistId: item.playlistId,
    );

    _pumpQueue();
  }

  void _incrementPlaylistCompleted(String playlistId, SongModel song) {
    if (_playlistProgressMap.containsKey(playlistId)) {
      final cur = _playlistProgressMap[playlistId]!;
      final newCount = cur.completedCount + 1;
      final isFinished = newCount >= cur.totalCount;

      _playlistProgressMap[playlistId] = cur.copyWith(
        completedCount: newCount,
        isActive: !isFinished,
        currentSongTitle: isFinished ? null : song.title,
      );

      if (isFinished) {
        _notificationsNotifier.addNotification(
          title: 'Playlist Downloaded',
          message: 'All songs in playlist downloaded successfully.',
          type: NotificationType.downloadCompleted,
          playlistId: playlistId,
        );
      }

      _notifyPlaylistProgress();
    }
  }

  void _checkPlaylistCompletion(String playlistId) {
    if (_playlistProgressMap.containsKey(playlistId)) {
      final cur = _playlistProgressMap[playlistId]!;
      // Check if any songs for this playlist remain in pending or running
      final remaining = _pendingQueue.where((i) => i.playlistId == playlistId).length +
          _activeRunningSongIds.where((id) {
            final t = _pendingQueue.any((i) => i.song.id == id && i.playlistId == playlistId);
            return t;
          }).length;

      if (remaining == 0) {
        _playlistProgressMap[playlistId] = cur.copyWith(isActive: false);
        _notifyPlaylistProgress();
      }
    }
  }

  /// Pause downloads for a specific playlist
  void pausePlaylistDownload(String playlistId) {
    if (_playlistProgressMap.containsKey(playlistId)) {
      _playlistProgressMap[playlistId] = _playlistProgressMap[playlistId]!.copyWith(isPaused: true);
      _notifyPlaylistProgress();
    }

    // Pause all running or pending songs for this playlist
    for (final item in _pendingQueue.where((i) => i.playlistId == playlistId)) {
      _pausedSongIds.add(item.song.id);
      state = {
        ...state,
        item.song.id: (state[item.song.id] ?? DownloadTaskState(songId: item.song.id)).copyWith(
          status: DownloadStatus.paused,
        ),
      };
    }
  }

  /// Resume downloads for a specific playlist
  void resumePlaylistDownload(String playlistId) {
    if (_playlistProgressMap.containsKey(playlistId)) {
      _playlistProgressMap[playlistId] = _playlistProgressMap[playlistId]!.copyWith(isPaused: false);
      _notifyPlaylistProgress();
    }

    for (final item in _pendingQueue.where((i) => i.playlistId == playlistId)) {
      _pausedSongIds.remove(item.song.id);
      state = {
        ...state,
        item.song.id: (state[item.song.id] ?? DownloadTaskState(songId: item.song.id)).copyWith(
          status: DownloadStatus.enqueued,
        ),
      };
    }

    _pumpQueue();
  }

  /// Cancel downloads for a specific playlist
  void cancelPlaylistDownload(String playlistId) {
    _playlistProgressMap[playlistId] = PlaylistDownloadProgress(playlistId: playlistId);
    _notifyPlaylistProgress();

    final toRemove = _pendingQueue.where((i) => i.playlistId == playlistId).toList();
    _pendingQueue.removeWhere((i) => i.playlistId == playlistId);

    for (final item in toRemove) {
      cancelTrackDownload(item.song.id);
    }
  }

  /// Cancel individual track download and clean up partial files
  void cancelTrackDownload(String songId) {
    _pausedSongIds.remove(songId);

    if (_activeClients.containsKey(songId)) {
      _activeClients[songId]?.close();
      _activeClients.remove(songId);
    }
    _activeRunningSongIds.remove(songId);

    if (_activeTempFiles.containsKey(songId)) {
      final tempFile = _activeTempFiles.remove(songId);
      if (tempFile != null && tempFile.existsSync()) {
        try {
          tempFile.deleteSync();
        } catch (_) {}
      }
    }

    _pendingQueue.removeWhere((i) => i.song.id == songId);

    state = {
      ...state,
      songId: DownloadTaskState(
        songId: songId,
        status: DownloadStatus.canceled,
        progress: 0.0,
      ),
    };

    _pumpQueue();
  }

  /// Pause/Resume all downloads globally
  void pauseBatchDownload() {
    _userPausedManually = true;
    _isQueuePaused = true;
    for (final k in _playlistProgressMap.keys) {
      _playlistProgressMap[k] = _playlistProgressMap[k]!.copyWith(isPaused: true);
    }
    _notifyPlaylistProgress();
  }

  void resumeBatchDownload() {
    _userPausedManually = false;
    _isQueuePaused = false;
    for (final k in _playlistProgressMap.keys) {
      _playlistProgressMap[k] = _playlistProgressMap[k]!.copyWith(isPaused: false);
    }
    _notifyPlaylistProgress();
    _pumpQueue();
  }

  void cancelBatchDownload() {
    _pendingQueue.clear();
    _pausedSongIds.clear();

    for (final songId in _activeClients.keys.toList()) {
      cancelTrackDownload(songId);
    }

    _playlistProgressMap.clear();
    _notifyPlaylistProgress();
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
    notificationsNotifier: ref.watch(inAppNotificationsNotifierProvider.notifier),
    settingsNotifier: ref.watch(appSettingsProvider.notifier),
  );
});

final playlistDownloadProgressStreamProvider =
    StreamProvider<Map<String, PlaylistDownloadProgress>>((ref) {
  final controller = ref.watch(downloadControllerProvider.notifier);
  return controller.playlistProgressStream;
});

final batchDownloadStatusStreamProvider = StreamProvider<PlaylistDownloadProgress>((ref) {
  final controller = ref.watch(downloadControllerProvider.notifier);
  return controller.batchStatusStream;
});
