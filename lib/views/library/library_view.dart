import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/playlist_model.dart';
import '../../models/song_model.dart';
import '../../controllers/playlist_controller.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/dimensions.dart';
import '../../core/constants/app_strings.dart';
import '../../core/services/cloud_catalog_service.dart';
import '../shared_widgets/empty_view.dart';
import '../shared_widgets/app_image.dart';
import '../playlist/playlist_detail_view.dart';

class LibraryView extends ConsumerWidget {
  const LibraryView({super.key});

  void _showCreatePlaylistDialog(BuildContext context, WidgetRef ref) {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('Create playlist', style: TextStyle(color: AppColors.textPrimary)),
          content: TextField(
            controller: textController,
            autofocus: true,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: const InputDecoration(
              hintText: 'Playlist name',
              hintStyle: TextStyle(color: AppColors.textSecondary),
              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.textSecondary)),
              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.accent)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
              onPressed: () {
                final name = textController.text.trim();
                if (name.isNotEmpty) {
                  ref.read(localPlaylistControllerProvider.notifier).createPlaylist(name);
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Create', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlistsAsync = ref.watch(localPlaylistControllerProvider);
    final allSongsAsync = ref.watch(allSongsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text('Your Library', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: AppColors.textPrimary)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, size: 28, color: AppColors.textPrimary),
            tooltip: 'Create Playlist',
            onPressed: () => _showCreatePlaylistDialog(context, ref),
          ),
        ],
      ),
      body: allSongsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.accent)),
        error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: Colors.red))),
        data: (allSongs) {
          // Pre-organized category playlists from folders
          final categories = <String, List<SongModel>>{};
          for (final song in allSongs) {
            categories.putIfAbsent(song.genre, () => []).add(song);
          }

          final userPlaylists = playlistsAsync.value ?? [];

          return ListView(
            padding: const EdgeInsets.symmetric(vertical: Dimensions.space8),
            children: [
              // Liked Songs item
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: Dimensions.space16, vertical: Dimensions.space8),
                leading: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF450AF5), Color(0xFFC4EFD9)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: const Icon(Icons.favorite, color: Colors.white, size: 28),
                ),
                title: const Text(AppStrings.likedSongs, style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontSize: 16)),
                subtitle: const Text('Playlist • Auto-saved', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PlaylistDetailView(
                        title: AppStrings.likedSongs,
                        subtitle: 'Your favorite tracks',
                        songs: allSongs.take(20).toList(),
                      ),
                    ),
                  );
                },
              ),

              // Folder categories as playlists
              ...categories.entries.map((entry) {
                final name = entry.key;
                final songs = entry.value;
                final cover = songs.isNotEmpty ? songs.first.coverUrl : null;

                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: Dimensions.space16, vertical: Dimensions.space8),
                  leading: AppImage(
                    url: cover ?? '',
                    width: 56,
                    height: 56,
                    borderRadius: Dimensions.radiusSmall,
                  ),
                  title: Text(
                    name.toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontSize: 15),
                  ),
                  subtitle: Text('Playlist • ${songs.length} songs', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PlaylistDetailView(
                          title: name.toUpperCase(),
                          subtitle: 'Playlist by Spotify Cloud',
                          coverUrl: cover,
                          songs: songs,
                        ),
                      ),
                    );
                  },
                );
              }),

              // User created custom playlists
              if (userPlaylists.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: Dimensions.space16, vertical: Dimensions.space12),
                  child: Text('CUSTOM PLAYLISTS', style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
                ...userPlaylists.map((pl) {
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: Dimensions.space16, vertical: Dimensions.space8),
                    leading: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
                      ),
                      child: const Icon(Icons.music_note, color: AppColors.accent, size: 28),
                    ),
                    title: Text(pl.name, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontSize: 15)),
                    subtitle: const Text('Custom Playlist', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: AppColors.textSecondary, size: 20),
                      onPressed: () {
                        ref.read(localPlaylistControllerProvider.notifier).deletePlaylist(pl.id);
                      },
                    ),
                    onTap: () async {
                      final songs = await ref.read(localPlaylistControllerProvider.notifier).getPlaylistSongs(pl.id);
                      if (context.mounted) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PlaylistDetailView(
                              title: pl.name,
                              subtitle: 'Custom Playlist',
                              songs: songs,
                            ),
                          ),
                        );
                      }
                    },
                  );
                }),
              ],
              const SizedBox(height: Dimensions.space64),
            ],
          );
        },
      ),
    );
  }
}
