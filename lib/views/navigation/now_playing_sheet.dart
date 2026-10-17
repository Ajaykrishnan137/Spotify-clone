import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:palette_generator/palette_generator.dart';
import '../../controllers/audio_player_controller.dart';
import '../../controllers/download_controller.dart';
import '../../controllers/playlist_controller.dart';
import '../../models/download_state.dart';
import '../../models/song_model.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/dimensions.dart';
import '../../core/utils/formatters.dart';
import '../shared_widgets/app_image.dart';
import '../shared_widgets/download_button.dart';
import '../shared_widgets/spotify_logo.dart';
import 'queue_sheet.dart';

class NowPlayingSheet extends ConsumerStatefulWidget {
  const NowPlayingSheet({super.key});

  @override
  ConsumerState<NowPlayingSheet> createState() => _NowPlayingSheetState();
}

class _NowPlayingSheetState extends ConsumerState<NowPlayingSheet> {
  Color _dominantColor = AppColors.surface;

  @override
  void initState() {
    super.initState();
    _extractPalette();
  }

  Future<void> _extractPalette() async {
    final song = ref.read(audioPlayerControllerProvider).currentSong;
    if (song != null && song.coverUrl.isNotEmpty && (song.coverUrl.startsWith('http') || song.coverUrl.startsWith('assets/'))) {
      try {
        final ImageProvider provider = song.coverUrl.startsWith('assets/')
            ? AssetImage(song.coverUrl) as ImageProvider
            : CachedNetworkImageProvider(song.coverUrl);

        final palette = await PaletteGenerator.fromImageProvider(
          provider,
          size: const Size(100, 100),
          maximumColorCount: 10,
        );
        if (mounted && palette.dominantColor != null) {
          setState(() {
            _dominantColor = palette.dominantColor!.color;
          });
        }
      } catch (_) {}
    }
  }

  void _showAddToPlaylistDialog(SongModel song) {
    final playlistsAsync = ref.read(localPlaylistControllerProvider);

    playlistsAsync.whenData((playlists) {
      if (playlists.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No playlists yet! Create one in Your Library first.')),
        );
        return;
      }

      showDialog(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            backgroundColor: AppColors.card,
            title: const Text('Add to Playlist', style: TextStyle(color: AppColors.textPrimary)),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: playlists.length,
                itemBuilder: (c, idx) {
                  final pl = playlists[idx];
                  return ListTile(
                    leading: const Icon(Icons.queue_music, color: AppColors.accent),
                    title: Text(pl.name, style: const TextStyle(color: AppColors.textPrimary)),
                    onTap: () {
                      ref.read(localPlaylistControllerProvider.notifier).addSongToPlaylist(pl.id, song);
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Added to "${pl.name}"'), backgroundColor: AppColors.accent),
                      );
                    },
                  );
                },
              ),
            ),
          );
        },
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final playerState = ref.watch(audioPlayerControllerProvider);
    final themeColor = ref.watch(nowPlayingThemeColorProvider);
    final song = playerState.currentSong;

    if (song == null) {
      return const SizedBox.shrink();
    }

    final double maxMs = playerState.duration.inMilliseconds.toDouble();
    final double curMs = playerState.position.inMilliseconds.toDouble().clamp(0.0, maxMs > 0 ? maxMs : 1.0);

    final effectiveColor = _dominantColor != AppColors.surface ? _dominantColor : themeColor;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF1E90FF), // Primary Sky Blue
            Color(0xFF5B4BFF), // Deep Blue/Purple
            AppColors.deepNightBlue,
          ],
          stops: [0.0, 0.45, 0.85],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Dimensions.space24),
          child: Column(
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.keyboard_arrow_down, size: 30),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Column(
                    children: [
                      const Text(
                        'PLAYING FROM ALBUM',
                        style: TextStyle(fontSize: 10, letterSpacing: 1.0, color: AppColors.textSecondary),
                      ),
                      Text(
                        song.album,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.queue_music, size: 26, color: AppColors.textPrimary),
                    tooltip: 'Queue',
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        useSafeArea: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => const QueueSheet(),
                      );
                    },
                  ),
                ],
              ),
              const Spacer(flex: 1),
              // Cover Art with dynamic breathing and glow
              AnimatedScale(
                scale: playerState.isPlaying ? 1.0 : 0.90,
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeOutBack,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
                    boxShadow: [
                      BoxShadow(
                        color: effectiveColor.withOpacity(playerState.isPlaying ? 0.35 : 0.1),
                        blurRadius: playerState.isPlaying ? 28 : 12,
                        spreadRadius: playerState.isPlaying ? 4 : 0,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: AppImage(
                    url: song.coverUrl,
                    width: MediaQuery.of(context).size.width - 64,
                    height: MediaQuery.of(context).size.width - 64,
                    borderRadius: Dimensions.radiusLarge,
                  ),
                ),
              ),
              const Spacer(flex: 1),
              // Title, Artist, Like & Add-to-Playlist
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          song.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: Dimensions.space4),
                        Text(
                          song.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Download button with cancel / progress
                      Consumer(
                        builder: (context, ref, _) {
                          final downloadTasks = ref.watch(downloadControllerProvider);
                          final task = downloadTasks[song.id] ?? DownloadTaskState(songId: song.id);
                          return DownloadButton(
                            status: task.status,
                            progress: task.progress,
                            onDownload: () => ref.read(downloadControllerProvider.notifier).startDownload(song),
                            onDelete: () => ref.read(downloadControllerProvider.notifier).deleteDownload(song.id),
                            onCancel: () => ref.read(downloadControllerProvider.notifier).cancelTrackDownload(song.id),
                          );
                        },
                      ),
                      // Add to playlist button
                      IconButton(
                        icon: const Icon(Icons.playlist_add, color: AppColors.textPrimary, size: 26),
                        tooltip: 'Add to Playlist',
                        onPressed: () => _showAddToPlaylistDialog(song),
                      ),
                      // Like button (toggles liked playlist)
                      IconButton(
                        icon: const Icon(Icons.favorite, color: AppColors.sunsetCoral, size: 28),
                        tooltip: 'Like Song',
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Added "${song.title}" to Liked Songs'),
                              backgroundColor: AppColors.sunsetCoral,
                              duration: const Duration(seconds: 1),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: Dimensions.space16),
              // Progress Slider (Cyan Accent)
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                  activeTrackColor: AppColors.cyanAccent,
                  inactiveTrackColor: AppColors.textSecondary.withOpacity(0.3),
                  thumbColor: Colors.white,
                ),
                child: Slider(
                  value: curMs,
                  max: maxMs > 0 ? maxMs : 1.0,
                  onChanged: (val) {
                    ref.read(audioPlayerControllerProvider.notifier).seek(
                          Duration(milliseconds: val.toInt()),
                        );
                  },
                ),
              ),
              // Time stamps
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Dimensions.space8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      Formatters.formatDuration(playerState.position),
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                    ),
                    Text(
                      Formatters.formatDuration(playerState.duration),
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: Dimensions.space16),
              // Main Playback Controls
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.shuffle,
                      color: playerState.isShuffle ? effectiveColor : AppColors.textSecondary,
                    ),
                    onPressed: () {
                      ref.read(audioPlayerControllerProvider.notifier).toggleShuffle();
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.skip_previous, size: 36, color: AppColors.textPrimary),
                    onPressed: () {
                      ref.read(audioPlayerControllerProvider.notifier).skipToPrevious();
                    },
                  ),
                  GestureDetector(
                    onTap: () {
                      ref.read(audioPlayerControllerProvider.notifier).togglePlayPause();
                    },
                    child: Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        color: effectiveColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: effectiveColor.withOpacity(0.4),
                            blurRadius: 16,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Icon(
                        playerState.isPlaying ? Icons.pause : Icons.play_arrow,
                        color: Colors.black,
                        size: 38,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.skip_next, size: 36, color: AppColors.textPrimary),
                    onPressed: () {
                      ref.read(audioPlayerControllerProvider.notifier).skipToNext();
                    },
                  ),
                  IconButton(
                    icon: Icon(
                      playerState.loopMode == PlayerLoopMode.one
                          ? Icons.repeat_one
                          : (playerState.loopMode == PlayerLoopMode.all ? Icons.repeat : Icons.repeat),
                      color: playerState.loopMode != PlayerLoopMode.off ? effectiveColor : AppColors.textSecondary,
                    ),
                    tooltip: 'Repeat: ${playerState.loopMode.name.toUpperCase()}',
                    onPressed: () {
                      ref.read(audioPlayerControllerProvider.notifier).toggleLoop();
                    },
                  ),
                ],
              ),
              const SizedBox(height: Dimensions.space32),
            ],
          ),
        ),
      ),
    );
  }
}
