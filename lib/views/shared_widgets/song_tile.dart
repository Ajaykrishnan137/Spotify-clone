import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/song_model.dart';
import '../../models/download_state.dart';
import '../../controllers/download_controller.dart';
import '../../controllers/playlist_controller.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/dimensions.dart';
import 'app_image.dart';
import 'download_button.dart';
import 'spotify_logo.dart';
import 'animated_equalizer_bars.dart';

class SongTile extends ConsumerWidget {
  final SongModel song;
  final bool isPlaying;
  final VoidCallback onTap;
  final Widget? trailing;

  const SongTile({
    super.key,
    required this.song,
    this.isPlaying = false,
    required this.onTap,
    this.trailing,
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
                  title: Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  subtitle: Text(song.artist, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textSecondary)),
                ),
                const Divider(color: AppColors.card),
                ListTile(
                  leading: const Icon(Icons.playlist_add, color: AppColors.textPrimary),
                  title: const Text('Add to Playlist', style: TextStyle(color: AppColors.textPrimary)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showAddToPlaylistDialog(context, ref);
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
    final playlistsAsync = ref.read(localPlaylistControllerProvider);

    playlistsAsync.whenData((playlists) {
      if (playlists.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No playlists yet! Create one in Your Library first.')),
        );
        return;
      }

      showDialog(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            backgroundColor: AppColors.card,
            title: const Text('Add to Playlist', style: TextStyle(color: AppColors.textPrimary)),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: playlists.length,
                itemBuilder: (c, idx) {
                  final pl = playlists[idx];
                  return ListTile(
                    leading: const Icon(Icons.queue_music, color: AppColors.accent),
                    title: Text(pl.name, style: const TextStyle(color: AppColors.textPrimary)),
                    onTap: () {
                      ref.read(localPlaylistControllerProvider.notifier).addSongToPlaylist(pl.id, song);
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Added to "${pl.name}"'), backgroundColor: AppColors.accent),
                      );
                    },
                  );
                },
              ),
            ),
          );
        },
      );
    });
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
