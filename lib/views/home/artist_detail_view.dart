import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/song_model.dart';
import '../../controllers/audio_player_controller.dart';
import '../../controllers/download_controller.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/dimensions.dart';
import '../../core/services/online_music_search_service.dart';
import '../shared_widgets/app_image.dart';
import '../shared_widgets/song_tile.dart';
import '../shared_widgets/add_to_playlist_sheet.dart';
import '../../core/utils/app_snackbar.dart';
import '../../core/services/artist_avatar_service.dart';

class ArtistDetailView extends ConsumerStatefulWidget {
  final String artistName;
  final String? artistAvatarUrl;

  const ArtistDetailView({
    super.key,
    required this.artistName,
    this.artistAvatarUrl,
  });

  @override
  ConsumerState<ArtistDetailView> createState() => _ArtistDetailViewState();
}

class _ArtistDetailViewState extends ConsumerState<ArtistDetailView> {
  List<SongModel> _songs = [];
  bool _isLoading = true;
  String? _error;
  String? _resolvedAvatarUrl;

  @override
  void initState() {
    super.initState();
    _resolvedAvatarUrl = widget.artistAvatarUrl;
    _fetchArtistSongs();
    _resolveAvatarIfNeeded();
  }

  Future<void> _resolveAvatarIfNeeded() async {
    if (_resolvedAvatarUrl == null || _resolvedAvatarUrl!.isEmpty || _resolvedAvatarUrl!.contains('unsplash')) {
      final url = await ArtistAvatarService.getArtistAvatarUrl(widget.artistName);
      if (mounted && url != null && url.isNotEmpty) {
        setState(() {
          _resolvedAvatarUrl = url;
        });
      }
    }
  }

  Future<void> _fetchArtistSongs() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final results = await OnlineMusicSearchService.searchOnline(widget.artistName, limit: 30);
      if (mounted) {
        setState(() {
          _songs = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load songs for ${widget.artistName}. Only legal licensed sources are queried.';
          _isLoading = false;
        });
      }
    }
  }

  void _showSongOptions(BuildContext context, SongModel song) {
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
                leading: AppImage(url: song.coverUrl, width: 44, height: 44),
                title: Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                subtitle: Text(song.artist, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textSecondary)),
              ),
              const Divider(color: AppColors.elevated),
              ListTile(
                leading: const Icon(Icons.playlist_play, color: AppColors.textPrimary),
                title: const Text('Play Next', style: TextStyle(color: AppColors.textPrimary)),
                onTap: () {
                  Navigator.pop(ctx);
                  ref.read(audioPlayerControllerProvider.notifier).playNext(song);
                  AppSnackBar.showInfo(context: context, message: 'Playing next: "${song.title}"');
                },
              ),
              ListTile(
                leading: const Icon(Icons.queue_music, color: AppColors.textPrimary),
                title: const Text('Add to Queue', style: TextStyle(color: AppColors.textPrimary)),
                onTap: () {
                  Navigator.pop(ctx);
                  ref.read(audioPlayerControllerProvider.notifier).addToQueue(song);
                  AppSnackBar.showInfo(context: context, message: 'Added to queue: "${song.title}"');
                },
              ),
              ListTile(
                leading: const Icon(Icons.playlist_add, color: AppColors.textPrimary),
                title: const Text('Add to Playlist', style: TextStyle(color: AppColors.textPrimary)),
                onTap: () {
                  Navigator.pop(ctx);
                  AddToPlaylistSheet.show(context, songs: [song]);
                },
              ),
              ListTile(
                leading: const Icon(Icons.download, color: AppColors.textPrimary),
                title: const Text('Download for Offline Play', style: TextStyle(color: AppColors.textPrimary)),
                onTap: () {
                  Navigator.pop(ctx);
                  ref.read(downloadControllerProvider.notifier).startDownload(song);
                  AppSnackBar.showInfo(context: context, message: 'Downloading "${song.title}"...');
                },
              ),
            ],
          ),
        );
      },
    );
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
                  Container(height: 14, width: 140, decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(4))),
                  const SizedBox(height: 6),
                  Container(height: 11, width: 90, decoration: BoxDecoration(color: AppColors.elevated, borderRadius: BorderRadius.circular(4))),
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
    final playerState = ref.watch(audioPlayerControllerProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 260.0,
            pinned: true,
            backgroundColor: AppColors.surface,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                widget.artistName,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.white),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  if (_resolvedAvatarUrl != null && _resolvedAvatarUrl!.isNotEmpty)
                    AppImage(url: _resolvedAvatarUrl!, fit: BoxFit.cover, borderRadius: 0)
                  else
                    Container(
                      decoration: BoxDecoration(
                        gradient: ArtistAvatarService.getGradientForArtist(widget.artistName),
                      ),
                      child: Center(
                        child: Text(
                          ArtistAvatarService.getInitials(widget.artistName),
                          style: const TextStyle(
                            fontSize: 72,
                            fontWeight: FontWeight.bold,
                            color: Colors.white24,
                            letterSpacing: 4,
                          ),
                        ),
                      ),
                    ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, AppColors.background.withOpacity(0.9), AppColors.background],
                        stops: const [0.3, 0.8, 1.0],
                      ),
                    ),
                  ),
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
                    child: Text(
                      _isLoading ? 'Loading artist catalog...' : '${_songs.length} songs found online',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ),
                  if (_songs.isNotEmpty) ...[
                    IconButton(
                      icon: const Icon(Icons.shuffle, color: AppColors.cyanAccent, size: 26),
                      tooltip: 'Shuffle Artist Songs',
                      onPressed: () {
                        final shuffled = List<SongModel>.from(_songs)..shuffle();
                        ref.read(audioPlayerControllerProvider.notifier).playSong(
                              shuffled.first,
                              queue: shuffled,
                              index: 0,
                            );
                      },
                    ),
                    const SizedBox(width: 8),
                    FloatingActionButton.small(
                      backgroundColor: AppColors.accent,
                      onPressed: () {
                        ref.read(audioPlayerControllerProvider.notifier).playSong(
                              _songs.first,
                              queue: _songs,
                              index: 0,
                            );
                      },
                      child: const Icon(Icons.play_arrow, color: Colors.black, size: 28),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (_isLoading)
            SliverFillRemaining(child: _buildSkeletonLoader())
          else if (_error != null)
            SliverFillRemaining(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.wifi_off_rounded, size: 48, color: AppColors.textSecondary),
                      const SizedBox(height: 12),
                      Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.cyanAccent),
                        onPressed: _fetchArtistSongs,
                        child: const Text('Retry', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else if (_songs.isEmpty)
            const SliverFillRemaining(
              child: Center(
                child: Text(
                  'No songs found from licensed sources for this artist.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final song = _songs[index];
                  return SongTile(
                    key: ValueKey('artist_song_${song.id}'),
                    song: song,
                    isPlaying: playerState.currentSong?.id == song.id,
                    trailing: IconButton(
                      icon: const Icon(Icons.more_vert, color: AppColors.textSecondary, size: 20),
                      onPressed: () => _showSongOptions(context, song),
                    ),
                    onTap: () {
                      ref.read(audioPlayerControllerProvider.notifier).playSong(
                            song,
                            queue: _songs,
                            index: index,
                          );
                    },
                  );
                },
                childCount: _songs.length,
              ),
            ),
          const SliverToBoxAdapter(
            child: SizedBox(height: Dimensions.miniPlayerHeight + Dimensions.space64),
          ),
        ],
      ),
    );
  }
}
