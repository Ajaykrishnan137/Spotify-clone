import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/song_model.dart';
import '../../models/download_state.dart';
import '../../controllers/download_controller.dart';
import '../../controllers/playlist_controller.dart';
import '../../controllers/audio_player_controller.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/dimensions.dart';
import 'app_image.dart';
import 'download_button.dart';
import 'spotify_logo.dart';
import 'animated_equalizer_bars.dart';
import 'add_to_playlist_sheet.dart';

class SongTile extends ConsumerWidget {
  final SongModel song;
  final bool isPlaying;
  final VoidCallback onTap;
  final Widget? trailing;
  final VoidCallback? onRemoveFromPlaylist;

  const SongTile({
    super.key,
    required this.song,
    this.isPlaying = false,
    required this.onTap,
    this.trailing,
    this.onRemoveFromPlaylist,
  });

  void _showSongOptions(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Dimensions.radiusLarge)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: Dimensions.space16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: AppImage(url: song.coverUrl, width: 44, height: 44),
                  title: Text(
                    song.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  subtitle: Text(
                    song.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ),
                const Divider(color: AppColors.card),
                ListTile(
                  leading: const Icon(Icons.playlist_play, color: AppColors.textPrimary),
                  title: const Text('Play Next', style: TextStyle(color: AppColors.textPrimary)),
                  onTap: () {
                    Navigator.pop(ctx);
                    ref.read(audioPlayerControllerProvider.notifier).playNext(song);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Playing next: "${song.title}"'), backgroundColor: AppColors.accent),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.queue_music, color: AppColors.textPrimary),
                  title: const Text('Add to Queue', style: TextStyle(color: AppColors.textPrimary)),
                  onTap: () {
                    Navigator.pop(ctx);
                    ref.read(audioPlayerControllerProvider.notifier).addToQueue(song);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Added to queue: "${song.title}"'), backgroundColor: AppColors.accent),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.playlist_add, color: AppColors.textPrimary),
                  title: const Text('Add to Playlist', style: TextStyle(color: AppColors.textPrimary)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showAddToPlaylistDialog(context, ref);
                  },
                ),
                if (onRemoveFromPlaylist != null)
                  ListTile(
                    leading: const Icon(Icons.playlist_remove, color: AppColors.error),
                    title: const Text('Remove from this playlist', style: TextStyle(color: AppColors.error)),
                    onTap: () {
                      Navigator.pop(ctx);
                      onRemoveFromPlaylist!();
                    },
                  ),
                ListTile(
                  leading: const Icon(Icons.download, color: AppColors.textPrimary),
                  title: const Text('Download for Offline Play', style: TextStyle(color: AppColors.textPrimary)),
                  onTap: () {
                    Navigator.pop(ctx);
                    ref.read(downloadControllerProvider.notifier).startDownload(song);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Downloading "${song.title}"...'), backgroundColor: AppColors.accent),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAddToPlaylistDialog(BuildContext context, WidgetRef ref) {
    AddToPlaylistSheet.show(context, songs: [song]);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloadTasks = ref.watch(downloadControllerProvider);
    final themeColor = ref.watch(nowPlayingThemeColorProvider);
    final task = downloadTasks[song.id] ?? DownloadTaskState(songId: song.id);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
      child: Container(
        height: Dimensions.songTileHeight,
        padding: const EdgeInsets.symmetric(horizontal: Dimensions.space16, vertical: Dimensions.space8),
        child: Row(
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                AppImage(
                  url: song.coverUrl,
                  width: 48,
                  height: 48,
                  borderRadius: Dimensions.radiusSmall,
                ),
                if (isPlaying)
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
                    ),
                    child: Center(
                      child: AnimatedEqualizerBars(
                        color: themeColor,
                        size: 22,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: Dimensions.space12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    song.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isPlaying ? themeColor : AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: Dimensions.space2),
                  Row(
                    children: [
                      if (song.isDownloaded || task.status == DownloadStatus.downloaded) ...[
                        Icon(Icons.download_done, color: isPlaying ? themeColor : AppColors.accent, size: 14),
                        const SizedBox(width: Dimensions.space4),
                      ],
                      Expanded(
                        child: Text(
                          song.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (trailing != null)
              trailing!
            else
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DownloadButton(
                    status: task.status,
                    progress: task.progress,
                    onDownload: () => ref.read(downloadControllerProvider.notifier).startDownload(song),
                    onDelete: () => ref.read(downloadControllerProvider.notifier).deleteDownload(song.id),
                    onCancel: () => ref.read(downloadControllerProvider.notifier).cancelTrackDownload(song.id),
                  ),
                  IconButton(
                    icon: const Icon(Icons.more_vert, color: AppColors.textSecondary, size: 20),
                    onPressed: () => _showSongOptions(context, ref),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
