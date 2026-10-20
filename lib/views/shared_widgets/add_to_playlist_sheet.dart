import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/song_model.dart';
import '../../models/playlist_model.dart';
import '../../controllers/playlist_controller.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/dimensions.dart';
import 'app_image.dart';

class AddToPlaylistSheet extends ConsumerStatefulWidget {
  final List<SongModel> songs; // Can be 1 or multiple songs

  const AddToPlaylistSheet({
    super.key,
    required this.songs,
  });

  static Future<void> show(BuildContext context, {required List<SongModel> songs}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Dimensions.radiusLarge)),
      ),
      builder: (ctx) => AddToPlaylistSheet(songs: songs),
    );
  }

  @override
  ConsumerState<AddToPlaylistSheet> createState() => _AddToPlaylistSheetState();
}

class _AddToPlaylistSheetState extends ConsumerState<AddToPlaylistSheet> {
  void _createNewPlaylistAndAdd() {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Dimensions.radiusMedium)),
        title: const Text('New Playlist', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: textController,
          autofocus: true,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: const InputDecoration(
            hintText: 'My Playlist',
            hintStyle: TextStyle(color: AppColors.textSecondary),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.textSecondary)),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.cyanAccent)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.cyanAccent),
            onPressed: () async {
              final name = textController.text.trim();
              if (name.isNotEmpty) {
                Navigator.pop(ctx); // Close dialog
                Navigator.pop(context); // Close bottom sheet
                final newId = DateTime.now().millisecondsSinceEpoch.toString();
                await ref.read(localPlaylistControllerProvider.notifier).createPlaylist(
                  name,
                  initialSongs: widget.songs,
                  id: newId,
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Added ${widget.songs.length} song(s) to "$name"'),
                      backgroundColor: AppColors.card,
                    ),
                  );
                }
              }
            },
            child: const Text('Create', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _addSongsToTargetPlaylist(PlaylistModel playlist) async {
    final existingSongs = await ref.read(localPlaylistControllerProvider.notifier).getPlaylistSongs(playlist.id);
    final existingIds = existingSongs.map((s) => s.id).toSet();

    final duplicates = widget.songs.where((s) => existingIds.contains(s.id)).toList();
    final nonDuplicates = widget.songs.where((s) => !existingIds.contains(s.id)).toList();

    if (duplicates.isNotEmpty && nonDuplicates.isEmpty) {
      // All are duplicates: ask user if they want to add anyway
      if (!mounted) return;
      final shouldAdd = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Dimensions.radiusMedium)),
          title: const Text('Already in this playlist', style: TextStyle(color: AppColors.textPrimary)),
          content: Text(
            widget.songs.length == 1
                ? '"${widget.songs.first.title}" is already in "${playlist.name}". Add it anyway?'
                : '${duplicates.length} songs are already in "${playlist.name}". Add anyway?',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.cyanAccent),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Add anyway', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );

      if (shouldAdd != true) return;
      await _executeAdd(playlist, widget.songs);
    } else if (duplicates.isNotEmpty && nonDuplicates.isNotEmpty) {
      if (!mounted) return;
      final choice = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Dimensions.radiusMedium)),
          title: const Text('Duplicate songs found', style: TextStyle(color: AppColors.textPrimary)),
          content: Text(
            '${duplicates.length} of ${widget.songs.length} songs are already in "${playlist.name}".',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'skip'),
              child: const Text('Add new only', style: TextStyle(color: AppColors.cyanAccent)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.cyanAccent),
              onPressed: () => Navigator.pop(ctx, 'all'),
              child: const Text('Add all', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );

      if (choice == null) return;
      final songsToAdd = choice == 'all' ? widget.songs : nonDuplicates;
      await _executeAdd(playlist, songsToAdd);
    } else {
      await _executeAdd(playlist, widget.songs);
    }
  }

  Future<void> _executeAdd(PlaylistModel playlist, List<SongModel> songsToAdd) async {
    Navigator.pop(context); // Dismiss sheet
    await ref.read(localPlaylistControllerProvider.notifier).addMultipleSongsToPlaylist(playlist.id, songsToAdd);

    if (mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added ${songsToAdd.length} song(s) to "${playlist.name}"'),
          backgroundColor: AppColors.card,
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'UNDO',
            textColor: AppColors.cyanAccent,
            onPressed: () async {
              for (final s in songsToAdd) {
                await ref.read(localPlaylistControllerProvider.notifier).removeSongFromPlaylist(playlist.id, s.id);
              }
            },
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final playlistsAsync = ref.watch(localPlaylistControllerProvider);

    return SafeArea(
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        padding: const EdgeInsets.symmetric(vertical: Dimensions.space16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Dimensions.space16),
              child: Row(
                children: [
                  const Text(
                    'Add to playlist',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.textSecondary),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(color: AppColors.card),

            // Option 1: New Playlist
            ListTile(
              leading: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
                ),
                child: const Icon(Icons.add, color: AppColors.cyanAccent, size: 28),
              ),
              title: const Text(
                'New playlist',
                style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
              ),
              subtitle: const Text('Create a new playlist', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              onTap: _createNewPlaylistAndAdd,
            ),
            const Divider(color: AppColors.card, height: 1),

            // Option 2: Existing playlists list
            Expanded(
              child: playlistsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator(color: AppColors.accent)),
                error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: Colors.red))),
                data: (playlists) {
                  if (playlists.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24.0),
                        child: Text(
                          'No existing playlists. Tap "New playlist" above to create one.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: playlists.length,
                    itemBuilder: (ctx, idx) {
                      final pl = playlists[idx];
                      return ListTile(
                        leading: pl.coverUrl != null && pl.coverUrl!.isNotEmpty
                            ? AppImage(url: pl.coverUrl!, width: 48, height: 48, borderRadius: Dimensions.radiusSmall)
                            : Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: AppColors.card,
                                  borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
                                ),
                                child: const Icon(Icons.music_note, color: AppColors.cyanAccent),
                              ),
                        title: Text(
                          pl.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          '${pl.songCount} songs',
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                        ),
                        onTap: () => _addSongsToTargetPlaylist(pl),
                      );
                    },
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
