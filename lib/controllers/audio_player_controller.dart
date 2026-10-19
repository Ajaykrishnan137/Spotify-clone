import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_service/audio_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../models/song_model.dart';
import '../core/audio/audio_player_handler.dart';
import '../core/security/key_manager.dart';
import '../core/security/encrypted_audio_source.dart';
import '../core/services/state_persistence_service.dart';
import '../data/remote/supabase_songs_repository.dart';

import '../core/services/art_cache_service.dart';

enum PlayerLoopMode { off, all, one }

class PlayerStateData {
  final SongModel? currentSong;
  final bool isPlaying;
  final Duration position;
  final Duration duration;
  final List<SongModel> queue;
  final int currentIndex;
  final bool isShuffle;
  final PlayerLoopMode loopMode;
  final bool isLoading;
  final List<SongModel> recentlyPlayed;

  const PlayerStateData({
    this.currentSong,
    this.isPlaying = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.queue = const [],
    this.currentIndex = -1,
    this.isShuffle = false,
    this.loopMode = PlayerLoopMode.off,
    this.isLoading = false,
    this.recentlyPlayed = const [],
  });

  PlayerStateData copyWith({
    SongModel? currentSong,
    bool? isPlaying,
    Duration? position,
    Duration? duration,
    List<SongModel>? queue,
    int? currentIndex,
    bool? isShuffle,
    PlayerLoopMode? loopMode,
    bool? isLoading,
    List<SongModel>? recentlyPlayed,
  }) {
    return PlayerStateData(
      currentSong: currentSong ?? this.currentSong,
      isPlaying: isPlaying ?? this.isPlaying,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      queue: queue ?? this.queue,
      currentIndex: currentIndex ?? this.currentIndex,
      isShuffle: isShuffle ?? this.isShuffle,
      loopMode: loopMode ?? this.loopMode,
      isLoading: isLoading ?? this.isLoading,
      recentlyPlayed: recentlyPlayed ?? this.recentlyPlayed,
    );
  }
}

class AudioPlayerController extends StateNotifier<PlayerStateData> {
  final AudioPlayerHandler _audioHandler;
  final SupabaseSongsRepository _songsRepo;
  final KeyManager _keyManager;
  final StatePersistenceService _persistenceService;

  AudioPlayerController({
    required AudioPlayerHandler audioHandler,
    required SupabaseSongsRepository songsRepo,
    required KeyManager keyManager,
    required StatePersistenceService persistenceService,
  })  : _audioHandler = audioHandler,
        _songsRepo = songsRepo,
        _keyManager = keyManager,
        _persistenceService = persistenceService,
        super(const PlayerStateData()) {
    // Connect notification and headset/bluetooth buttons directly to shared controller
    _audioHandler.onSkipToNext = () => skipToNext();
    _audioHandler.onSkipToPrevious = () => skipToPrevious();

    _listenToPlayerStreams();
    _restoreSavedState();
  }

  Future<void> _restoreSavedState() async {
    try {
      final saved = await _persistenceService.loadState();
      if (saved != null) {
        state = state.copyWith(
          currentSong: saved.currentSong,
          position: Duration(milliseconds: saved.positionMs),
          queue: saved.queue,
          currentIndex: saved.currentIndex,
          recentlyPlayed: saved.recentlyPlayed,
        );

        if (saved.currentSong != null) {
          final song = saved.currentSong!;
          final localArtUri = await ArtCacheService.getLocalArtUri(song.coverUrl);

          // Update notification/lock screen media item so it's ready
          _audioHandler.updateMediaItem(
            MediaItem(
              id: song.id,
              album: song.album,
              title: song.title,
              artist: song.artist,
              artUri: localArtUri,
              duration: Duration(milliseconds: song.durationMs),
            ),
          );

          // Prepare the player audio source at the saved position without auto-playing
          try {
            await _setupAudioSource(song);
            if (saved.positionMs > 0) {
              await _audioHandler.player.seek(Duration(milliseconds: saved.positionMs));
            }
          } catch (_) {}
        }
      }
    } catch (_) {}
  }

  void _listenToPlayerStreams() {
    _audioHandler.player.playerStateStream.listen((playerState) {
      state = state.copyWith(
        isPlaying: playerState.playing,
        isLoading: playerState.processingState == ProcessingState.buffering ||
                   playerState.processingState == ProcessingState.loading,
      );

      if (playerState.processingState == ProcessingState.completed) {
        if (state.loopMode == PlayerLoopMode.one) {
          seek(Duration.zero);
          _audioHandler.player.play();
        } else {
          skipToNext();
        }
      }
    });

    _audioHandler.player.positionStream.listen((pos) {
      state = state.copyWith(position: pos);
      _persistCurrentStateDebounced();
    });

    _audioHandler.player.durationStream.listen((dur) {
      if (dur != null) {
        state = state.copyWith(duration: dur);
      }
    });
  }

  DateTime _lastPersist = DateTime.now();
  void _persistCurrentStateDebounced() {
    final now = DateTime.now();
    if (now.difference(_lastPersist).inSeconds >= 3) {
      _lastPersist = now;
      _saveStateToDisk();
    }
  }

  void _saveStateToDisk() {
    _persistenceService.saveState(
      AppSavedState(
        currentSong: state.currentSong,
        positionMs: state.position.inMilliseconds,
        queue: state.queue,
        currentIndex: state.currentIndex,
        recentlyPlayed: state.recentlyPlayed,
      ),
    );
  }

  void _addToRecentlyPlayed(SongModel song) {
    final list = List<SongModel>.from(state.recentlyPlayed);
    // Remove if already present (no duplicates, replayed moves to front)
    list.removeWhere((s) => s.id == song.id);
    list.insert(0, song);
    // Keep max 20 tracks
    if (list.length > 20) {
      list.removeRange(20, list.length);
    }
    state = state.copyWith(recentlyPlayed: list);
    _saveStateToDisk();
  }

  Future<void> _setupAudioSource(SongModel song) async {
    final appDocDir = await getApplicationDocumentsDirectory();
    final offlineMp3 = File(p.join(appDocDir.path, 'offline_music', '${song.id}.mp3'));
    final secureDat = File(p.join(appDocDir.path, 'secure_audio', '${song.id}.dat'));

    if (offlineMp3.existsSync()) {
      await _audioHandler.player.setFilePath(offlineMp3.path);
    } else if (song.localPath != null && File(song.localPath!).existsSync()) {
      final f = File(song.localPath!);
      if (f.path.endsWith('.mp3')) {
        await _audioHandler.player.setFilePath(f.path);
      } else {
        final key = await _keyManager.getOrCreateMasterKey();
        final source = EncryptedAudioSource(file: f, key: key);
        await _audioHandler.player.setAudioSource(source);
      }
    } else if (secureDat.existsSync()) {
      final key = await _keyManager.getOrCreateMasterKey();
      final source = EncryptedAudioSource(file: secureDat, key: key);
      await _audioHandler.player.setAudioSource(source);
    } else {
      final res = await _songsRepo.getSignedAudioUrl(song.storagePath);
      final url = res.dataOrNull ?? song.storagePath;
      await _audioHandler.player.setUrl(url);
    }
  }

  Future<void> playSong(SongModel song, {List<SongModel>? queue, int? index}) async {
    state = state.copyWith(isLoading: true, currentSong: song);

    final effectiveQueue = queue ?? [song];
    final effectiveIndex = index ?? effectiveQueue.indexOf(song);

    state = state.copyWith(
      queue: effectiveQueue,
      currentIndex: effectiveIndex >= 0 ? effectiveIndex : 0,
    );

    _addToRecentlyPlayed(song);
    _saveStateToDisk();

    // 1. Resolve local/cached artUri bitmap for notification and lockscreen
    final localArtUri = await ArtCacheService.getLocalArtUri(song.coverUrl);

    // 2. Update system lockscreen & notification media item
    _audioHandler.updateMediaItem(
      MediaItem(
        id: song.id,
        album: song.album,
        title: song.title,
        artist: song.artist,
        artUri: localArtUri,
        duration: Duration(milliseconds: song.durationMs),
      ),
    );

    try {
      await _setupAudioSource(song);
      await _audioHandler.play();
      state = state.copyWith(isLoading: false, isPlaying: true);
      _saveStateToDisk();
    } catch (e) {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> togglePlayPause() async {
    if (state.currentSong != null) {
      if (_audioHandler.player.playing) {
        await _audioHandler.pause();
        state = state.copyWith(isPlaying: false);
      } else {
        await _audioHandler.play();
        state = state.copyWith(isPlaying: true);
      }
      _saveStateToDisk();
    } else if (state.queue.isNotEmpty) {
      await playSong(state.queue.first, queue: state.queue, index: 0);
    }
  }

  Future<void> seek(Duration pos) async {
    await _audioHandler.seek(pos);
    state = state.copyWith(position: pos);
    _saveStateToDisk();
  }

  Future<void> skipToNext() async {
    if (state.queue.isEmpty) return;
    int nextIdx = state.currentIndex + 1;
    if (nextIdx >= state.queue.length) {
      if (state.loopMode == PlayerLoopMode.all) {
        nextIdx = 0;
      } else {
        return;
      }
    }
    await playSong(state.queue[nextIdx], queue: state.queue, index: nextIdx);
  }

  Future<void> skipToPrevious() async {
    if (state.queue.isEmpty) return;
    int prevIdx = state.currentIndex - 1;
    if (prevIdx < 0) {
      prevIdx = state.loopMode == PlayerLoopMode.all ? state.queue.length - 1 : 0;
    }
    await playSong(state.queue[prevIdx], queue: state.queue, index: prevIdx);
  }

  void toggleShuffle() {
    state = state.copyWith(isShuffle: !state.isShuffle);
  }

  void toggleLoop() {
    final nextMode = switch (state.loopMode) {
      PlayerLoopMode.off => PlayerLoopMode.all,
      PlayerLoopMode.all => PlayerLoopMode.one,
      PlayerLoopMode.one => PlayerLoopMode.off,
    };
    state = state.copyWith(loopMode: nextMode);
  }

  void playNext(SongModel song) {
    final newQueue = List<SongModel>.from(state.queue);
    final insertPos = (state.currentIndex >= 0 && state.currentIndex < newQueue.length)
        ? state.currentIndex + 1
        : newQueue.length;
    newQueue.insert(insertPos, song);
    state = state.copyWith(queue: newQueue);
    _saveStateToDisk();
  }

  void addToQueue(SongModel song) {
    final newQueue = List<SongModel>.from(state.queue)..add(song);
    state = state.copyWith(queue: newQueue);
    _saveStateToDisk();
  }

  void reorderQueue(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final items = List<SongModel>.from(state.queue);
    final song = items.removeAt(oldIndex);
    items.insert(newIndex, song);

    // Update currentIndex if moved item was before or was current
    int updatedCurrentIndex = state.currentIndex;
    if (oldIndex == state.currentIndex) {
      updatedCurrentIndex = newIndex;
    } else if (oldIndex < state.currentIndex && newIndex >= state.currentIndex) {
      updatedCurrentIndex -= 1;
    } else if (oldIndex > state.currentIndex && newIndex <= state.currentIndex) {
      updatedCurrentIndex += 1;
    }

    state = state.copyWith(queue: items, currentIndex: updatedCurrentIndex);
    _saveStateToDisk();
  }

  void removeFromQueue(int index) {
    if (index < 0 || index >= state.queue.length) return;
    final items = List<SongModel>.from(state.queue);
    items.removeAt(index);
    int updatedCurrentIndex = state.currentIndex;
    if (index < state.currentIndex) {
      updatedCurrentIndex -= 1;
    }
    state = state.copyWith(queue: items, currentIndex: updatedCurrentIndex);
    _saveStateToDisk();
  }

  void clearQueue() {
    state = state.copyWith(
      queue: state.currentSong != null ? [state.currentSong!] : [],
      currentIndex: 0,
    );
    _saveStateToDisk();
  }
}

// Global reference for audioHandler to ensure singleton lifecycle
AudioPlayerHandler? _globalAudioHandler;

final audioPlayerHandlerProvider = Provider<AudioPlayerHandler>((ref) {
  _globalAudioHandler ??= AudioPlayerHandler();
  return _globalAudioHandler!;
});

final supabaseSongsRepoProvider = Provider<SupabaseSongsRepository>((ref) => SupabaseSongsRepository());
final keyManagerProvider = Provider<KeyManager>((ref) => KeyManager());

final audioPlayerControllerProvider =
    StateNotifierProvider<AudioPlayerController, PlayerStateData>((ref) {
  return AudioPlayerController(
    audioHandler: ref.watch(audioPlayerHandlerProvider),
    songsRepo: ref.watch(supabaseSongsRepoProvider),
    keyManager: ref.watch(keyManagerProvider),
    persistenceService: ref.watch(statePersistenceServiceProvider),
  );
});
