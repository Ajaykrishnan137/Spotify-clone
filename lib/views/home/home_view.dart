import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/song_model.dart';
import '../../controllers/audio_player_controller.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/dimensions.dart';
import '../../core/constants/app_strings.dart';
import '../../core/services/cloud_catalog_service.dart';
import '../../core/services/playlist_visibility_service.dart';
import '../shared_widgets/song_card.dart';
import '../shared_widgets/song_tile.dart';
import '../shared_widgets/spotify_logo.dart';
import '../playlist/playlist_detail_view.dart';

import '../../core/services/in_app_notifications_service.dart';
import 'notifications_view.dart';
import 'history_view.dart';
import '../settings/settings_view.dart';

class HomeView extends ConsumerWidget {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(audioPlayerControllerProvider);
    final songsAsync = ref.watch(allSongsProvider);
    final hiddenPlaylists = ref.watch(hiddenPlaylistsProvider);
    final unreadNotifsCount = ref.watch(inAppNotificationsNotifierProvider.notifier).unreadCount;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Fixed Top Bar: SkyTune Logo + Wordmark & Action Icons
            Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: Dimensions.space16),
              color: AppColors.background,
              child: Row(
                children: [
                  const SkyTuneDynamicLogo(size: 32),
                  const SizedBox(width: 12),
                  const SkyTuneWordmark(fontSize: 22),
                  const Spacer(),

                  // Notifications Icon with Badge & 48px Touch Target
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      IconButton(
                        iconSize: 26,
                        splashRadius: 24,
                        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                        icon: const Icon(Icons.notifications_none, color: AppColors.textPrimary),
                        tooltip: 'Notifications',
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const NotificationsView()),
                          );
                        },
                      ),
                      if (unreadNotifsCount > 0)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: AppColors.cyanAccent,
                              shape: BoxShape.circle,
                            ),
                            constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                            child: Text(
                              '$unreadNotifsCount',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),

                  // History Icon with 48px Touch Target
                  IconButton(
                    iconSize: 26,
                    splashRadius: 24,
                    constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                    icon: const Icon(Icons.history, color: AppColors.textPrimary),
                    tooltip: 'Listening History',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const HistoryView()),
                      );
                    },
                  ),

                  // Settings Icon with 48px Touch Target
                  IconButton(
                    iconSize: 26,
                    splashRadius: 24,
                    constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                    icon: const Icon(Icons.settings_outlined, color: AppColors.textPrimary),
                    tooltip: 'Settings',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SettingsView()),
                      );
                    },
                  ),
                ],
              ),
            ),

            // Scrollable Content
            Expanded(
              child: songsAsync.when(
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: CircularProgressIndicator(color: AppColors.accent),
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

                  // Group by folder / genre (excluding hidden/deleted playlists)
                  final genres = <String, List<SongModel>>{};
                  for (final song in songs) {
                    if (!hiddenPlaylists.contains(song.genre.toLowerCase().trim())) {
                      genres.putIfAbsent(song.genre, () => []).add(song);
                    }
                  }

                  final recentlyPlayedList = playerState.recentlyPlayed;

                  return ListView(
                    padding: const EdgeInsets.only(
                      top: Dimensions.space8,
                      bottom: Dimensions.miniPlayerHeight + Dimensions.space64,
                    ),
                    children: [
                      // 1. RECENTLY PLAYED Horizontal Row (Newest first, max 20, deduplicated)
                      if (recentlyPlayedList.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                            Dimensions.space16,
                            Dimensions.space12,
                            Dimensions.space16,
                            Dimensions.space8,
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.history, size: 20, color: AppColors.accent),
                              const SizedBox(width: 8),
                              Text(
                                AppStrings.recentlyPlayed,
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(
                          height: Dimensions.songCardHeight,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: Dimensions.space16),
                            itemCount: recentlyPlayedList.length,
                            itemBuilder: (context, index) {
                              final song = recentlyPlayedList[index];
                              return SongCard(
                                song: song,
                                onTap: () {
                                  ref.read(audioPlayerControllerProvider.notifier).playSong(
                                        song,
                                        queue: recentlyPlayedList,
                                        index: index,
                                      );
                                },
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: Dimensions.space16),
                      ],

                      // 2. Quick Picks / Featured Horizontal Row
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: Dimensions.space16, vertical: Dimensions.space8),
                        child: Text(
                          AppStrings.madeForYou,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ),
                      SizedBox(
                        height: Dimensions.songCardHeight,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: Dimensions.space16),
                          itemCount: songs.take(12).length,
                          itemBuilder: (context, index) {
                            final song = songs[index];
                            return SongCard(
                              song: song,
                              onTap: () {
                                ref.read(audioPlayerControllerProvider.notifier).playSong(
                                      song,
                                      queue: songs.take(12).toList(),
                                      index: index,
                                    );
                              },
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: Dimensions.space24),

                      // 3. Render sections for each folder / genre
                      ...genres.entries.map((entry) {
                        final category = entry.key;
                        final categorySongs = entry.value;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: Dimensions.space16, vertical: Dimensions.space8),
                              child: InkWell(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => PlaylistDetailView(
                                        title: category.toUpperCase(),
                                        subtitle: 'Legal Music Collection',
                                        coverUrl: categorySongs.isNotEmpty ? categorySongs.first.coverUrl : null,
                                        songs: categorySongs,
                                      ),
                                    ),
                                  );
                                },
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          category.toUpperCase(),
                                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 1.1,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.textSecondary),
                                      ],
                                    ),
                                    Text(
                                      'See all (${categorySongs.length})',
                                      style: const TextStyle(fontSize: 12, color: AppColors.accent, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            ...categorySongs.take(6).map(
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
