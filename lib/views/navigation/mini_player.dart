import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../controllers/audio_player_controller.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/dimensions.dart';
import '../shared_widgets/app_image.dart';
import '../shared_widgets/spotify_logo.dart';
import '../shared_widgets/animated_equalizer_bars.dart';
import 'now_playing_sheet.dart';

class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(audioPlayerControllerProvider);
    final themeColor = ref.watch(nowPlayingThemeColorProvider);
    final currentSong = playerState.currentSong;

    if (currentSong == null) {
      return const SizedBox.shrink();
    }

    final double progress = (playerState.duration.inMilliseconds > 0)
        ? (playerState.position.inMilliseconds / playerState.duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          backgroundColor: Colors.transparent,
          builder: (_) => const NowPlayingSheet(),
        );
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        height: Dimensions.miniPlayerHeight,
        margin: const EdgeInsets.symmetric(horizontal: Dimensions.space8, vertical: Dimensions.space4),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              themeColor.withOpacity(0.35),
              AppColors.elevated,
            ],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(Dimensions.radiusMedium),
          boxShadow: [
            BoxShadow(
              color: themeColor.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  AppImage(
                    url: currentSong.coverUrl,
                    width: Dimensions.miniPlayerHeight - 2,
                    height: Dimensions.miniPlayerHeight - 2,
                    borderRadius: Dimensions.radiusSmall,
                  ),
                  const SizedBox(width: Dimensions.space12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          currentSong.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: Dimensions.space2),
                        Row(
                          children: [
                            if (playerState.isPlaying) ...[
                              AnimatedEqualizerBars(color: themeColor, size: 12),
                              const SizedBox(width: 6),
                            ],
                            Expanded(
                              child: Text(
                                currentSong.artist,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      ref.read(audioPlayerControllerProvider.notifier).togglePlayPause();
                    },
                    child: Container(
                      width: 38,
                      height: 38,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1E90FF), Color(0xFF38D6FF)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF38D6FF).withOpacity(0.4),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Icon(
                        playerState.isPlaying ? Icons.pause : Icons.play_arrow,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.skip_next, color: AppColors.textPrimary, size: 24),
                    onPressed: () {
                      ref.read(audioPlayerControllerProvider.notifier).skipToNext();
                    },
                  ),
                ],
              ),
            ),
            // Bottom mini progress bar
            LinearProgressIndicator(
              value: progress,
              backgroundColor: AppColors.surface,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.cyanAccent),
              minHeight: 2.5,
            ),
          ],
        ),
      ),
    );
  }
}
