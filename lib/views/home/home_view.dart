import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/song_model.dart';
import '../../controllers/audio_player_controller.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/dimensions.dart';
import '../../core/constants/app_strings.dart';
import '../../core/services/cloud_catalog_service.dart';
import '../shared_widgets/song_card.dart';
import '../shared_widgets/song_tile.dart';

class HomeView extends ConsumerWidget {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(audioPlayerControllerProvider);
    final songsAsync = ref.watch(allSongsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            pinned: false,
            backgroundColor: AppColors.background,
            title: const Text(
              'Good evening',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.notifications_none, color: AppColors.textPrimary),
                onPressed: () {},
              ),
              IconButton(
                icon: const Icon(Icons.history, color: AppColors.textPrimary),
                onPressed: () {},
              ),
              IconButton(
                icon: const Icon(Icons.settings_outlined, color: AppColors.textPrimary),
                onPressed: () {},
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: songsAsync.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              ),
              error: (err, stack) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Text('Error loading catalog: $err', style: const TextStyle(color: Colors.red)),
                ),
              ),
              data: (songs) {
                if (songs.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Text('No songs loaded in catalog yet.', style: TextStyle(color: AppColors.textSecondary)),
                    ),
                  );
                }

                // Group by folder / genre
                final genres = <String, List<SongModel>>{};
                for (final song in songs) {
                  genres.putIfAbsent(song.genre, () => []).add(song);
                }

                final featuredSongs = songs.take(12).toList();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Quick Mix Shelf
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: Dimensions.space16, vertical: Dimensions.space8),
                      child: Text(
                        AppStrings.recentlyPlayed,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    SizedBox(
                      height: Dimensions.songCardHeight,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: Dimensions.space16),
                        itemCount: featuredSongs.length,
                        itemBuilder: (context, index) {
                          final song = featuredSongs[index];
                          return SongCard(
                            song: song,
                            onTap: () {
                              ref.read(audioPlayerControllerProvider.notifier).playSong(
                                    song,
                                    queue: featuredSongs,
                                    index: index,
                                  );
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: Dimensions.space24),

                    // Render sections for each folder / genre
                    ...genres.entries.map((entry) {
                      final category = entry.key;
                      final categorySongs = entry.value;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: Dimensions.space16, vertical: Dimensions.space8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  category.toUpperCase(),
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.1,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                Text(
                                  '${categorySongs.length} songs',
                                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          ...categorySongs.take(8).map(
                            (song) => SongTile(
                              song: song,
                              isPlaying: playerState.currentSong?.id == song.id,
                              onTap: () {
                                ref.read(audioPlayerControllerProvider.notifier).playSong(
                                      song,
                                      queue: categorySongs,
                                      index: categorySongs.indexOf(song),
                                    );
                              },
                            ),
                          ),
                          const SizedBox(height: Dimensions.space16),
                        ],
                      );
                    }),
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
