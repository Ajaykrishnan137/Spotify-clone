import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/song_model.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/dimensions.dart';
import '../../core/services/in_app_notifications_service.dart';
import '../../controllers/download_controller.dart';
import '../playlist/playlist_detail_view.dart';
import '../shared_widgets/app_image.dart';

class NotificationsView extends ConsumerStatefulWidget {
  const NotificationsView({super.key});

  @override
  ConsumerState<NotificationsView> createState() => _NotificationsViewState();
}

class _NotificationsViewState extends ConsumerState<NotificationsView> {
  @override
  void initState() {
    super.initState();
    // Mark notifications as read when opening the screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(inAppNotificationsNotifierProvider.notifier).markAllAsRead();
    });
  }

  void _handleNotificationTap(InAppNotificationItem item) {
    if (item.song != null && item.type == NotificationType.downloadFailed) {
      // Trigger Retry
      ref.read(downloadControllerProvider.notifier).startDownload(
            item.song!,
            playlistId: item.playlistId ?? 'retry',
          );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Retrying download: "${item.song!.title}"'),
          backgroundColor: AppColors.card,
        ),
      );
    } else if (item.playlistId != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PlaylistDetailView(
            title: item.playlistName ?? 'Playlist',
            subtitle: 'Offline Collection',
            songs: item.song != null ? [item.song!] : [],
            playlistId: item.playlistId,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final notifications = ref.watch(inAppNotificationsNotifierProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Notifications',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: AppColors.textPrimary),
        ),
        actions: [
          if (notifications.isNotEmpty)
            TextButton(
              onPressed: () {
                ref.read(inAppNotificationsNotifierProvider.notifier).clearAll();
              },
              child: const Text('Clear all', style: TextStyle(color: AppColors.cyanAccent, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: notifications.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.notifications_none, size: 56, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No notifications yet',
                    style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Downloads, updates, and news will appear here',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                  ),
                ],
              ),
            )
          : ListView.builder(
              itemCount: notifications.length,
              itemBuilder: (ctx, idx) {
                final item = notifications[idx];
                final iconData = switch (item.type) {
                  NotificationType.downloadCompleted => Icons.download_done,
                  NotificationType.downloadFailed => Icons.error_outline,
                  NotificationType.playlistUpdated => Icons.playlist_add_check,
                  NotificationType.appTip => Icons.tips_and_updates_outlined,
                };

                final iconColor = switch (item.type) {
                  NotificationType.downloadCompleted => AppColors.accent,
                  NotificationType.downloadFailed => AppColors.error,
                  NotificationType.playlistUpdated => AppColors.cyanAccent,
                  NotificationType.appTip => Colors.amber,
                };

                return Dismissible(
                  key: Key('notif_${item.id}'),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    color: AppColors.error,
                    child: const Icon(Icons.delete_outline, color: Colors.white, size: 28),
                  ),
                  onDismissed: (_) {
                    ref.read(inAppNotificationsNotifierProvider.notifier).removeNotification(item.id);
                  },
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: Dimensions.space16, vertical: 8),
                    leading: CircleAvatar(
                      backgroundColor: iconColor.withOpacity(0.15),
                      child: Icon(iconData, color: iconColor, size: 22),
                    ),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: item.isRead ? FontWeight.w500 : FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        if (!item.isRead)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppColors.cyanAccent,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(item.message, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                        const SizedBox(height: 4),
                        Text(
                          _formatTimeAgo(item.timestamp),
                          style: TextStyle(color: AppColors.textSecondary.withOpacity(0.7), fontSize: 11),
                        ),
                      ],
                    ),
                    trailing: item.type == NotificationType.downloadFailed && item.song != null
                        ? ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.card,
                              foregroundColor: AppColors.cyanAccent,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            ),
                            onPressed: () => _handleNotificationTap(item),
                            child: const Text('Retry', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          )
                        : null,
                    onTap: () => _handleNotificationTap(item),
                  ),
                );
              },
            ),
    );
  }

  String _formatTimeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
