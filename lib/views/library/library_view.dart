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
import 'downloaded_songs_view.dart';

class LibraryView extends ConsumerStatefulWidget {
  const LibraryView({super.key});

  @override
  ConsumerState<LibraryView> createState() => _LibraryViewState();
}

class _LibraryViewState extends ConsumerState<LibraryView> {
  void _openDownloadedView() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const DownloadedSongsView(),
      ),
    );
  }

  void _showCreatePlaylistDialog() {
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

  void _showRenamePlaylistDialog(PlaylistModel playlist) {
    final textController = TextEditingController(text: playlist.name);
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('Rename playlist', style: TextStyle(color: AppColors.textPrimary)),
          content: TextField(
            controller: textController,
            autofocus: true,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: const InputDecoration(
              hintText: 'New playlist name',
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
                final newName = textController.text.trim();
                if (newName.isNotEmpty) {
                  ref.read(localPlaylistControllerProvider.notifier).renamePlaylist(playlist.id, newName);
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Rename', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _showPlaylistMenu(PlaylistModel playlist) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Dimensions.radiusLarge)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit, color: AppColors.textPrimary),
                title: const Text('Rename playlist', style: TextStyle(color: AppColors.textPrimary)),
                onTap: () {
                  Navigator.pop(ctx);
                  _showRenamePlaylistDialog(playlist);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: AppColors.error),
                title: const Text('Delete playlist', style: TextStyle(color: AppColors.error)),
                onTap: () {
                  Navigator.pop(ctx);
                  ref.read(localPlaylistControllerProvider.notifier).deletePlaylist(playlist.id);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final playlistsAsync = ref.watch(localPlaylistControllerProvider);
    final allSongsAsync = ref.watch(allSongsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text(
          'Your Library',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: AppColors.textPrimary),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, size: 28, color: AppColors.textPrimary),
            tooltip: 'Create Playlist',
            onPressed: _showCreatePlaylistDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Chips (Downloaded)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Dimensions.space16, vertical: 4),
            child: Row(
              children: [
                ActionChip(
                  label: const Text('Downloaded'),
                  avatar: const Icon(
                    Icons.arrow_circle_down,
                    size: 18,
                    color: AppColors.cyanAccent,
                  ),
                  backgroundColor: AppColors.card,
                  labelStyle: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                  onPressed: _openDownloadedView,
                ),
              ],
            ),
          ),
          Expanded(
            child: allSongsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator(color: AppColors.accent)),
              error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: Colors.red))),
              data: (allSongs) {
                final categories = <String, List<SongModel>>{};
                for (final song in allSongs) {
                  categories.putIfAbsent(song.genre, () => []).add(song);
                }

                final userPlaylists = playlistsAsync.value ?? [];

                return ListView(
                  padding: const EdgeInsets.symmetric(vertical: Dimensions.space8),
                  children: [
                    // Downloaded Songs item
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: Dimensions.space16, vertical: Dimensions.space8),
                      leading: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
                          gradient: const LinearGradient(
                            colors: [Color(0xFF1E90FF), Color(0xFF38D6FF)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: const Icon(Icons.download_done_rounded, color: Colors.white, size: 28),
                      ),
                      title: const Text(
                        'Downloaded',
                        style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontSize: 16),
                      ),
                      subtitle: const Text('Offline Music • Stored on device', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.textSecondary),
                      onTap: _openDownloadedView,
                    ),

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
                      title: const Text(
                        AppStrings.likedSongs,
                        style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontSize: 16),
                      ),
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
                                subtitle: 'Legal Music Collection',
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
                          leading: FutureBuilder<List<SongModel>>(
                            future: ref.read(localPlaylistControllerProvider.notifier).getPlaylistSongs(pl.id),
                            builder: (context, snap) {
                              final firstSong = (snap.data != null && snap.data!.isNotEmpty) ? snap.data!.first : null;
                              if (firstSong != null && firstSong.coverUrl.isNotEmpty) {
                                return AppImage(url: firstSong.coverUrl, width: 56, height: 56, borderRadius: Dimensions.radiusSmall);
                              }
                              return Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  color: AppColors.card,
                                  borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
                                ),
                                child: const Icon(Icons.music_note, color: AppColors.accent, size: 28),
                              );
                            },
                          ),
                          title: Text(pl.name, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontSize: 15)),
                          subtitle: const Text('Custom Playlist', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                          trailing: IconButton(
                            icon: const Icon(Icons.more_vert, color: AppColors.textSecondary, size: 20),
                            onPressed: () => _showPlaylistMenu(pl),
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
                                    coverUrl: songs.isNotEmpty ? songs.first.coverUrl : null,
                                    songs: songs,
                                    playlistId: pl.id,
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
          ),
        ],
      ),
    );
  }
}
