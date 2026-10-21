import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../../models/song_model.dart';
import '../../models/download_state.dart';
import '../../controllers/audio_player_controller.dart';
import '../../controllers/download_controller.dart';
import '../../controllers/playlist_controller.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/dimensions.dart';
import '../../core/utils/formatters.dart';
import '../shared_widgets/song_tile.dart';
import '../shared_widgets/empty_view.dart';

enum DownloadSortOption {
  recent('Recently Downloaded'),
  titleAZ('Title A-Z'),
  artistAZ('Artist A-Z');

  final String label;
  const DownloadSortOption(this.label);
}

class DownloadedSongsView extends ConsumerStatefulWidget {
  const DownloadedSongsView({super.key});

  @override
  ConsumerState<DownloadedSongsView> createState() => _DownloadedSongsViewState();
}

class _DownloadedSongsViewState extends ConsumerState<DownloadedSongsView> {
  final TextEditingController _searchController = TextEditingController();
  DownloadSortOption _sortOption = DownloadSortOption.recent;
  List<SongModel> _verifiedSongs = [];
  bool _isInitialLoading = true;
  bool _isRefreshing = false;
  int _totalStorageBytes = 0;

  @override
  void initState() {
    super.initState();
    _loadAndVerifyDownloads(isFirstLoad: true);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAndVerifyDownloads({bool isFirstLoad = false}) async {
    if (_isRefreshing) return;
    _isRefreshing = true;
    if (isFirstLoad && _verifiedSongs.isEmpty) {
      setState(() => _isInitialLoading = true);
    }

    try {
      final songsDao = ref.read(songsDaoProvider);
      final rawDownloaded = await songsDao.watchDownloadedSongs().first;
      final appDocDir = await getApplicationDocumentsDirectory();

      final List<SongModel> verified = [];
      int totalBytes = 0;

      for (final song in rawDownloaded) {
        String? validPath;

        // Check 1: offline_music/<id>.mp3
        final f1 = File(p.join(appDocDir.path, 'offline_music', '${song.id}.mp3'));
        // Check 2: secure_audio/<id>.dat
        final f2 = File(p.join(appDocDir.path, 'secure_audio', '${song.id}.dat'));
        // Check 3: song.localPath
        final f3 = song.localPath != null ? File(song.localPath!) : null;

        if (f1.existsSync()) {
          validPath = f1.path;
          totalBytes += f1.lengthSync();
        } else if (f2.existsSync()) {
          validPath = f2.path;
          totalBytes += f2.lengthSync();
        } else if (f3 != null && f3.existsSync()) {
          validPath = f3.path;
          totalBytes += f3.lengthSync();
        }

        if (validPath != null) {
          verified.add(song.copyWith(localPath: validPath, isDownloaded: true));
        } else {
          // File missing from disk! Automatically sync database state
          await songsDao.deleteDownload(song.id);
        }
      }

      // Check if list actually changed before triggering full state update
      final bool hasChanged = verified.length != _verifiedSongs.length ||
          totalBytes != _totalStorageBytes ||
          !_areSongListsEqual(_verifiedSongs, verified);

      if (mounted) {
        setState(() {
          if (hasChanged || isFirstLoad) {
            _verifiedSongs = verified;
            _totalStorageBytes = totalBytes;
          }
          _isInitialLoading = false;
          _isRefreshing = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isInitialLoading = false;
          _isRefreshing = false;
        });
      }
    }
  }

  bool _areSongListsEqual(List<SongModel> a, List<SongModel> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id || a[i].localPath != b[i].localPath) {
        return false;
      }
    }
    return true;
  }

  List<SongModel> _getFilteredAndSortedSongs() {
    final query = _searchController.text.trim().toLowerCase();
    var list = _verifiedSongs.where((s) {
      if (query.isEmpty) return true;
      return s.title.toLowerCase().contains(query) ||
          s.artist.toLowerCase().contains(query) ||
          s.album.toLowerCase().contains(query);
    }).toList();

    switch (_sortOption) {
      case DownloadSortOption.recent:
        list.sort((a, b) {
          final aDate = a.downloadedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bDate = b.downloadedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return bDate.compareTo(aDate);
        });
        break;
      case DownloadSortOption.titleAZ:
        list.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        break;
      case DownloadSortOption.artistAZ:
        list.sort((a, b) => a.artist.toLowerCase().compareTo(b.artist.toLowerCase()));
        break;
    }
    return list;
  }

  Widget _buildSkeletonLoader() {
    return ListView.builder(
      itemCount: 8,
      padding: const EdgeInsets.symmetric(horizontal: Dimensions.space16, vertical: 8),
      itemBuilder: (_, __) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
              ),
            ),
            const SizedBox(width: Dimensions.space12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 14,
                    width: 140,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: 11,
                    width: 90,
                    decoration: BoxDecoration(
                      color: AppColors.elevated,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Only listen for transitions to DownloadStatus.downloaded or deletions
    ref.listen<Map<String, DownloadTaskState>>(downloadControllerProvider, (prev, next) {
      final prevMap = prev ?? {};
      bool shouldRefresh = false;
      for (final entry in next.entries) {
        final prevStatus = prevMap[entry.key]?.status;
        final nextStatus = entry.value.status;
        if (prevStatus != DownloadStatus.downloaded && nextStatus == DownloadStatus.downloaded) {
          shouldRefresh = true;
          break;
        }
        if (prevStatus == DownloadStatus.downloaded && nextStatus == DownloadStatus.notDownloaded) {
          shouldRefresh = true;
          break;
        }
      }
      if (shouldRefresh) {
        _loadAndVerifyDownloads();
      }
    });

    final playerState = ref.watch(audioPlayerControllerProvider);
    final displayedSongs = _getFilteredAndSortedSongs();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text(
          'Downloaded Music',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: AppColors.textPrimary),
        ),
        actions: [
          PopupMenuButton<DownloadSortOption>(
            icon: const Icon(Icons.sort, color: AppColors.textPrimary),
            tooltip: 'Sort Downloads',
            color: AppColors.card,
            onSelected: (opt) {
              setState(() => _sortOption = opt);
            },
            itemBuilder: (ctx) => DownloadSortOption.values.map((opt) {
              return PopupMenuItem(
                value: opt,
                child: Row(
                  children: [
                    if (_sortOption == opt)
                      const Icon(Icons.check, size: 18, color: AppColors.cyanAccent)
                    else
                      const SizedBox(width: 18),
                    const SizedBox(width: 8),
                    Text(
                      opt.label,
                      style: TextStyle(
                        color: _sortOption == opt ? AppColors.cyanAccent : AppColors.textPrimary,
                        fontWeight: _sortOption == opt ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.textPrimary),
            tooltip: 'Refresh & Verify Files',
            onPressed: () => _loadAndVerifyDownloads(isFirstLoad: false),
          ),
        ],
      ),
      body: _isInitialLoading
          ? _buildSkeletonLoader()
          : Column(
              children: [
                // Storage and stats bar
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: Dimensions.space16, vertical: 4),
                  padding: const EdgeInsets.symmetric(horizontal: Dimensions.space12, vertical: Dimensions.space8),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
                    border: Border.all(color: AppColors.elevated),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.offline_pin_rounded, color: AppColors.cyanAccent, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            '${_verifiedSongs.length} songs available offline',
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        Formatters.formatBytes(_totalStorageBytes),
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                // Search filter inside downloaded songs
                if (_verifiedSongs.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Dimensions.space16, vertical: 8),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (_) => setState(() {}),
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: AppColors.card,
                        hintText: 'Search downloaded songs or artists...',
                        hintStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                        prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.textSecondary),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18, color: AppColors.textSecondary),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {});
                                },
                              )
                            : null,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                // Main list or true empty state
                Expanded(
                  child: _verifiedSongs.isEmpty
                      ? const EmptyView(
                          icon: Icons.download_for_offline_outlined,
                          title: 'No downloaded songs',
                          subtitle: 'Tap the download icon on any track or playlist to listen offline anywhere without internet.',
                        )
                      : displayedSongs.isEmpty
                          ? const Center(
                              child: Text(
                                'No matching downloaded songs found.',
                                style: TextStyle(color: AppColors.textSecondary),
                              ),
                            )
                          : ListView.builder(
                              itemCount: displayedSongs.length,
                              itemBuilder: (context, index) {
                                final song = displayedSongs[index];
                                return Dismissible(
                                  key: ValueKey('downloaded_${song.id}'),
                                  direction: DismissDirection.endToStart,
                                  background: Container(
                                    alignment: Alignment.centerRight,
                                    padding: const EdgeInsets.only(right: 20),
                                    color: AppColors.error,
                                    child: const Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        Icon(Icons.delete_outline, color: Colors.white, size: 26),
                                        SizedBox(width: 6),
                                        Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ),
                                  onDismissed: (_) async {
                                    final removedSong = song;
                                    setState(() {
                                      _verifiedSongs.removeWhere((s) => s.id == removedSong.id);
                                    });
                                    await ref.read(downloadControllerProvider.notifier).deleteDownload(removedSong.id);
                                    _loadAndVerifyDownloads(isFirstLoad: false);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).clearSnackBars();
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Deleted "${removedSong.title}" from downloads'),
                                          backgroundColor: AppColors.surface,
                                          behavior: SnackBarBehavior.floating,
                                          margin: const EdgeInsets.only(
                                            left: 16,
                                            right: 16,
                                            bottom: Dimensions.miniPlayerHeight + 16,
                                          ),
                                          duration: const Duration(seconds: 4),
                                          dismissDirection: DismissDirection.horizontal,
                                        ),
                                      );
                                    }
                                  },
                                  child: SongTile(
                                    key: ValueKey('song_tile_${song.id}'),
                                    song: song,
                                    isPlaying: playerState.currentSong?.id == song.id,
                                    onTap: () {
                                      ref.read(audioPlayerControllerProvider.notifier).playSong(
                                            song,
                                            queue: displayedSongs,
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
    );
  }
}
