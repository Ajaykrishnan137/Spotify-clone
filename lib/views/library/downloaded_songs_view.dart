import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../../models/song_model.dart';
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
  bool _isLoading = true;
  int _totalStorageBytes = 0;

  @override
  void initState() {
    super.initState();
    _loadAndVerifyDownloads();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAndVerifyDownloads() async {
    setState(() => _isLoading = true);

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

      if (mounted) {
        setState(() {
          _verifiedSongs = verified;
          _totalStorageBytes = totalBytes;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
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

  @override
  Widget build(BuildContext context) {
    // Listen to download tasks so when a new download completes, we refresh
    ref.listen<Map<String, DownloadTaskState>>(downloadControllerProvider, (prev, next) {
      _loadAndVerifyDownloads();
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
            onPressed: _loadAndVerifyDownloads,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.cyanAccent))
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
                                  key: Key('downloaded_${song.id}'),
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
                                    await ref.read(downloadControllerProvider.notifier).deleteDownload(song.id);
                                    _loadAndVerifyDownloads();
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Deleted "${song.title}" from downloads'),
                                          backgroundColor: AppColors.surface,
                                        ),
                                      );
                                    }
                                  },
                                  child: SongTile(
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
