import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/song_model.dart';
import '../../models/download_state.dart';
import '../../controllers/audio_player_controller.dart';
import '../../controllers/download_controller.dart';
import '../../controllers/playlist_controller.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/dimensions.dart';
import '../shared_widgets/app_image.dart';
import '../shared_widgets/song_tile.dart';

class PlaylistDetailView extends ConsumerStatefulWidget {
  final String title;
  final String subtitle;
  final String? coverUrl;
  final List<SongModel> songs;
  final String? playlistId;

  const PlaylistDetailView({
    super.key,
    required this.title,
    required this.subtitle,
    this.coverUrl,
    required this.songs,
    this.playlistId,
  });

  @override
  ConsumerState<PlaylistDetailView> createState() => _PlaylistDetailViewState();
}

class _PlaylistDetailViewState extends ConsumerState<PlaylistDetailView> {
  late List<SongModel> _currentSongs;
  bool _isMultiSelect = false;
  final Set<String> _selectedSongIds = {};

  @override
  void initState() {
    super.initState();
    _currentSongs = List.from(widget.songs);
  }

  void _removeSong(SongModel song) {
    final index = _currentSongs.indexOf(song);
    setState(() {
      _currentSongs.removeWhere((s) => s.id == song.id);
      _selectedSongIds.remove(song.id);
    });

    if (widget.playlistId != null) {
      ref.read(localPlaylistControllerProvider.notifier).removeSongFromPlaylist(widget.playlistId!, song.id);
    }

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Removed "${song.title}" from ${widget.title}'),
        backgroundColor: AppColors.surface,
        action: SnackBarAction(
          label: 'UNDO',
          textColor: AppColors.cyanAccent,
          onPressed: () {
            setState(() {
              if (index >= 0 && index <= _currentSongs.length) {
                _currentSongs.insert(index, song);
              } else {
                _currentSongs.add(song);
              }
            });
            if (widget.playlistId != null) {
              ref.read(localPlaylistControllerProvider.notifier).addSongToPlaylist(widget.playlistId!, song);
            }
          },
        ),
      ),
    );
  }

  void _removeSelectedSongs() {
    final removed = _currentSongs.where((s) => _selectedSongIds.contains(s.id)).toList();
    if (removed.isEmpty) return;

    setState(() {
      _currentSongs.removeWhere((s) => _selectedSongIds.contains(s.id));
      _selectedSongIds.clear();
      _isMultiSelect = false;
    });

    if (widget.playlistId != null) {
      for (final s in removed) {
        ref.read(localPlaylistControllerProvider.notifier).removeSongFromPlaylist(widget.playlistId!, s.id);
      }
    }

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Removed ${removed.length} songs from ${widget.title}'),
        backgroundColor: AppColors.surface,
        action: SnackBarAction(
          label: 'UNDO',
          textColor: AppColors.cyanAccent,
          onPressed: () {
            setState(() {
              _currentSongs.addAll(removed);
            });
            if (widget.playlistId != null) {
              for (final s in removed) {
                ref.read(localPlaylistControllerProvider.notifier).addSongToPlaylist(widget.playlistId!, s);
              }
            }
          },
        ),
      ),
    );
  }

  void _confirmDeleteEntirePlaylist() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Delete "${widget.title}"?'),
        content: const Text(
          'This playlist will be deleted permanently. Downloaded songs will NOT be removed.',
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
              if (widget.playlistId != null) {
                ref.read(localPlaylistControllerProvider.notifier).deletePlaylist(widget.playlistId!);
              }
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Deleted playlist "${widget.title}"'),
                  backgroundColor: AppColors.surface,
                ),
              );
            },
            child: const Text('Delete', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final playerState = ref.watch(audioPlayerControllerProvider);
    final batchStatus = ref.watch(batchDownloadStatusStreamProvider).value ??
        ref.read(downloadControllerProvider.notifier).currentBatchStatus;
    final downloadTasks = ref.watch(downloadControllerProvider);

    final allDownloaded = _currentSongs.isNotEmpty &&
        _currentSongs.every((s) => downloadTasks[s.id]?.status == DownloadStatus.downloaded);

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
                  icon: const Icon(Icons.delete, color: AppColors.error),
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
                IconButton(
                  icon: const Icon(Icons.checklist, color: Colors.white),
                  tooltip: 'Select Multiple',
                  onPressed: () {
                    setState(() {
                      _isMultiSelect = true;
                    });
                  },
                ),
                if (widget.playlistId != null)
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, color: Colors.white),
                    color: AppColors.card,
                    onSelected: (val) {
                      if (val == 'delete_playlist') {
                        _confirmDeleteEntirePlaylist();
                      }
                    },
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(
                        value: 'delete_playlist',
                        child: Row(
                          children: [
                            Icon(Icons.delete_forever, color: AppColors.error, size: 20),
                            SizedBox(width: 8),
                            Text('Delete Playlist', style: TextStyle(color: AppColors.error)),
                          ],
                        ),
                      ),
                    ],
                  ),
              ],
            ],
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                _isMultiSelect ? '${_selectedSongIds.length} Selected' : widget.title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
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

          // Download All active progress & control card
          if (batchStatus.isBatchActive)
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
                            batchStatus.isPaused
                                ? 'Download paused (${batchStatus.completedCount}/${batchStatus.totalCount})'
                                : 'Downloading ${batchStatus.completedCount}/${batchStatus.totalCount} tracks...',
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        // Pause / Resume Button
                        IconButton(
                          icon: Icon(
                            batchStatus.isPaused ? Icons.play_arrow : Icons.pause,
                            color: AppColors.textPrimary,
                            size: 22,
                          ),
                          tooltip: batchStatus.isPaused ? 'Resume' : 'Pause',
                          onPressed: () {
                            if (batchStatus.isPaused) {
                              ref.read(downloadControllerProvider.notifier).resumeBatchDownload();
                            } else {
                              ref.read(downloadControllerProvider.notifier).pauseBatchDownload();
                            }
                          },
                        ),
                        // Cancel / Stop Button
                        IconButton(
                          icon: const Icon(Icons.stop_circle_outlined, color: AppColors.error, size: 24),
                          tooltip: 'Stop & Cancel Download All',
                          onPressed: () {
                            ref.read(downloadControllerProvider.notifier).cancelBatchDownload();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Download stopped. Partial files deleted.'),
                                backgroundColor: AppColors.surface,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    LinearProgressIndicator(
                      value: batchStatus.totalCount > 0
                          ? (batchStatus.completedCount / batchStatus.totalCount).clamp(0.0, 1.0)
                          : null,
                      backgroundColor: AppColors.surface,
                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accent),
                      minHeight: 4,
                    ),
                    if (batchStatus.currentSongTitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Current: ${batchStatus.currentSongTitle}',
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

                  // Download All or Stop button in action row
                  if (batchStatus.isBatchActive)
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error.withOpacity(0.2),
                        foregroundColor: AppColors.error,
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text('Cancel All'),
                      onPressed: () {
                        ref.read(downloadControllerProvider.notifier).cancelBatchDownload();
                      },
                    )
                  else
                    IconButton(
                      icon: Icon(
                        allDownloaded ? Icons.download_done : Icons.arrow_circle_down_rounded,
                        color: allDownloaded ? AppColors.accent : AppColors.textSecondary,
                        size: 28,
                      ),
                      tooltip: allDownloaded ? 'Playlist Downloaded' : 'Download all',
                      onPressed: () {
                        if (!allDownloaded) {
                          ref.read(downloadControllerProvider.notifier).downloadMultipleSongs(_currentSongs);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Starting download of ${_currentSongs.length} songs...'),
                              duration: const Duration(seconds: 2),
                              backgroundColor: AppColors.card,
                            ),
                          );
                        }
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
            const SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Text(
                    'No songs in this playlist',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
                  ),
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final song = _currentSongs[index];
                  final isSelected = _selectedSongIds.contains(song.id);

                  if (_isMultiSelect) {
                    return CheckboxListTile(
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

                  return Dismissible(
                    key: Key('playlist_song_${song.id}_$index'),
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
                      song: song,
                      isPlaying: playerState.currentSong?.id == song.id,
                      onRemoveFromPlaylist: () => _removeSong(song),
                      onTap: () {
                        ref.read(audioPlayerControllerProvider.notifier).playSong(
                              song,
                              queue: _currentSongs,
                              index: index,
                            );
                      },
                    ),
                  );
                },
                childCount: _currentSongs.length,
              ),
            ),
          const SliverToBoxAdapter(
            child: SizedBox(height: Dimensions.space64),
          ),
        ],
      ),
    );
  }
}
