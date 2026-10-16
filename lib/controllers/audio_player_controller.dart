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
import '../data/remote/supabase_songs_repository.dart';

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
    );
  }
}

class AudioPlayerController extends StateNotifier<PlayerStateData> {
  final AudioPlayerHandler _audioHandler;
  final SupabaseSongsRepository _songsRepo;
  final KeyManager _keyManager;

  AudioPlayerController({
    required AudioPlayerHandler audioHandler,
    required SupabaseSongsRepository songsRepo,
    required KeyManager keyManager,
  })  : _audioHandler = audioHandler,
        _songsRepo = songsRepo,
        _keyManager = keyManager,
        super(const PlayerStateData()) {
    _listenToPlayerStreams();
  }

  void _listenToPlayerStreams() {
    _audioHandler.player.playerStateStream.listen((playerState) {
      state = state.copyWith(
        isPlaying: playerState.playing,
        isLoading: playerState.processingState == ProcessingState.buffering ||
                   playerState.processingState == ProcessingState.loading,
      );

      if (playerState.processingState == ProcessingState.completed) {
        skipToNext();
      }
    });

    _audioHandler.player.positionStream.listen((pos) {
      state = state.copyWith(position: pos);
    });

    _audioHandler.player.durationStream.listen((dur) {
      if (dur != null) {
        state = state.copyWith(duration: dur);
      }
    });
  }

  Future<void> playSong(SongModel song, {List<SongModel>? queue, int? index}) async {
    state = state.copyWith(isLoading: true, currentSong: song);

    final effectiveQueue = queue ?? [song];
    final effectiveIndex = index ?? effectiveQueue.indexOf(song);

    state = state.copyWith(
      queue: effectiveQueue,
      currentIndex: effectiveIndex >= 0 ? effectiveIndex : 0,
    );

    // Update system lockscreen media item
    _audioHandler.updateMediaItem(
      MediaItem(
        id: song.id,
        album: song.album,
        title: song.title,
        artist: song.artist,
        artUri: Uri.tryParse(song.coverUrl),
        duration: Duration(milliseconds: song.durationMs),
      ),
    );

    try {
      // Check if downloaded offline file exists (check offline_music mp3 first, then secure_audio dat)
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
        // Fetch streaming URL
        final res = await _songsRepo.getSignedAudioUrl(song.storagePath);
        final url = res.dataOrNull ?? song.storagePath;
        await _audioHandler.player.setUrl(url);
      }

      await _audioHandler.player.play();
      state = state.copyWith(isLoading: false, isPlaying: true);
    } catch (e) {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> togglePlayPause() async {
    // If no song is loaded or playback state is stopped/idle, resume or start first song
    if (state.currentSong != null) {
      if (_audioHandler.player.playing) {
        await _audioHandler.player.pause();
        state = state.copyWith(isPlaying: false);
      } else {
        await _audioHandler.player.play();
        state = state.copyWith(isPlaying: true);
      }
    }
  }

  Future<void> seek(Duration pos) async {
    await _audioHandler.player.seek(pos);
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

  void reorderQueue(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final items = List<SongModel>.from(state.queue);
    final song = items.removeAt(oldIndex);
    items.insert(newIndex, song);
    state = state.copyWith(queue: items);
  }

  void clearQueue() {
    state = state.copyWith(queue: state.currentSong != null ? [state.currentSong!] : [], currentIndex: 0);
  }
}

final audioPlayerHandlerProvider = Provider<AudioPlayerHandler>((ref) => AudioPlayerHandler());
final supabaseSongsRepoProvider = Provider<SupabaseSongsRepository>((ref) => SupabaseSongsRepository());
final keyManagerProvider = Provider<KeyManager>((ref) => KeyManager());

final audioPlayerControllerProvider =
    StateNotifierProvider<AudioPlayerController, PlayerStateData>((ref) {
  return AudioPlayerController(
    audioHandler: ref.watch(audioPlayerHandlerProvider),
    songsRepo: ref.watch(supabaseSongsRepoProvider),
    keyManager: ref.watch(keyManagerProvider),
  );
});
