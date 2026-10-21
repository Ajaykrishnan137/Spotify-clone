import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/song_model.dart';
import '../../models/download_state.dart';
import '../../controllers/audio_player_controller.dart';
import '../../controllers/download_controller.dart';
import '../../controllers/playlist_controller.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/dimensions.dart';
import '../../core/services/playlist_visibility_service.dart';
import '../../core/utils/app_snackbar.dart';
import '../shared_widgets/app_image.dart';
import '../shared_widgets/song_tile.dart';
import '../shared_widgets/song_picker_dialog.dart';

enum PlaylistSortMode {
  custom('Custom order'),
  titleAZ('Title A-Z'),
  artistAZ('Artist A-Z'),
  recentlyAdded('Recently added');

  final String label;
  const PlaylistSortMode(this.label);
}

class PlaylistDetailView extends ConsumerStatefulWidget {
  final String title;
  final String subtitle;
  final String? coverUrl;
  final List<SongModel> songs;
  final String? playlistId;
  final bool isImportedPlaylist;
  final String? importedCategoryName;

  const PlaylistDetailView({
    super.key,
    required this.title,
    required this.subtitle,
    this.coverUrl,
    required this.songs,
    this.playlistId,
    this.isImportedPlaylist = false,
    this.importedCategoryName,
  });

  @override
  ConsumerState<PlaylistDetailView> createState() => _PlaylistDetailViewState();
}

class _PlaylistDetailViewState extends ConsumerState<PlaylistDetailView> {
  late String _currentTitle;
  late List<SongModel> _currentSongs;
  late List<SongModel> _originalOrderSongs; // For Reorder Cancel
  String? _effectivePlaylistId;
  bool _isConvertedCopy = false;

  bool _isMultiSelect = false;
  final Set<String> _selectedSongIds = {};

  bool _isReorderMode = false;
  PlaylistSortMode _sortMode = PlaylistSortMode.custom;

  @override
  void initState() {
    super.initState();
    _currentTitle = widget.title;
    _currentSongs = List.from(widget.songs);
    _originalOrderSongs = List.from(widget.songs);
    _effectivePlaylistId = widget.playlistId;
  }

  void _showRenameDialog() {
    final textController = TextEditingController(text: _currentTitle);
    textController.selection = TextSelection(baseOffset: 0, extentOffset: _currentTitle.length);
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

                    final oldTitle = _currentTitle;
                    if (_effectivePlaylistId != null) {
                      await ref.read(localPlaylistControllerProvider.notifier).renamePlaylist(_effectivePlaylistId!, newName);
                    } else {
                      final categoryName = widget.importedCategoryName ?? oldTitle;
                      ref.read(hiddenPlaylistsProvider.notifier).hidePlaylist(categoryName);
                      final newId = 'pl_${DateTime.now().millisecondsSinceEpoch}';
                      await ref.read(localPlaylistControllerProvider.notifier).createPlaylist(
                        newName,
                        initialSongs: _currentSongs,
                        id: newId,
                      );
                      setState(() {
                        _effectivePlaylistId = newId;
                      });
                    }

                    setState(() {
                      _currentTitle = newName;
                    });

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

  String get _currentPlaylistIdKey {
    return _effectivePlaylistId ?? 'imported_${widget.importedCategoryName ?? _currentTitle}';
  }

  /// Ensure we have an editable local playlist ID if this was an imported read-only category
  Future<String> _ensureEditablePlaylist() async {
    if (_effectivePlaylistId != null) {
      return _effectivePlaylistId!;
    }

    final newId = 'copy_${DateTime.now().millisecondsSinceEpoch}';
    final copyTitle = '$_currentTitle (Editable)';
    await ref.read(localPlaylistControllerProvider.notifier).createPlaylist(
      copyTitle,
      initialSongs: _currentSongs,
      id: newId,
    );

    setState(() {
      _effectivePlaylistId = newId;
      _isConvertedCopy = true;
    });

    if (mounted) {
      AppSnackBar.showInfo(
        context: context,
        message: 'Created editable copy: "$copyTitle"',
      );
    }
    return newId;
  }

  void _removeSong(SongModel song) async {
    final effectiveId = await _ensureEditablePlaylist();
    final index = _currentSongs.indexOf(song);

    setState(() {
      _currentSongs.removeWhere((s) => s.id == song.id);
      _selectedSongIds.remove(song.id);
    });

    await ref.read(localPlaylistControllerProvider.notifier).removeSongFromPlaylist(effectiveId, song.id);

    // Sync audio player queue if currently playing from this playlist
    final playerState = ref.read(audioPlayerControllerProvider);
    if (playerState.queue.any((s) => s.id == song.id)) {
      final updatedQueue = List<SongModel>.from(playerState.queue)..removeWhere((s) => s.id == song.id);
      ref.read(audioPlayerControllerProvider.notifier).updateQueuePreservingCurrent(updatedQueue);
    }

    if (!mounted) return;
    AppSnackBar.showUndo(
      context: context,
      message: 'Removed "${song.title}" from $_currentTitle',
      onUndo: () async {
        setState(() {
          if (index >= 0 && index <= _currentSongs.length) {
            _currentSongs.insert(index, song);
          } else {
            _currentSongs.add(song);
          }
        });
        await ref.read(localPlaylistControllerProvider.notifier).addSongToPlaylist(effectiveId, song);
      },
    );
  }

  void _removeSelectedSongs() async {
    final removed = _currentSongs.where((s) => _selectedSongIds.contains(s.id)).toList();
    if (removed.isEmpty) return;

    final effectiveId = await _ensureEditablePlaylist();

    setState(() {
      _currentSongs.removeWhere((s) => _selectedSongIds.contains(s.id));
      _selectedSongIds.clear();
      _isMultiSelect = false;
    });

    for (final s in removed) {
      await ref.read(localPlaylistControllerProvider.notifier).removeSongFromPlaylist(effectiveId, s.id);
    }

    if (!mounted) return;
    AppSnackBar.showUndo(
      context: context,
      message: 'Removed ${removed.length} songs from $_currentTitle',
      onUndo: () async {
        setState(() {
          _currentSongs.addAll(removed);
        });
        await ref.read(localPlaylistControllerProvider.notifier).addMultipleSongsToPlaylist(effectiveId, removed);
      },
    );
  }

  void _openSongPicker() {
    SongPickerDialog.show(
      context,
      currentPlaylistSongs: _currentSongs,
      onSongsSelected: (selectedSongs) async {
        if (selectedSongs.isEmpty) return;
        final effectiveId = await _ensureEditablePlaylist();

        setState(() {
          _currentSongs.addAll(selectedSongs);
        });

        await ref.read(localPlaylistControllerProvider.notifier).addMultipleSongsToPlaylist(effectiveId, selectedSongs);

        if (mounted) {
          AppSnackBar.showUndo(
            context: context,
            message: 'Added ${selectedSongs.length} song(s) to $_currentTitle',
            onUndo: () async {
              setState(() {
                _currentSongs.removeWhere((s) => selectedSongs.any((sel) => sel.id == s.id));
              });
              for (final s in selectedSongs) {
                await ref.read(localPlaylistControllerProvider.notifier).removeSongFromPlaylist(effectiveId, s.id);
              }
            },
          );
        }
      },
    );
  }

  void _onReorderSongs(int oldIndex, int newIndex) async {
    final effectiveId = await _ensureEditablePlaylist();

    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final song = _currentSongs.removeAt(oldIndex);
      _currentSongs.insert(newIndex, song);
      _sortMode = PlaylistSortMode.custom;
    });

    await ref.read(localPlaylistControllerProvider.notifier).reorderSongs(effectiveId, oldIndex, newIndex);

    // Update play queue order if current song is in this playlist, without interrupting audio
    final playerState = ref.read(audioPlayerControllerProvider);
    if (playerState.currentSong != null && _currentSongs.any((s) => s.id == playerState.currentSong!.id)) {
      ref.read(audioPlayerControllerProvider.notifier).updateQueuePreservingCurrent(_currentSongs);
    }
  }

  void _applySort(PlaylistSortMode mode) async {
    final effectiveId = await _ensureEditablePlaylist();
    setState(() {
      _sortMode = mode;
      switch (mode) {
        case PlaylistSortMode.custom:
          // Keep current
          break;
        case PlaylistSortMode.titleAZ:
          _currentSongs.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
          break;
        case PlaylistSortMode.artistAZ:
          _currentSongs.sort((a, b) => a.artist.toLowerCase().compareTo(b.artist.toLowerCase()));
          break;
        case PlaylistSortMode.recentlyAdded:
          _currentSongs = _currentSongs.reversed.toList();
          break;
      }
    });

    await ref.read(localPlaylistControllerProvider.notifier).setPlaylistSongs(effectiveId, _currentSongs);

    final playerState = ref.read(audioPlayerControllerProvider);
    if (playerState.currentSong != null && _currentSongs.any((s) => s.id == playerState.currentSong!.id)) {
      ref.read(audioPlayerControllerProvider.notifier).updateQueuePreservingCurrent(_currentSongs);
    }
  }

  /// Confirmation dialog before deleting playlist
  void _confirmDeleteEntirePlaylist() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Dimensions.radiusMedium)),
        title: Text(
          'Delete ${widget.title}?',
          style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Delete "${widget.title}"? This won\'t delete the songs from your downloads or other playlists.',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF6B6B),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _executeDeletePlaylist();
            },
            child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _executeDeletePlaylist() {
    final deletedTitle = widget.title;
    final categoryName = widget.importedCategoryName ?? widget.title;
    final isCustom = _effectivePlaylistId != null;
    final playlistId = _effectivePlaylistId;
    final cachedSongs = List<SongModel>.from(_currentSongs);

    if (isCustom && playlistId != null) {
      ref.read(localPlaylistControllerProvider.notifier).deletePlaylist(playlistId);
    } else {
      ref.read(hiddenPlaylistsProvider.notifier).hidePlaylist(categoryName);
    }

    Navigator.pop(context);

    AppSnackBar.showUndo(
      context: context,
      message: 'Deleted playlist "$deletedTitle"',
      onUndo: () {
        if (isCustom && playlistId != null) {
          ref.read(localPlaylistControllerProvider.notifier).createPlaylist(
            deletedTitle,
            initialSongs: cachedSongs,
            id: playlistId,
          );
        } else {
          ref.read(hiddenPlaylistsProvider.notifier).unhidePlaylist(categoryName);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final playerState = ref.watch(audioPlayerControllerProvider);
    final playlistProgressMap = ref.watch(playlistDownloadProgressStreamProvider).value ?? {};
    final downloadTasks = ref.watch(downloadControllerProvider);

    final playlistProgress = playlistProgressMap[_currentPlaylistIdKey] ??
        ref.read(downloadControllerProvider.notifier).getPlaylistProgress(_currentPlaylistIdKey);

    final downloadedCount = _currentSongs.where((s) => downloadTasks[s.id]?.status == DownloadStatus.downloaded).length;
    final remainingToDownload = _currentSongs.length - downloadedCount;
    final allDownloaded = _currentSongs.isNotEmpty && remainingToDownload == 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 280.0,
            pinned: true,
            backgroundColor: AppColors.surface,
            actions: [
              if (_isMultiSelect) ...[
                IconButton(
                  icon: const Icon(Icons.delete, color: Color(0xFFFF6B6B)),
                  tooltip: 'Remove selected (${_selectedSongIds.length})',
                  onPressed: _selectedSongIds.isEmpty ? null : _removeSelectedSongs,
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  tooltip: 'Cancel Multi-select',
                  onPressed: () {
                    setState(() {
                      _isMultiSelect = false;
                      _selectedSongIds.clear();
                    });
                  },
                ),
              ] else ...[
                // Sort Menu
                PopupMenuButton<PlaylistSortMode>(
                  icon: const Icon(Icons.sort, color: Colors.white),
                  tooltip: 'Sort playlist',
                  color: AppColors.card,
                  onSelected: _applySort,
                  itemBuilder: (ctx) => PlaylistSortMode.values.map((mode) {
                    final isSelected = mode == _sortMode;
                    return PopupMenuItem(
                      value: mode,
                      child: Row(
                        children: [
                          Icon(
                            isSelected ? Icons.check : Icons.circle_outlined,
                            size: 16,
                            color: isSelected ? AppColors.cyanAccent : AppColors.textSecondary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            mode.label,
                            style: TextStyle(
                              color: isSelected ? AppColors.cyanAccent : AppColors.textPrimary,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),

                // Add Songs Picker Button
                IconButton(
                  icon: const Icon(Icons.add, color: Colors.white, size: 28),
                  tooltip: 'Add songs',
                  onPressed: _openSongPicker,
                ),

                // Multi-select Toggle Button
                IconButton(
                  icon: const Icon(Icons.checklist, color: Colors.white),
                  tooltip: 'Select Multiple',
                  onPressed: () {
                    setState(() {
                      _isMultiSelect = true;
                    });
                  },
                ),

                // More Menu with Rename & Delete Playlist
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.white),
                  color: AppColors.card,
                  onSelected: (val) {
                    if (val == 'rename_playlist') {
                      _showRenameDialog();
                    } else if (val == 'delete_playlist') {
                      _confirmDeleteEntirePlaylist();
                    }
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      value: 'rename_playlist',
                      child: Row(
                        children: [
                          Icon(Icons.edit, color: AppColors.textPrimary, size: 20),
                          SizedBox(width: 8),
                          Text('Rename playlist', style: TextStyle(color: AppColors.textPrimary)),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete_playlist',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, color: Color(0xFFFF6B6B), size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Delete playlist',
                            style: TextStyle(color: Color(0xFFFF6B6B), fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ],
            flexibleSpace: FlexibleSpaceBar(
              title: GestureDetector(
                onTap: _isMultiSelect ? null : _showRenameDialog,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        _isMultiSelect ? '${_selectedSongIds.length} Selected' : _currentTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
                      ),
                    ),
                    if (!_isMultiSelect) ...[
                      const SizedBox(width: 6),
                      const Icon(Icons.edit_outlined, size: 14, color: Colors.white70),
                    ],
                  ],
                ),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  if (widget.coverUrl != null && widget.coverUrl!.isNotEmpty)
                    AppImage(url: widget.coverUrl!, fit: BoxFit.cover, borderRadius: 0)
                  else
                    Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF2E77D0), Color(0xFF121212)],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                      child: const Center(
                        child: Icon(Icons.music_note, size: 80, color: Colors.white54),
                      ),
                    ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.transparent, AppColors.background.withOpacity(0.9), AppColors.background],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Download All active progress & control card (Specific to this playlist only!)
          if (playlistProgress.isActive)
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: Dimensions.space16, vertical: Dimensions.space8),
                padding: const EdgeInsets.all(Dimensions.space12),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(Dimensions.radiusMedium),
                  border: Border.all(color: AppColors.accent.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.downloading, color: AppColors.accent, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            playlistProgress.isPaused
                                ? 'Paused (${playlistProgress.completedCount}/${playlistProgress.totalCount})'
                                : 'Downloading ${playlistProgress.completedCount}/${playlistProgress.totalCount} tracks...',
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        // Pause / Resume Button for this playlist
                        IconButton(
                          icon: Icon(
                            playlistProgress.isPaused ? Icons.play_arrow : Icons.pause,
                            color: AppColors.textPrimary,
                            size: 22,
                          ),
                          tooltip: playlistProgress.isPaused ? 'Resume' : 'Pause',
                          onPressed: () {
                            if (playlistProgress.isPaused) {
                              ref.read(downloadControllerProvider.notifier).resumePlaylistDownload(_currentPlaylistIdKey);
                            } else {
                              ref.read(downloadControllerProvider.notifier).pausePlaylistDownload(_currentPlaylistIdKey);
                            }
                          },
                        ),
                        // Cancel / Stop Button for this playlist
                        IconButton(
                          icon: const Icon(Icons.stop_circle_outlined, color: AppColors.error, size: 24),
                          tooltip: 'Stop & Cancel This Playlist',
                          onPressed: () {
                            ref.read(downloadControllerProvider.notifier).cancelPlaylistDownload(_currentPlaylistIdKey);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Playlist download cancelled.'),
                                backgroundColor: AppColors.surface,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    LinearProgressIndicator(
                      value: playlistProgress.totalCount > 0
                          ? (playlistProgress.completedCount / playlistProgress.totalCount).clamp(0.0, 1.0)
                          : null,
                      backgroundColor: AppColors.surface,
                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accent),
                      minHeight: 4,
                    ),
                    if (playlistProgress.currentSongTitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Current: ${playlistProgress.currentSongTitle}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                      ),
                    ],
                  ],
                ),
              ),
            ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Dimensions.space16, vertical: Dimensions.space12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.subtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                        const SizedBox(height: 4),
                        Text(
                          '${_currentSongs.length} songs',
                          style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),

                  // Per-playlist Download All or Status button
                  if (playlistProgress.isActive)
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error.withOpacity(0.2),
                        foregroundColor: AppColors.error,
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text('Cancel'),
                      onPressed: () {
                        ref.read(downloadControllerProvider.notifier).cancelPlaylistDownload(_currentPlaylistIdKey);
                      },
                    )
                  else if (allDownloaded)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
                        border: Border.all(color: AppColors.accent.withOpacity(0.5)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.download_done, color: AppColors.accent, size: 18),
                          SizedBox(width: 6),
                          Text('Downloaded', style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold, fontSize: 12)),
                        ],
                      ),
                    )
                  else
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.card,
                        foregroundColor: AppColors.cyanAccent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      icon: const Icon(Icons.arrow_circle_down_rounded, size: 20),
                      label: Text(
                        downloadedCount > 0 ? 'Download remaining ($remainingToDownload)' : 'Download all',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      onPressed: () {
                        ref.read(downloadControllerProvider.notifier).downloadMultipleSongs(
                              _currentSongs,
                              playlistId: _currentPlaylistIdKey,
                            );
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Starting download of $remainingToDownload songs...'),
                            duration: const Duration(seconds: 2),
                            backgroundColor: AppColors.card,
                          ),
                        );
                      },
                    ),

                  const SizedBox(width: Dimensions.space12),
                  FloatingActionButton(
                    backgroundColor: AppColors.accent,
                    elevation: 4,
                    onPressed: () {
                      if (_currentSongs.isEmpty) return;
                      final isCurrentPlaylistPlaying = _currentSongs.any((s) => s.id == playerState.currentSong?.id);
                      if (isCurrentPlaylistPlaying) {
                        ref.read(audioPlayerControllerProvider.notifier).togglePlayPause();
                      } else {
                        ref.read(audioPlayerControllerProvider.notifier).playSong(
                              _currentSongs.first,
                              queue: _currentSongs,
                              index: 0,
                            );
                      }
                    },
                    child: Icon(
                      (_currentSongs.any((s) => s.id == playerState.currentSong?.id) && playerState.isPlaying)
                          ? Icons.pause
                          : Icons.play_arrow,
                      color: Colors.black,
                      size: 36,
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (_currentSongs.isEmpty)
            SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 48),
                  child: Column(
                    children: [
                      const Icon(Icons.music_off, size: 48, color: AppColors.textSecondary),
                      const SizedBox(height: 12),
                      const Text(
                        'No songs in this playlist',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.cyanAccent),
                        icon: const Icon(Icons.add, color: Colors.black),
                        label: const Text('Add Songs', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                        onPressed: _openSongPicker,
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            SliverReorderableList(
              itemCount: _currentSongs.length,
              onReorder: _onReorderSongs,
              proxyDecorator: (child, index, animation) {
                return AnimatedBuilder(
                  animation: animation,
                  builder: (context, child) {
                    final double elevation = Tween<double>(begin: 0, end: 10).animate(animation).value;
                    return Material(
                      elevation: elevation,
                      color: AppColors.card.withOpacity(0.96),
                      shadowColor: Colors.black.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
                      child: child,
                    );
                  },
                  child: child,
                );
              },
              itemBuilder: (context, index) {
                final song = _currentSongs[index];
                final isSelected = _selectedSongIds.contains(song.id);

                if (_isMultiSelect) {
                  return CheckboxListTile(
                    key: ValueKey('multiselect_${song.id}'),
                    value: isSelected,
                    activeColor: AppColors.cyanAccent,
                    checkColor: Colors.black,
                    title: Text(
                      song.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      song.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                    secondary: AppImage(url: song.coverUrl, width: 44, height: 44),
                    onChanged: (val) {
                      setState(() {
                        if (val == true) {
                          _selectedSongIds.add(song.id);
                        } else {
                          _selectedSongIds.remove(song.id);
                        }
                      });
                    },
                  );
                }

                Widget dragHandleWidget;
                if (_sortMode == PlaylistSortMode.custom) {
                  dragHandleWidget = ReorderableDragStartListener(
                    index: index,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
                      child: Icon(Icons.drag_handle, color: AppColors.textSecondary, size: 22),
                    ),
                  );
                } else {
                  dragHandleWidget = InkWell(
                    onTap: () {
                      AppSnackBar.showUndo(
                        context: context,
                        message: 'Switch to Custom order to rearrange',
                        duration: const Duration(seconds: 4),
                        onUndo: () => _applySort(PlaylistSortMode.custom),
                      );
                    },
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
                      child: Icon(Icons.drag_handle, color: AppColors.textMuted, size: 22),
                    ),
                  );
                }

                return ReorderableDelayedDragStartListener(
                  key: ValueKey('song_row_${song.id}'),
                  index: index,
                  enabled: _sortMode == PlaylistSortMode.custom,
                  child: Dismissible(
                    key: ValueKey('dismiss_song_${song.id}'),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      color: AppColors.error,
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Icon(Icons.delete_outline, color: Colors.white, size: 28),
                          SizedBox(width: 8),
                          Text(
                            'Remove',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    onDismissed: (_) {
                      _removeSong(song);
                    },
                    child: SongTile(
                      key: ValueKey('tile_${song.id}'),
                      song: song,
                      isPlaying: playerState.currentSong?.id == song.id,
                      dragHandle: dragHandleWidget,
                      onRemoveFromPlaylist: () => _removeSong(song),
                      onTap: () {
                        ref.read(audioPlayerControllerProvider.notifier).playSong(
                              song,
                              queue: _currentSongs,
                              index: index,
                            );
                      },
                    ),
                  ),
                );
              },
            ),
          const SliverToBoxAdapter(
            child: SizedBox(height: Dimensions.miniPlayerHeight + Dimensions.space64),
          ),
        ],
      ),
    );
  }
}
