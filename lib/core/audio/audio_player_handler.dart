import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';

class AudioPlayerHandler extends BaseAudioHandler with SeekHandler {
  final AudioPlayer _player = AudioPlayer();
  AudioSession? _session;

  AudioPlayer get player => _player;

  AudioPlayerHandler() {
    _init();
  }

  Future<void> _init() async {
    // 1. Setup AudioSession for proper audio focus & ducking
    try {
      _session = await AudioSession.instance;
      await _session!.configure(const AudioSessionConfiguration.music());

      _session!.interruptionEventStream.listen((event) {
        if (event.begin) {
          switch (event.type) {
            case AudioInterruptionType.duck:
              _player.setVolume(0.3);
              break;
            case AudioInterruptionType.pause:
            case AudioInterruptionType.unknown:
              pause();
              break;
          }
        } else {
          switch (event.type) {
            case AudioInterruptionType.duck:
              _player.setVolume(1.0);
              break;
            case AudioInterruptionType.pause:
              play();
              break;
            case AudioInterruptionType.unknown:
              break;
          }
        }
      });

      _session!.becomingNoisyEventStream.listen((_) {
        // Unplugged headphones or disconnected bluetooth
        pause();
      });
    } catch (_) {}

    // 2. Broadcast playback state changes to Android foreground service & lock screen notification
    _player.playbackEventStream.listen((PlaybackEvent event) {
      final playing = _player.playing;
      playbackState.add(
        playbackState.value.copyWith(
          controls: [
            MediaControl.skipToPrevious,
            if (playing) MediaControl.pause else MediaControl.play,
            MediaControl.skipToNext,
            MediaControl.stop,
          ],
          systemActions: const {
            MediaAction.seek,
            MediaAction.seekForward,
            MediaAction.seekBackward,
            MediaAction.setShuffleMode,
            MediaAction.setRepeatMode,
          },
          androidCompactActionIndices: const [0, 1, 2],
          processingState: const {
            ProcessingState.idle: AudioProcessingState.idle,
            ProcessingState.loading: AudioProcessingState.loading,
            ProcessingState.buffering: AudioProcessingState.buffering,
            ProcessingState.ready: AudioProcessingState.ready,
            ProcessingState.completed: AudioProcessingState.completed,
          }[_player.processingState]!,
          playing: playing,
          updatePosition: _player.position,
          bufferedPosition: _player.bufferedPosition,
          speed: _player.speed,
          queueIndex: event.currentIndex,
        ),
      );
    });
  }

  @override
  Future<void> updateMediaItem(MediaItem item) async {
    mediaItem.add(item);
  }

  @override
  Future<void> play() async {
    await _session?.setActive(true);
    return _player.play();
  }

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> stop() async {
    await _player.stop();
    await _session?.setActive(false);
    return super.stop();
  }

  @override
  Future<void> skipToNext() async {
    // Handled by controller hook or custom action
  }

  @override
  Future<void> skipToPrevious() async {
    // Handled by controller hook or custom action
  }

  @override
  Future<void> onTaskRemoved() async {
    // Keeps service running when swiped from recents if playing
    if (!_player.playing) {
      await stop();
    }
  }
}
