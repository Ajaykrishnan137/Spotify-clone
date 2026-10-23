import 'dart:io';
import 'package:flutter/material.dart';
import '../../models/song_model.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/dimensions.dart';
import '../shared_widgets/app_image.dart';

class GeneratedPlaylistCard extends StatelessWidget {
  final String title;
  final List<SongModel> songs;
  final VoidCallback onPlay;
  final VoidCallback onShuffle;
  final VoidCallback onSave;
  final VoidCallback onDownloadAll;
  final bool isSaved;

  const GeneratedPlaylistCard({
    super.key,
    required this.title,
    required this.songs,
    required this.onPlay,
    required this.onShuffle,
    required this.onSave,
    required this.onDownloadAll,
    this.isSaved = false,
  });

  String _formatTotalDuration() {
    int totalMs = 0;
    for (final s in songs) {
      totalMs += s.durationMs;
    }
    final totalSec = totalMs ~/ 1000;
    final mins = totalSec ~/ 60;
    final hours = mins ~/ 60;
    final remMins = mins % 60;

    if (hours > 0) {
      return '$hours hr $remMins min';
    }
    return '$mins min';
  }

  Widget _buildCollageCover() {
    final covers = songs.take(4).map((s) => s.coverUrl).where((u) => u.isNotEmpty).toList();

    if (covers.length >= 4) {
      return Container(
        width: 96,
        height: 96,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Column(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Expanded(child: AppImage(url: covers[0], fit: BoxFit.cover, borderRadius: 0)),
                    Expanded(child: AppImage(url: covers[1], fit: BoxFit.cover, borderRadius: 0)),
                  ],
                ),
              ),
              Expanded(
                child: Row(
                  children: [
                    Expanded(child: AppImage(url: covers[2], fit: BoxFit.cover, borderRadius: 0)),
                    Expanded(child: AppImage(url: covers[3], fit: BoxFit.cover, borderRadius: 0)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    } else if (covers.isNotEmpty) {
      return AppImage(
        url: covers.first,
        width: 96,
        height: 96,
        borderRadius: 8,
        fit: BoxFit.cover,
      );
    }

    return Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: AppColors.elevated,
      ),
      child: const Center(
        child: Icon(Icons.queue_music_rounded, color: AppColors.textSecondary, size: 36),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(Dimensions.space16, 4, Dimensions.space16, 12),
      padding: const EdgeInsets.all(Dimensions.space16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: AppColors.surface,
        border: Border.all(color: AppColors.dividers, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCollageCover(),
              const SizedBox(width: Dimensions.space16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.elevated,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'CURATED PLAYLIST',
                        style: TextStyle(
                          color: AppColors.primarySkyBlue,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${songs.length} songs • ${_formatTotalDuration()}',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Legal & Licensed Sources',
                      style: TextStyle(
                        color: AppColors.success,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Action Buttons: Play, Shuffle, Save as playlist, Download all
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ElevatedButton.icon(
                  onPressed: onPlay,
                  icon: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 20),
                  label: const Text('Play', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primarySkyBlue,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: onShuffle,
                  icon: const Icon(Icons.shuffle_rounded, color: AppColors.textPrimary, size: 18),
                  label: const Text('Shuffle', style: TextStyle(color: AppColors.textPrimary, fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.dividers),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: onSave,
                  icon: Icon(
                    isSaved ? Icons.check_circle_outline : Icons.bookmark_add_outlined,
                    color: isSaved ? AppColors.primarySkyBlue : AppColors.textPrimary,
                    size: 18,
                  ),
                  label: Text(
                    isSaved ? 'Saved' : 'Save as playlist',
                    style: TextStyle(color: isSaved ? AppColors.primarySkyBlue : AppColors.textPrimary, fontSize: 13),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: isSaved ? AppColors.primarySkyBlue : AppColors.dividers),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: onDownloadAll,
                  icon: const Icon(Icons.download_rounded, color: AppColors.textPrimary, size: 18),
                  label: const Text('Download all', style: TextStyle(color: AppColors.textPrimary, fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.dividers),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
