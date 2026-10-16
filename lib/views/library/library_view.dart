import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/playlist_model.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/dimensions.dart';
import '../../core/constants/app_strings.dart';
import '../shared_widgets/empty_view.dart';

class LibraryView extends ConsumerWidget {
  const LibraryView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mockPlaylists = [
      PlaylistModel(
        id: 'liked',
        ownerId: 'user-1',
        name: AppStrings.likedSongs,
        isLikedSongs: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        songCount: 12,
      ),
      PlaylistModel(
        id: 'p-1',
        ownerId: 'user-1',
        name: 'Pradeep Kumar Hits',
        coverUrl: 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=500&q=80',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        songCount: 49,
      ),
      PlaylistModel(
        id: 'p-2',
        ownerId: 'user-1',
        name: 'Sai Abhyankkar Vibes',
        coverUrl: 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=500&q=80',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        songCount: 25,
      ),
      PlaylistModel(
        id: 'p-3',
        ownerId: 'user-1',
        name: 'Tamil Melody Hits',
        coverUrl: 'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=500&q=80',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        songCount: 75,
      ),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Your Library'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              // Create playlist dialog
            },
          ),
        ],
      ),
      body: mockPlaylists.isEmpty
          ? const EmptyView(
              title: 'Your Library is empty',
              subtitle: 'Add playlists and liked songs to see them here.',
              icon: Icons.library_music,
            )
          : ListView.builder(
              itemCount: mockPlaylists.length,
              itemBuilder: (context, index) {
                final playlist = mockPlaylists[index];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: Dimensions.space16, vertical: Dimensions.space4),
                  leading: playlist.isLikedSongs
                      ? Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF450AF5), Color(0xFFC4EFD9)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
                          ),
                          child: const Icon(Icons.favorite, color: Colors.white, size: 28),
                        )
                      : Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: AppColors.card,
                            borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
                          ),
                          child: const Icon(Icons.queue_music, color: AppColors.textSecondary, size: 32),
                        ),
                  title: Text(
                    playlist.name,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    'Playlist • ${playlist.songCount} songs',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
                  onTap: () {},
                );
              },
            ),
    );
  }
}
