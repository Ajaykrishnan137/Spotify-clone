import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/song_model.dart';
import '../../models/playlist_model.dart';
import '../../controllers/audio_player_controller.dart';
import '../../controllers/playlist_controller.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/dimensions.dart';
import '../../core/constants/app_strings.dart';
import '../../core/services/cloud_catalog_service.dart';
import '../../core/services/home_content_service.dart';
import '../../core/services/in_app_notifications_service.dart';
import '../shared_widgets/song_card.dart';
import '../shared_widgets/song_tile.dart';
import '../shared_widgets/app_image.dart';
import '../shared_widgets/spotify_logo.dart';
import '../playlist/playlist_detail_view.dart';
import 'artist_detail_view.dart';
import 'notifications_view.dart';
import 'history_view.dart';
import '../settings/settings_view.dart';

class HomeView extends ConsumerStatefulWidget {
  const HomeView({super.key});

  @override
  ConsumerState<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends ConsumerState<HomeView> {
  List<SongModel> _trendingTamil = [];
  bool _isLoadingTrending = true;

  @override
  void initState() {
    super.initState();
    _loadTrendingTamil();
  }

  Future<void> _loadTrendingTamil() async {
    try {
      final songs = await HomeContentService.getTrendingTamilSongs();
      if (mounted) {
        setState(() {
          _trendingTamil = songs;
          _isLoadingTrending = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingTrending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final playerState = ref.watch(audioPlayerControllerProvider);
    final songsAsync = ref.watch(allSongsProvider);
    final userPlaylistsAsync = ref.watch(localPlaylistControllerProvider);
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
                  const SizedBox(width: Dimensions.space12),
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
              child: RefreshIndicator(
                color: AppColors.accent,
                backgroundColor: AppColors.surface,
                onRefresh: () async {
                  await _loadTrendingTamil();
                },
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(
                    top: Dimensions.space8,
                    bottom: Dimensions.miniPlayerHeight + Dimensions.space64,
                  ),
                  children: [
                    // SECTION A: Recently Played (Horizontal row, max 20, deduplicated)
                    if (playerState.recentlyPlayed.isNotEmpty) ...[
                      _buildSectionHeader(
                        context,
                        title: AppStrings.recentlyPlayed,
                        icon: Icons.history,
                      ),
                      SizedBox(
                        height: Dimensions.songCardHeight,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: Dimensions.space16),
                          itemCount: playerState.recentlyPlayed.length,
                          itemBuilder: (context, index) {
                            final song = playerState.recentlyPlayed[index];
                            return SongCard(
                              song: song,
                              onTap: () {
                                ref.read(audioPlayerControllerProvider.notifier).playSong(
                                      song,
                                      queue: playerState.recentlyPlayed,
                                      index: index,
                                    );
                              },
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: Dimensions.space24),
                    ],

                    // SECTION B: Made For You (Auto-generated mixes)
                    songsAsync.when(
                      data: (catalog) => _buildMadeForYouSection(context, playerState.recentlyPlayed, catalog),
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                    ),
                    const SizedBox(height: Dimensions.space24),

                    // SECTION C: Your Favourite Playlists (Max 10 + View All)
                    userPlaylistsAsync.when(
                      data: (playlists) => _buildFavouritePlaylistsSection(context, playlists),
                      loading: () => _buildSectionSkeleton(height: 140),
                      error: (_, __) => const SizedBox.shrink(),
                    ),
                    const SizedBox(height: Dimensions.space24),

                    // SECTION D: Popular Artists (Round avatars -> Artist Page)
                    _buildPopularArtistsSection(context),
                    const SizedBox(height: Dimensions.space24),

                    // SECTION E: Trending Tamil (Loaded online from legal sources, cached)
                    _buildTrendingTamilSection(context),
                    const SizedBox(height: Dimensions.space16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context, {
    required String title,
    IconData? icon,
    String? actionText,
    VoidCallback? onActionTap,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Dimensions.space16,
        Dimensions.space12,
        Dimensions.space16,
        Dimensions.space12,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20, color: AppColors.accent),
                const SizedBox(width: Dimensions.space8),
              ],
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.2,
                      color: AppColors.textPrimary,
                    ),
              ),
            ],
          ),
          if (actionText != null && onActionTap != null)
            InkWell(
              borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
              onTap: onActionTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Text(
                  actionText,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // SECTION B: MADE FOR YOU
  // -------------------------------------------------------------
  Widget _buildMadeForYouSection(
    BuildContext context,
    List<SongModel> history,
    List<SongModel> catalog,
  ) {
    final mixes = HomeContentService.getMadeForYouMixes(history, catalog);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          context,
          title: 'Made for you',
          icon: Icons.auto_awesome,
        ),
        SizedBox(
          height: 180,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: Dimensions.space16),
            itemCount: mixes.length,
            itemBuilder: (context, index) {
              final mix = mixes[index];
              final title = mix['title'] as String;
              final subtitle = mix['subtitle'] as String;
              final colors = mix['colors'] as List<Color>;
              final songs = mix['songs'] as List<SongModel>;

              return Container(
                width: 140,
                margin: const EdgeInsets.only(right: Dimensions.space12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
                  onTap: () {
                    if (songs.isEmpty) return;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PlaylistDetailView(
                          title: title,
                          subtitle: subtitle,
                          songs: songs,
                        ),
                      ),
                    );
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 130,
                        width: 140,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
                          gradient: LinearGradient(
                            colors: colors,
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: colors.first.withOpacity(0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(Dimensions.space12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.35),
                                borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
                              ),
                              child: const Text(
                                'SKYTUNE MIX',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${songs.length} songs',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.85),
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: Dimensions.space8),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------
  // SECTION C: YOUR FAVOURITE PLAYLISTS
  // -------------------------------------------------------------
  Widget _buildFavouritePlaylistsSection(BuildContext context, List<PlaylistModel> playlists) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          context,
          title: 'Your playlists',
          icon: Icons.queue_music,
          actionText: playlists.isNotEmpty ? 'View all' : null,
          onActionTap: () => context.go('/library'),
        ),
        if (playlists.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Dimensions.space16),
            child: InkWell(
              borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
              onTap: () => context.go('/library'),
              child: Container(
                padding: const EdgeInsets.all(Dimensions.space16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
                  border: Border.all(color: AppColors.elevated),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.accent.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(Dimensions.radiusMedium),
                      ),
                      child: const Icon(Icons.add, color: AppColors.accent, size: 28),
                    ),
                    const SizedBox(width: Dimensions.space16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Create your first playlist',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Tap to organize songs in your Library',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.textSecondary),
                  ],
                ),
              ),
            ),
          )
        else
          SizedBox(
            height: 170,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: Dimensions.space16),
              // Max 10 playlists + 1 View All card if >= 10
              itemCount: playlists.length > 10 ? 11 : playlists.length,
              itemBuilder: (context, index) {
                if (index == 10 && playlists.length > 10) {
                  return Container(
                    width: 120,
                    margin: const EdgeInsets.only(right: Dimensions.space12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
                      onTap: () => context.go('/library'),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
                              border: Border.all(color: AppColors.elevated),
                            ),
                            child: const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.arrow_forward, color: AppColors.accent, size: 28),
                                SizedBox(height: 6),
                                Text(
                                  'View all',
                                  style: TextStyle(
                                    color: AppColors.accent,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${playlists.length} total',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final pl = playlists[index];
                return Container(
                  width: 125,
                  margin: const EdgeInsets.only(right: Dimensions.space12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
                    onTap: () async {
                      final songs = await ref
                          .read(localPlaylistControllerProvider.notifier)
                          .getPlaylistSongs(pl.id);
                      if (context.mounted) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PlaylistDetailView(
                              playlistId: pl.id,
                              title: pl.name,
                              subtitle: '${songs.length} songs',
                              coverUrl: pl.coverUrl,
                              songs: songs,
                            ),
                          ),
                        );
                      }
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
                          child: Container(
                            width: 125,
                            height: 125,
                            color: AppColors.surface,
                            child: (pl.coverUrl != null && pl.coverUrl!.isNotEmpty)
                                ? AppImage(
                                    url: pl.coverUrl!,
                                    fit: BoxFit.cover,
                                  )
                                : const Icon(Icons.music_note, size: 40, color: AppColors.accent),
                          ),
                        ),
                        const SizedBox(height: Dimensions.space8),
                        Text(
                          pl.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          '${pl.songCount} songs',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  // -------------------------------------------------------------
  // SECTION D: POPULAR ARTISTS
  // -------------------------------------------------------------
  Widget _buildPopularArtistsSection(BuildContext context) {
    const artists = HomeContentService.popularArtists;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          context,
          title: 'Popular artists',
          icon: Icons.person_outline,
        ),
        SizedBox(
          height: 130,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: Dimensions.space16),
            itemCount: artists.length,
            itemBuilder: (context, index) {
              final artist = artists[index];
              return Container(
                width: 88,
                margin: const EdgeInsets.only(right: Dimensions.space16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(44),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ArtistDetailView(
                          artistName: artist.name,
                          artistAvatarUrl: artist.avatarUrl,
                        ),
                      ),
                    );
                  },
                  child: Column(
                    children: [
                      Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.cyanAccent.withOpacity(0.4), width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.cyanAccent.withOpacity(0.12),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: AppImage(
                            url: artist.avatarUrl,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(height: Dimensions.space8),
                      Text(
                        artist.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------
  // SECTION E: TRENDING TAMIL
  // -------------------------------------------------------------
  Widget _buildTrendingTamilSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          context,
          title: 'Trending Tamil',
          icon: Icons.local_fire_department,
          actionText: _trendingTamil.isNotEmpty ? 'See all' : null,
          onActionTap: _trendingTamil.isNotEmpty
              ? () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PlaylistDetailView(
                        title: 'Trending Tamil',
                        subtitle: 'Hot legal tracks & trending hits',
                        songs: _trendingTamil,
                      ),
                    ),
                  );
                }
              : null,
        ),
        if (_isLoadingTrending)
          _buildSectionSkeleton(height: 120)
        else if (_trendingTamil.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Dimensions.space16, vertical: 8),
            child: Container(
              padding: const EdgeInsets.all(Dimensions.space16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
                border: Border.all(color: AppColors.elevated),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: AppColors.accent, size: 24),
                  SizedBox(width: Dimensions.space12),
                  Expanded(
                    child: Text(
                      'No online Tamil results found at this time. Only songs from legal, licensed, or free-to-use sources appear.',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          )
        else ...[
          // Play All & Shuffle Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Dimensions.space16, vertical: 4),
            child: Row(
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    if (_trendingTamil.isNotEmpty) {
                      ref.read(audioPlayerControllerProvider.notifier).playSong(
                            _trendingTamil.first,
                            queue: _trendingTamil,
                            index: 0,
                          );
                    }
                  },
                  icon: const Icon(Icons.play_arrow, color: Colors.black, size: 18),
                  label: const Text('Play all', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    minimumSize: const Size(90, 36),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  ),
                ),
                const SizedBox(width: Dimensions.space12),
                OutlinedButton.icon(
                  onPressed: () {
                    if (_trendingTamil.isNotEmpty) {
                      final shuffled = List<SongModel>.from(_trendingTamil)..shuffle();
                      ref.read(audioPlayerControllerProvider.notifier).playSong(
                            shuffled.first,
                            queue: shuffled,
                            index: 0,
                          );
                    }
                  },
                  icon: const Icon(Icons.shuffle, color: AppColors.accent, size: 16),
                  label: const Text('Shuffle', style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.accent),
                    minimumSize: const Size(90, 36),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: Dimensions.space8),
          // Top 6 trending tracks rendered as SongTiles
          ..._trendingTamil.take(6).map((song) {
            final playerState = ref.watch(audioPlayerControllerProvider);
            return SongTile(
              song: song,
              isPlaying: playerState.currentSong?.id == song.id,
              onTap: () {
                ref.read(audioPlayerControllerProvider.notifier).playSong(
                      song,
                      queue: _trendingTamil,
                      index: _trendingTamil.indexOf(song),
                    );
              },
            );
          }),
        ],
      ],
    );
  }

  Widget _buildSectionSkeleton({required double height}) {
    return Container(
      height: height,
      margin: const EdgeInsets.symmetric(horizontal: Dimensions.space16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
      ),
      child: const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
        ),
      ),
    );
  }
}
