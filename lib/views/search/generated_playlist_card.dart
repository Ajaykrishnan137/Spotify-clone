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
        width: 104,
        height: 104,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Dimensions.radiusMedium),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(Dimensions.radiusMedium),
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
      return Container(
        width: 104,
        height: 104,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Dimensions.radiusMedium),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: AppImage(
          url: covers.first,
          width: 104,
          height: 104,
          borderRadius: Dimensions.radiusMedium,
          fit: BoxFit.cover,
        ),
      );
    }

    return Container(
      width: 104,
      height: 104,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Dimensions.radiusMedium),
        gradient: const LinearGradient(
          colors: [Color(0xFF38D6FF), Color(0xFF1E90FF), Color(0xFF7C4DFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: Icon(Icons.queue_music_rounded, color: Colors.white, size: 40),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(Dimensions.space16, 4, Dimensions.space16, 12),
      padding: const EdgeInsets.all(Dimensions.space16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
        gradient: const LinearGradient(
          colors: [Color(0xFF1A2244), Color(0xFF0F1528), Color(0xFF0B1026)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: AppColors.cyanAccent.withOpacity(0.3), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: AppColors.cyanAccent.withOpacity(0.12),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: Collage cover + Meta details
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
                        color: AppColors.cyanAccent.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.auto_awesome, color: AppColors.cyanAccent, size: 12),
                          SizedBox(width: 4),
                          Text(
                            'AUTO-GENERATED PLAYLIST',
                            style: TextStyle(
                              color: AppColors.cyanAccent,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
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
                      '100% Legal & Licensed Sources',
                      style: TextStyle(
                        color: Color(0xFF00E676),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
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
                // Play button
                ElevatedButton.icon(
                  onPressed: onPlay,
                  icon: const Icon(Icons.play_arrow_rounded, color: Colors.black, size: 20),
                  label: const Text('Play', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 13)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.cyanAccent,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                ),
                const SizedBox(width: 8),

                // Shuffle button
                OutlinedButton.icon(
                  onPressed: onShuffle,
                  icon: const Icon(Icons.shuffle_rounded, color: Colors.white, size: 18),
                  label: const Text('Shuffle', style: TextStyle(color: Colors.white, fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white38),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                ),
                const SizedBox(width: 8),

                // Save as playlist button
                OutlinedButton.icon(
                  onPressed: onSave,
                  icon: Icon(
                    isSaved ? Icons.check_circle_outline : Icons.bookmark_add_outlined,
                    color: isSaved ? AppColors.cyanAccent : Colors.white,
                    size: 18,
                  ),
                  label: Text(
                    isSaved ? 'Saved' : 'Save as playlist',
                    style: TextStyle(color: isSaved ? AppColors.cyanAccent : Colors.white, fontSize: 13),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: isSaved ? AppColors.cyanAccent : Colors.white38),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                ),
                const SizedBox(width: 8),

                // Download all button
                OutlinedButton.icon(
                  onPressed: onDownloadAll,
                  icon: const Icon(Icons.download_rounded, color: Colors.white, size: 18),
                  label: const Text('Download all', style: TextStyle(color: Colors.white, fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white38),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
