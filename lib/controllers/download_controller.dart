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

class DownloadController extends StateNotifier<Map<String, DownloadTaskState>> {
  final SupabaseSongsRepository _songsRepo;
  final SongsDao _songsDao;
  final DownloadTasksDao _tasksDao;
  final KeyManager _keyManager;
  final FileCipher _fileCipher = FileCipher();
  final IntegrityService _integrityService = IntegrityService();
  final ConnectivityService _connectivityService;

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
        super({});

  void setWifiOnly(bool value) {
    _wifiOnly = value;
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

    _updateProgress(song.id, 0.1);

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

    try {
      _updateProgress(song.id, 0.3);
      final client = http.Client();
      final request = http.Request('GET', Uri.parse(url));
      final response = await client.send(request);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final totalBytes = response.contentLength ?? 0;
        int receivedBytes = 0;
        final sink = tempFile.openWrite();

        await response.stream.listen((chunk) {
          sink.add(chunk);
          receivedBytes += chunk.length;
          if (totalBytes > 0) {
            _updateProgress(song.id, 0.3 + (0.5 * (receivedBytes / totalBytes)));
          }
        }).asFuture();

        await sink.close();
        client.close();

        await _processDownloadedFile(song.id, tempFile);
      } else {
        throw Exception('Download failed with status ${response.statusCode}');
      }
    } catch (e) {
      state = {
        ...state,
        song.id: DownloadTaskState(
          songId: song.id,
          status: DownloadStatus.failed,
          error: e.toString(),
        )
      };
      if (tempFile.existsSync()) tempFile.deleteSync();
    }
  }

  Future<void> _processDownloadedFile(String songId, File tempFile) async {
    final cur = state[songId] ?? DownloadTaskState(songId: songId);
    state = {...state, songId: cur.copyWith(status: DownloadStatus.encrypting, progress: 0.9)};

    if (!tempFile.existsSync()) return;

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
        return;
      }
    }

    // 3. Encrypt to private storage with .nomedia
    final appDocDir = await getApplicationDocumentsDirectory();
    final secureMusicDir = Directory(p.join(appDocDir.path, 'secure_audio'));
    if (!secureMusicDir.existsSync()) {
      secureMusicDir.createSync(recursive: true);
      File(p.join(secureMusicDir.path, '.nomedia')).createSync();
    }

    final targetEncryptedFile = File(p.join(secureMusicDir.path, '$songId.dat'));
    final masterKey = await _keyManager.getOrCreateMasterKey();

    await _fileCipher.encryptFile(
      inputFile: tempFile,
      outputFile: targetEncryptedFile,
      key: masterKey,
    );

    if (tempFile.existsSync()) {
      tempFile.deleteSync();
    }

    // 4. Update local SQLite DB
    await _songsDao.markDownloaded(songId, targetEncryptedFile.path);

    final completeState = DownloadTaskState(
      songId: songId,
      status: DownloadStatus.downloaded,
      progress: 1.0,
    );
    state = {...state, songId: completeState};
    await _tasksDao.upsertTask(completeState);
  }

  Future<void> deleteDownload(String songId) async {
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
    final appDocDir = await getApplicationDocumentsDirectory();
    final secureMusicDir = Directory(p.join(appDocDir.path, 'secure_audio'));
    if (secureMusicDir.existsSync()) {
      secureMusicDir.deleteSync(recursive: true);
    }
    await _songsDao.clearAllDownloads();
    state = {};
  }
}
