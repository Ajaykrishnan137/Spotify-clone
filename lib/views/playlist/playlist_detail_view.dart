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
                        Text('${songs.length} songs', style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  Consumer(
                    builder: (context, ref, _) {
                      final downloadTasks = ref.watch(downloadControllerProvider);
                      final allDownloaded = songs.isNotEmpty &&
                          songs.every((s) => downloadTasks[s.id]?.status == DownloadStatus.downloaded);
                      final isDownloadingAny =
                          songs.any((s) => downloadTasks[s.id]?.status == DownloadStatus.downloading);

                      return IconButton(
                        icon: isDownloadingAny
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
                              )
                            : Icon(
                                allDownloaded ? Icons.download_done : Icons.arrow_circle_down_rounded,
                                color: allDownloaded ? AppColors.accent : AppColors.textSecondary,
                                size: 28,
                              ),
                        tooltip: allDownloaded ? 'Playlist Downloaded' : 'Download Playlist',
                        onPressed: () {
                          if (!allDownloaded && !isDownloadingAny) {
                            ref.read(downloadControllerProvider.notifier).downloadMultipleSongs(songs);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Downloading ${songs.length} songs for offline listening...'),
                                duration: const Duration(seconds: 2),
                                backgroundColor: AppColors.card,
                              ),
                            );
                          }
                        },
                      );
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
