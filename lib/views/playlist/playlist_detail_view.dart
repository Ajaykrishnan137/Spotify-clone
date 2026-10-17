import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/song_model.dart';
import '../../models/download_state.dart';
import '../../controllers/audio_player_controller.dart';
import '../../controllers/download_controller.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/dimensions.dart';
import '../shared_widgets/app_image.dart';
import '../shared_widgets/song_tile.dart';

class PlaylistDetailView extends ConsumerWidget {
  final String title;
  final String subtitle;
  final String? coverUrl;
  final List<SongModel> songs;

  const PlaylistDetailView({
    super.key,
    required this.title,
    required this.subtitle,
    this.coverUrl,
    required this.songs,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(audioPlayerControllerProvider);
    final batchStatus = ref.watch(batchDownloadStatusStreamProvider).value ??
        ref.read(downloadControllerProvider.notifier).currentBatchStatus;
    final downloadTasks = ref.watch(downloadControllerProvider);

    final allDownloaded = songs.isNotEmpty &&
        songs.every((s) => downloadTasks[s.id]?.status == DownloadStatus.downloaded);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 280.0,
            pinned: true,
            backgroundColor: AppColors.surface,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  if (coverUrl != null && coverUrl!.isNotEmpty)
                    AppImage(url: coverUrl!, fit: BoxFit.cover, borderRadius: 0)
                  else
                    Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF2E77D0), Color(0xFF121212)],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                      child: const Center(
                        child: Icon(Icons.music_note, size: 80, color: Colors.white54),
                      ),
                    ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.transparent, AppColors.background.withOpacity(0.9), AppColors.background],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Download All active progress & control card
          if (batchStatus.isBatchActive)
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: Dimensions.space16, vertical: Dimensions.space8),
                padding: const EdgeInsets.all(Dimensions.space12),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(Dimensions.radiusMedium),
                  border: Border.all(color: AppColors.accent.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.downloading, color: AppColors.accent, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            batchStatus.isPaused
                                ? 'Download paused (${batchStatus.completedCount}/${batchStatus.totalCount})'
                                : 'Downloading ${batchStatus.completedCount}/${batchStatus.totalCount} tracks...',
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        // Pause / Resume Button
                        IconButton(
                          icon: Icon(
                            batchStatus.isPaused ? Icons.play_arrow : Icons.pause,
                            color: AppColors.textPrimary,
                            size: 22,
                          ),
                          tooltip: batchStatus.isPaused ? 'Resume' : 'Pause',
                          onPressed: () {
                            if (batchStatus.isPaused) {
                              ref.read(downloadControllerProvider.notifier).resumeBatchDownload();
                            } else {
                              ref.read(downloadControllerProvider.notifier).pauseBatchDownload();
                            }
                          },
                        ),
                        // Cancel / Stop Button
                        IconButton(
                          icon: const Icon(Icons.stop_circle_outlined, color: AppColors.error, size: 24),
                          tooltip: 'Stop & Cancel Download All',
                          onPressed: () {
                            ref.read(downloadControllerProvider.notifier).cancelBatchDownload();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Download stopped. Partial files deleted.'),
                                backgroundColor: AppColors.surface,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    LinearProgressIndicator(
                      value: batchStatus.totalCount > 0
                          ? (batchStatus.completedCount / batchStatus.totalCount).clamp(0.0, 1.0)
                          : null,
                      backgroundColor: AppColors.surface,
                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accent),
                      minHeight: 4,
                    ),
                    if (batchStatus.currentSongTitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Current: ${batchStatus.currentSongTitle}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                      ),
                    ],
                  ],
                ),
              ),
            ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Dimensions.space16, vertical: Dimensions.space12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(subtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                        const SizedBox(height: 4),
                        Text(
                          '${songs.length} songs',
                          style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),

                  // Download All or Stop button in action row
                  if (batchStatus.isBatchActive)
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error.withOpacity(0.2),
                        foregroundColor: AppColors.error,
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text('Cancel All'),
                      onPressed: () {
                        ref.read(downloadControllerProvider.notifier).cancelBatchDownload();
                      },
                    )
                  else
                    IconButton(
                      icon: Icon(
                        allDownloaded ? Icons.download_done : Icons.arrow_circle_down_rounded,
                        color: allDownloaded ? AppColors.accent : AppColors.textSecondary,
                        size: 28,
                      ),
                      tooltip: allDownloaded ? 'Playlist Downloaded' : 'Download all',
                      onPressed: () {
                        if (!allDownloaded) {
                          ref.read(downloadControllerProvider.notifier).downloadMultipleSongs(songs);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Starting download of ${songs.length} songs...'),
                              duration: const Duration(seconds: 2),
                              backgroundColor: AppColors.card,
                            ),
                          );
                        }
                      },
                    ),

                  const SizedBox(width: Dimensions.space12),
                  FloatingActionButton(
                    backgroundColor: AppColors.accent,
                    elevation: 4,
                    onPressed: () {
                      if (songs.isEmpty) return;
                      final isCurrentPlaylistPlaying = songs.any((s) => s.id == playerState.currentSong?.id);
                      if (isCurrentPlaylistPlaying) {
                        ref.read(audioPlayerControllerProvider.notifier).togglePlayPause();
                      } else {
                        ref.read(audioPlayerControllerProvider.notifier).playSong(
                              songs.first,
                              queue: songs,
                              index: 0,
                            );
                      }
                    },
                    child: Icon(
                      (songs.any((s) => s.id == playerState.currentSong?.id) && playerState.isPlaying)
                          ? Icons.pause
                          : Icons.play_arrow,
                      color: Colors.black,
                      size: 36,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final song = songs[index];
                return SongTile(
                  song: song,
                  isPlaying: playerState.currentSong?.id == song.id,
                  onTap: () {
                    ref.read(audioPlayerControllerProvider.notifier).playSong(
                          song,
                          queue: songs,
                          index: index,
                        );
                  },
                );
              },
              childCount: songs.length,
            ),
          ),
          const SliverToBoxAdapter(
            child: SizedBox(height: Dimensions.space64),
          ),
        ],
      ),
    );
  }
}
