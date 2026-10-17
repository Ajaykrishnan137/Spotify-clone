import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/song_model.dart';
import '../../controllers/audio_player_controller.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/dimensions.dart';
import '../shared_widgets/app_image.dart';

class QueueSheet extends ConsumerWidget {
  const QueueSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(audioPlayerControllerProvider);
    final queue = playerState.queue;
    final currentSong = playerState.currentSong;
    final currentIndex = playerState.currentIndex;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(Dimensions.radiusLarge)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Handle bar
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textSecondary.withOpacity(0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Dimensions.space16, vertical: Dimensions.space12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Queue',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (queue.isNotEmpty)
                    TextButton(
                      onPressed: () {
                        ref.read(audioPlayerControllerProvider.notifier).clearQueue();
                      },
                      child: const Text('Clear', style: TextStyle(color: AppColors.textSecondary)),
                    ),
                ],
              ),
            ),
            const Divider(color: AppColors.card, height: 1),

            // Now Playing Section
            if (currentSong != null) ...[
              const Padding(
                padding: EdgeInsets.fromLTRB(Dimensions.space16, Dimensions.space12, Dimensions.space16, Dimensions.space4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'NOW PLAYING',
                    style: TextStyle(
                      color: AppColors.accent,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ),
              ListTile(
                leading: AppImage(url: currentSong.coverUrl, width: 44, height: 44),
                title: Text(
                  currentSong.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.accent),
                ),
                subtitle: Text(
                  currentSong.artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                trailing: const Icon(Icons.volume_up, color: AppColors.accent, size: 20),
              ),
              const Divider(color: AppColors.card, height: 1),
            ],

            // Next In Queue / Drag to Reorder Section
            Padding(
              padding: const EdgeInsets.fromLTRB(Dimensions.space16, Dimensions.space12, Dimensions.space16, Dimensions.space8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'NEXT UP (${queue.length})',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ),

            Expanded(
              child: queue.isEmpty
                  ? const Center(
                      child: Text('Queue is empty', style: TextStyle(color: AppColors.textSecondary)),
                    )
                  : ReorderableListView.builder(
                      itemCount: queue.length,
                      onReorder: (oldIndex, newIndex) {
                        ref.read(audioPlayerControllerProvider.notifier).reorderQueue(oldIndex, newIndex);
                      },
                      itemBuilder: (context, index) {
                        final song = queue[index];
                        final isCurrentlyPlaying = index == currentIndex;

                        return Dismissible(
                          key: ValueKey('${song.id}_$index'),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            color: AppColors.error,
                            child: const Icon(Icons.delete, color: Colors.white),
                          ),
                          onDismissed: (_) {
                            ref.read(audioPlayerControllerProvider.notifier).removeFromQueue(index);
                          },
                          child: ListTile(
                            key: ValueKey('tile_${song.id}_$index'),
                            leading: AppImage(url: song.coverUrl, width: 40, height: 40),
                            title: Text(
                              song.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: isCurrentlyPlaying ? AppColors.accent : AppColors.textPrimary,
                                fontWeight: isCurrentlyPlaying ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                            subtitle: Text(
                              song.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                            ),
                            trailing: ReorderableDragStartListener(
                              index: index,
                              child: const Icon(Icons.drag_handle, color: AppColors.textSecondary),
                            ),
                            onTap: () {
                              ref.read(audioPlayerControllerProvider.notifier).playSong(
                                    song,
                                    queue: queue,
                                    index: index,
                                  );
                            },
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
