import 'package:flutter/material.dart';
import '../../models/download_state.dart';
import '../../core/constants/app_colors.dart';

class DownloadButton extends StatelessWidget {
  final DownloadStatus status;
  final double progress;
  final VoidCallback onDownload;
  final VoidCallback onDelete;

  const DownloadButton({
    super.key,
    required this.status,
    this.progress = 0.0,
    required this.onDownload,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case DownloadStatus.downloaded:
        return IconButton(
          icon: const Icon(Icons.download_done, color: AppColors.accent),
          onPressed: () {
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                backgroundColor: AppColors.card,
                title: const Text('Remove Download?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                content: const Text(
                  'This song will no longer be available for offline playback.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      onDelete();
                    },
                    child: const Text('Remove', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            );
          },
          tooltip: 'Downloaded (Tap to manage)',
        );
      case DownloadStatus.downloading:
      case DownloadStatus.encrypting:
        return SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            value: progress > 0 ? progress : null,
            strokeWidth: 2.5,
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accent),
          ),
        );
      case DownloadStatus.failed:
        return IconButton(
          icon: const Icon(Icons.refresh, color: AppColors.error),
          onPressed: onDownload,
          tooltip: 'Retry download',
        );
      case DownloadStatus.notDownloaded:
      case DownloadStatus.canceled:
      case DownloadStatus.enqueued:
      default:
        return IconButton(
          icon: const Icon(Icons.arrow_downward, color: AppColors.textSecondary),
          onPressed: onDownload,
          tooltip: 'Download',
        );
    }
  }
}
