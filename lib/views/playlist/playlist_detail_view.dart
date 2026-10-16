import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/song_model.dart';
import '../../controllers/audio_player_controller.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/dimensions.dart';
import '../shared_widgets/app_image.dart';
import '../shared_widgets/song_tile.dart';

class PlaylistDetailView extends ConsumerWidget {
  final String title;
  final String subtitle;
  final String? coverUrl;
  final List<SongModel> songs;

  const PlaylistDetailView({
    super.key,
    required this.title,
    required this.subtitle,
    this.coverUrl,
    required this.songs,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(audioPlayerControllerProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 280.0,
            pinned: true,
            backgroundColor: AppColors.surface,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  if (coverUrl != null && coverUrl!.isNotEmpty)
                    AppImage(url: coverUrl!, fit: BoxFit.cover, borderRadius: 0)
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
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(Dimensions.space16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(subtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                      const SizedBox(height: 4),
                      Text('${songs.length} songs', style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  FloatingActionButton(
                    backgroundColor: AppColors.accent,
                    onPressed: () {
                      if (songs.isNotEmpty) {
                        ref.read(audioPlayerControllerProvider.notifier).playSong(
                              songs.first,
                              queue: songs,
                              index: 0,
                            );
                      }
                    },
                    child: const Icon(Icons.play_arrow, color: Colors.black, size: 36),
                  ),
                ],
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final song = songs[index];
                return SongTile(
                  song: song,
                  isPlaying: playerState.currentSong?.id == song.id,
                  onTap: () {
                    ref.read(audioPlayerControllerProvider.notifier).playSong(
                          song,
                          queue: songs,
                          index: index,
                        );
                  },
                );
              },
              childCount: songs.length,
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
