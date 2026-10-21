import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/playlist_model.dart';
import '../../models/song_model.dart';
import '../../controllers/playlist_controller.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/dimensions.dart';
import '../../core/constants/app_strings.dart';
import '../../core/services/cloud_catalog_service.dart';
import '../../core/services/playlist_visibility_service.dart';
import '../shared_widgets/app_image.dart';
import '../../core/utils/app_snackbar.dart';
import '../playlist/playlist_detail_view.dart';
import 'downloaded_songs_view.dart';

class PlaylistItemData {
  final String key;
  final String name;
  final String? subtitle;
  final String? coverUrl;
  final List<SongModel> songs;
  final bool isCustom;
  final String? customId;

  PlaylistItemData({
    required this.key,
    required this.name,
    this.subtitle,
    this.coverUrl,
    required this.songs,
    required this.isCustom,
    this.customId,
  });
}

class LibraryView extends ConsumerStatefulWidget {
  const LibraryView({super.key});

  @override
  ConsumerState<LibraryView> createState() => _LibraryViewState();
}

class _LibraryViewState extends ConsumerState<LibraryView> {
  bool _isMultiSelect = false;
  final Set<String> _selectedPlaylistKeys = {};

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

  void _showRenamePlaylistDialog({
    required String currentName,
    String? customId,
    List<SongModel>? songs,
  }) {
    final textController = TextEditingController(text: currentName);
    textController.selection = TextSelection(baseOffset: 0, extentOffset: currentName.length);
    String? errorText;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.surface,
              title: const Text('Rename playlist', style: TextStyle(color: AppColors.textPrimary)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: textController,
                    autofocus: true,
                    maxLength: 60,
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'New playlist name',
                      errorText: errorText,
                      hintStyle: const TextStyle(color: AppColors.textSecondary),
                      enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.textSecondary)),
                      focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.accent)),
                    ),
                    onChanged: (val) {
                      if (errorText != null) {
                        setDialogState(() => errorText = null);
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
                  onPressed: () async {
                    final newName = textController.text.trim();
                    if (newName.isEmpty) {
                      setDialogState(() => errorText = 'Playlist name cannot be empty');
                      return;
                    }
                    if (newName.length > 60) {
                      setDialogState(() => errorText = 'Maximum 60 characters');
                      return;
                    }

                    if (customId != null) {
                      await ref.read(localPlaylistControllerProvider.notifier).renamePlaylist(customId, newName);
                    } else {
                      // Rename default / imported playlist
                      ref.read(hiddenPlaylistsProvider.notifier).hidePlaylist(currentName);
                      await ref.read(localPlaylistControllerProvider.notifier).createPlaylist(
                        newName,
                        initialSongs: songs ?? [],
                      );
                    }

                    if (ctx.mounted) Navigator.pop(ctx);
                    AppSnackBar.showInfo(
                      context: context,
                      message: 'Renamed to "$newName"',
                    );
                  },
                  child: const Text('Save', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Show the required confirmation dialog with Cancel and Delete (coral accent #FF6B6B)
  void _confirmDeleteSinglePlaylist(PlaylistItemData playlist) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Dimensions.radiusMedium)),
          title: Text(
            'Delete ${playlist.name}?',
            style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
          ),
          content: Text(
            'Delete "${playlist.name}"? This won\'t delete the songs from your downloads or other playlists.',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF6B6B), // Coral accent #FF6B6B
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                _executeDeletePlaylist(playlist);
              },
              child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _executeDeletePlaylist(PlaylistItemData playlist) {
    if (playlist.isCustom && playlist.customId != null) {
      ref.read(localPlaylistControllerProvider.notifier).deletePlaylist(playlist.customId!);
    } else {
      ref.read(hiddenPlaylistsProvider.notifier).hidePlaylist(playlist.name);
    }

    AppSnackBar.showUndo(
      context: context,
      message: 'Deleted playlist "${playlist.name}"',
      onUndo: () {
        if (playlist.isCustom && playlist.customId != null) {
          ref.read(localPlaylistControllerProvider.notifier).createPlaylist(playlist.name).then((_) {
            for (final song in playlist.songs) {
              ref.read(localPlaylistControllerProvider.notifier).addSongToPlaylist(playlist.customId!, song);
            }
          });
        } else {
          ref.read(hiddenPlaylistsProvider.notifier).unhidePlaylist(playlist.name);
        }
      },
    );
  }

  void _confirmDeleteSelectedPlaylists(List<PlaylistItemData> allItems) {
    final selectedItems = allItems.where((item) => _selectedPlaylistKeys.contains(item.key)).toList();
    if (selectedItems.isEmpty) return;

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Dimensions.radiusMedium)),
          title: Text(
            'Delete ${selectedItems.length} playlists?',
            style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
          ),
          content: Text(
            'Delete ${selectedItems.length} playlists? This won\'t delete the songs from your downloads or other playlists.',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF6B6B), // Coral accent #FF6B6B
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                _executeDeleteSelectedPlaylists(selectedItems);
              },
              child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _executeDeleteSelectedPlaylists(List<PlaylistItemData> items) {
    setState(() {
      _isMultiSelect = false;
      _selectedPlaylistKeys.clear();
    });

    final customItems = items.where((i) => i.isCustom && i.customId != null).toList();
    final importedItems = items.where((i) => !i.isCustom).toList();

    for (final c in customItems) {
      ref.read(localPlaylistControllerProvider.notifier).deletePlaylist(c.customId!);
    }
    if (importedItems.isNotEmpty) {
      ref.read(hiddenPlaylistsProvider.notifier).hideMultiplePlaylists(importedItems.map((i) => i.name));
    }

    AppSnackBar.showUndo(
      context: context,
      message: 'Deleted ${items.length} playlists',
      onUndo: () {
        for (final c in customItems) {
          ref.read(localPlaylistControllerProvider.notifier).createPlaylist(c.name).then((_) {
            for (final song in c.songs) {
              ref.read(localPlaylistControllerProvider.notifier).addSongToPlaylist(c.customId!, song);
            }
          });
        }
        if (importedItems.isNotEmpty) {
          ref.read(hiddenPlaylistsProvider.notifier).unhideMultiplePlaylists(importedItems.map((i) => i.name));
        }
      },
    );
  }

  /// Long-press bottom sheet menu for any playlist card/tile
  void _showPlaylistMenu(PlaylistItemData item) {
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
                  _showRenamePlaylistDialog(
                    currentName: item.name,
                    customId: item.isCustom ? item.customId : null,
                    songs: item.songs,
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Color(0xFFFF6B6B)),
                title: const Text('Delete playlist', style: TextStyle(color: Color(0xFFFF6B6B), fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.pop(ctx);
                  _confirmDeleteSinglePlaylist(item);
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
    final hiddenPlaylists = ref.watch(hiddenPlaylistsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Fixed Top Header (Safe Area aware, fixed in place)
            Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: Dimensions.space16),
              color: AppColors.background,
              child: Row(
                children: [
                  Text(
                    _isMultiSelect ? '${_selectedPlaylistKeys.length} Selected' : 'Your Library',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: AppColors.textPrimary),
                  ),
                  const Spacer(),
                  if (_isMultiSelect) ...[
                    IconButton(
                      icon: const Icon(Icons.delete, color: Color(0xFFFF6B6B)),
                      tooltip: 'Delete Selected',
                      onPressed: _selectedPlaylistKeys.isEmpty
                          ? null
                          : () {
                              allSongsAsync.whenData((allSongs) {
                                final categories = <String, List<SongModel>>{};
                                for (final song in allSongs) {
                                  if (!hiddenPlaylists.contains(song.genre.toLowerCase().trim())) {
                                    categories.putIfAbsent(song.genre, () => []).add(song);
                                  }
                                }
                                final userPlaylists = playlistsAsync.value ?? [];
                                final List<PlaylistItemData> allDeletable = [
                                  ...categories.entries.map((e) => PlaylistItemData(
                                        key: 'cat_${e.key}',
                                        name: e.key.toUpperCase(),
                                        songs: e.value,
                                        isCustom: false,
                                      )),
                                  ...userPlaylists.map((pl) => PlaylistItemData(
                                        key: 'custom_${pl.id}',
                                        name: pl.name,
                                        songs: [],
                                        isCustom: true,
                                        customId: pl.id,
                                      )),
                                ];
                                _confirmDeleteSelectedPlaylists(allDeletable);
                              });
                            },
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: AppColors.textPrimary),
                      tooltip: 'Cancel Multi-select',
                      onPressed: () {
                        setState(() {
                          _isMultiSelect = false;
                          _selectedPlaylistKeys.clear();
                        });
                      },
                    ),
                  ] else ...[
                    IconButton(
                      icon: const Icon(Icons.checklist, color: AppColors.textPrimary),
                      tooltip: 'Multi-select Playlists',
                      onPressed: () {
                        setState(() {
                          _isMultiSelect = true;
                        });
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.add, size: 28, color: AppColors.textPrimary),
                      tooltip: 'Create Playlist',
                      onPressed: _showCreatePlaylistDialog,
                    ),
                  ],
                ],
              ),
            ),

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

            // Scrollable Content
            Expanded(
              child: allSongsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator(color: AppColors.accent)),
                error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: Colors.red))),
                data: (allSongs) {
                  // Filter out hidden / deleted imported playlists
                  final categories = <String, List<SongModel>>{};
                  for (final song in allSongs) {
                    if (!hiddenPlaylists.contains(song.genre.toLowerCase().trim())) {
                      categories.putIfAbsent(song.genre, () => []).add(song);
                    }
                  }

                  final userPlaylists = playlistsAsync.value ?? [];

                  return ListView(
                    padding: const EdgeInsets.only(
                      top: Dimensions.space8,
                      bottom: Dimensions.miniPlayerHeight + Dimensions.space64,
                    ),
                    children: [
                      // Downloaded Songs item
                      if (!_isMultiSelect)
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
                      if (!_isMultiSelect)
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

                      // Folder categories as loaded/imported playlists (Swipeable, Long-pressable, Multi-selectable)
                      ...categories.entries.map((entry) {
                        final name = entry.key;
                        final songs = entry.value;
                        final cover = songs.isNotEmpty ? songs.first.coverUrl : null;
                        final itemData = PlaylistItemData(
                          key: 'cat_$name',
                          name: name.toUpperCase(),
                          subtitle: 'Playlist • ${songs.length} songs',
                          coverUrl: cover,
                          songs: songs,
                          isCustom: false,
                        );

                        if (_isMultiSelect) {
                          final isSelected = _selectedPlaylistKeys.contains(itemData.key);
                          return CheckboxListTile(
                            value: isSelected,
                            activeColor: AppColors.cyanAccent,
                            checkColor: Colors.black,
                            secondary: AppImage(
                              url: cover ?? '',
                              width: 52,
                              height: 52,
                              borderRadius: Dimensions.radiusSmall,
                            ),
                            title: Text(
                              name.toUpperCase(),
                              style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontSize: 15),
                            ),
                            subtitle: Text('Playlist • ${songs.length} songs', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                            onChanged: (val) {
                              setState(() {
                                if (val == true) {
                                  _selectedPlaylistKeys.add(itemData.key);
                                } else {
                                  _selectedPlaylistKeys.remove(itemData.key);
                                }
                              });
                            },
                          );
                        }

                        // Swipe-to-delete on the Library list
                        return Dismissible(
                          key: Key('imported_pl_${itemData.key}'),
                          direction: DismissDirection.endToStart,
                          confirmDismiss: (dir) async {
                            _confirmDeleteSinglePlaylist(itemData);
                            return false; // Let confirmation dialog trigger the actual delete
                          },
                          background: Container(
                            color: const Color(0xFFFF6B6B),
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Icon(Icons.delete_outline, color: Colors.white, size: 28),
                                SizedBox(width: 8),
                                Text(
                                  'Delete',
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                              ],
                            ),
                          ),
                          child: InkWell(
                            onLongPress: () => _showPlaylistMenu(itemData),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => PlaylistDetailView(
                                    title: name.toUpperCase(),
                                    subtitle: 'Legal Music Collection',
                                    coverUrl: cover,
                                    songs: songs,
                                    isImportedPlaylist: true,
                                    importedCategoryName: name,
                                  ),
                                ),
                              );
                            },
                            child: ListTile(
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
                              trailing: IconButton(
                                icon: const Icon(Icons.more_vert, color: AppColors.textSecondary, size: 20),
                                onPressed: () => _showPlaylistMenu(itemData),
                              ),
                            ),
                          ),
                        );
                      }),

                      // User created custom playlists
                      if (userPlaylists.isNotEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: Dimensions.space16, vertical: Dimensions.space12),
                          child: Text('CUSTOM PLAYLISTS', style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                        ...userPlaylists.map((pl) {
                          final itemData = PlaylistItemData(
                            key: 'custom_${pl.id}',
                            name: pl.name,
                            subtitle: 'Custom Playlist',
                            songs: [],
                            isCustom: true,
                            customId: pl.id,
                          );

                          if (_isMultiSelect) {
                            final isSelected = _selectedPlaylistKeys.contains(itemData.key);
                            return CheckboxListTile(
                              value: isSelected,
                              activeColor: AppColors.cyanAccent,
                              checkColor: Colors.black,
                              secondary: Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  color: AppColors.card,
                                  borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
                                ),
                                child: const Icon(Icons.music_note, color: AppColors.accent, size: 28),
                              ),
                              title: Text(pl.name, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontSize: 15)),
                              subtitle: const Text('Custom Playlist', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                              onChanged: (val) {
                                setState(() {
                                  if (val == true) {
                                    _selectedPlaylistKeys.add(itemData.key);
                                  } else {
                                    _selectedPlaylistKeys.remove(itemData.key);
                                  }
                                });
                              },
                            );
                          }

                          return Dismissible(
                            key: Key('custom_pl_${pl.id}'),
                            direction: DismissDirection.endToStart,
                            confirmDismiss: (dir) async {
                              _confirmDeleteSinglePlaylist(itemData);
                              return false;
                            },
                            background: Container(
                              color: const Color(0xFFFF6B6B),
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Icon(Icons.delete_outline, color: Colors.white, size: 28),
                                  SizedBox(width: 8),
                                  Text(
                                    'Delete',
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                ],
                              ),
                            ),
                            child: InkWell(
                              onLongPress: () => _showPlaylistMenu(itemData),
                              child: ListTile(
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
                                  onPressed: () => _showPlaylistMenu(itemData),
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
                              ),
                            ),
                          );
                        }),
                      ],
                    ],
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
