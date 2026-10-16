import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:palette_generator/palette_generator.dart';
import '../../controllers/audio_player_controller.dart';
import '../../controllers/download_controller.dart';
import '../../models/download_state.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/dimensions.dart';
import '../../core/utils/formatters.dart';
import '../shared_widgets/app_image.dart';
import '../shared_widgets/download_button.dart';

class NowPlayingSheet extends ConsumerStatefulWidget {
  const NowPlayingSheet({super.key});

  @override
  ConsumerState<NowPlayingSheet> createState() => _NowPlayingSheetState();
}

class _NowPlayingSheetState extends ConsumerState<NowPlayingSheet> {
  Color _dominantColor = AppColors.surface;

  @override
  void initState() {
    super.initState();
    _extractPalette();
  }

  Future<void> _extractPalette() async {
    final song = ref.read(audioPlayerControllerProvider).currentSong;
    if (song != null && song.coverUrl.isNotEmpty) {
      try {
        final palette = await PaletteGenerator.fromImageProvider(
          CachedNetworkImageProvider(song.coverUrl),
          size: const Size(100, 100),
          maximumColorCount: 10,
        );
        if (mounted && palette.dominantColor != null) {
          setState(() {
            _dominantColor = palette.dominantColor!.color;
          });
        }
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final playerState = ref.watch(audioPlayerControllerProvider);
    final song = playerState.currentSong;

    if (song == null) {
      return const SizedBox.shrink();
    }

    final double maxMs = playerState.duration.inMilliseconds.toDouble();
    final double curMs = playerState.position.inMilliseconds.toDouble().clamp(0.0, maxMs > 0 ? maxMs : 1.0);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            _dominantColor.withOpacity(0.85),
            AppColors.background,
          ],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Dimensions.space24),
          child: Column(
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.keyboard_arrow_down, size: 30),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Column(
                    children: [
                      const Text(
                        'PLAYING FROM PLAYLIST',
                        style: TextStyle(fontSize: 10, letterSpacing: 1.0, color: AppColors.textSecondary),
                      ),
                      Text(
                        song.album,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.more_vert),
                    onPressed: () {},
                  ),
                ],
              ),
              const Spacer(),
              // Cover Art
              AppImage(
                url: song.coverUrl,
                width: MediaQuery.of(context).size.width - 48,
                height: MediaQuery.of(context).size.width - 48,
                borderRadius: Dimensions.radiusLarge,
              ),
              const Spacer(),
              // Title & Artist
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          song.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: Dimensions.space4),
                        Text(
                          song.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Consumer(
                        builder: (context, ref, _) {
                          final downloadTasks = ref.watch(downloadControllerProvider);
                          final task = downloadTasks[song.id] ?? DownloadTaskState(songId: song.id);
                          return DownloadButton(
                            status: task.status,
                            progress: task.progress,
                            onDownload: () => ref.read(downloadControllerProvider.notifier).startDownload(song),
                            onDelete: () => ref.read(downloadControllerProvider.notifier).deleteDownload(song.id),
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.favorite_border, color: AppColors.textPrimary, size: 28),
                        onPressed: () {},
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: Dimensions.space16),
              // Progress Slider
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                  activeTrackColor: AppColors.textPrimary,
                  inactiveTrackColor: AppColors.textSecondary.withOpacity(0.3),
                  thumbColor: AppColors.textPrimary,
                ),
                child: Slider(
                  value: curMs,
                  max: maxMs > 0 ? maxMs : 1.0,
                  onChanged: (val) {
                    ref.read(audioPlayerControllerProvider.notifier).seek(
                          Duration(milliseconds: val.toInt()),
                        );
                  },
                ),
              ),
              // Time stamps
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Dimensions.space8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      Formatters.formatDuration(playerState.position),
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                    ),
                    Text(
                      Formatters.formatDuration(playerState.duration),
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: Dimensions.space16),
              // Main Playback Controls
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.shuffle,
                      color: playerState.isShuffle ? AppColors.accent : AppColors.textSecondary,
                    ),
                    onPressed: () {
                      ref.read(audioPlayerControllerProvider.notifier).toggleShuffle();
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.skip_previous, size: 36, color: AppColors.textPrimary),
                    onPressed: () {
                      ref.read(audioPlayerControllerProvider.notifier).skipToPrevious();
                    },
                  ),
                  GestureDetector(
                    onTap: () {
                      ref.read(audioPlayerControllerProvider.notifier).togglePlayPause();
                    },
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: const BoxDecoration(
                        color: AppColors.textPrimary,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        playerState.isPlaying ? Icons.pause : Icons.play_arrow,
                        color: Colors.black,
                        size: 36,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.skip_next, size: 36, color: AppColors.textPrimary),
                    onPressed: () {
                      ref.read(audioPlayerControllerProvider.notifier).skipToNext();
                    },
                  ),
                  IconButton(
                    icon: Icon(
                      playerState.loopMode == PlayerLoopMode.one ? Icons.repeat_one : Icons.repeat,
                      color: playerState.loopMode != PlayerLoopMode.off ? AppColors.accent : AppColors.textSecondary,
                    ),
                    onPressed: () {
                      ref.read(audioPlayerControllerProvider.notifier).toggleLoop();
                    },
                  ),
                ],
              ),
              const SizedBox(height: Dimensions.space32),
            ],
          ),
        ),
      ),
    );
  }
}
