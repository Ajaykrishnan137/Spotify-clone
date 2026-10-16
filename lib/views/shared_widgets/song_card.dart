import 'package:flutter/material.dart';
import '../../models/song_model.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/dimensions.dart';
import 'app_image.dart';

class SongCard extends StatelessWidget {
  final SongModel song;
  final VoidCallback onTap;

  const SongCard({
    super.key,
    required this.song,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Dimensions.radiusMedium),
      child: Container(
        width: Dimensions.songCardWidth,
        margin: const EdgeInsets.only(right: Dimensions.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppImage(
              url: song.coverUrl,
              width: Dimensions.songCardWidth,
              height: Dimensions.songCardWidth,
              borderRadius: Dimensions.radiusMedium,
            ),
            const SizedBox(height: Dimensions.space8),
            Text(
              song.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: Dimensions.space2),
            Text(
              song.artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
