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
import '../shared_widgets/artist_avatar.dart';
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
  bool _isRefreshing = false;
  DateTime? _lastUpdated;
  DateTime? _lastRefreshTap;

  @override
  void initState() {
    super.initState();
    _loadTrendingTamil();
  }

  Future<void> _loadTrendingTamil({bool forceNextBatch = false}) async {
    try {
      final songs = await HomeContentService.getTrendingTamilSongs(
        limit: 20,
        forceNextBatch: forceNextBatch,
      );
      if (mounted) {
        setState(() {
          _trendingTamil = songs;
          _isLoadingTrending = false;
          _isRefreshing = false;
          _lastUpdated = DateTime.now();
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingTrending = false;
          _isRefreshing = false;
        });
      }
    }
  }

  void _handleRefreshTap() {
    final now = DateTime.now();
    if (_lastRefreshTap != null &&
        now.difference(_lastRefreshTap!).inMilliseconds < 2000) {
      return; // 2s anti-spam lock
    }
    _lastRefreshTap = now;
    setState(() {
      _isRefreshing = true;
    });
    _loadTrendingTamil(forceNextBatch: true);
  }

  String _getUpdatedTimeText() {
    if (_lastUpdated == null) return 'Updated just now';
    final diff = DateTime.now().difference(_lastUpdated!);
    if (diff.inSeconds < 60) return 'Updated just now';
    if (diff.inMinutes < 60) return 'Updated ${diff.inMinutes}m ago';
    if (diff.inHours < 24) return 'Updated ${diff.inHours}h ago';
    return 'Updated ${diff.inDays}d ago';
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
                              color: AppColors.secondaryAccent,
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
          height: 195,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: Dimensions.space16),
            itemCount: mixes.length,
            itemBuilder: (context, index) {
              final mix = mixes[index];
              final title = mix['title'] as String;
              final subtitle = mix['subtitle'] as String;
              final color = (mix['color'] as Color?) ?? const Color(0xFF1E90FF);
              final songs = mix['songs'] as List<SongModel>;

              // Extract 2 or 3 distinct artist names for caption
              final artistNames = <String>[];
              for (final s in songs) {
                final a = s.artist.split('/').first.trim();
                if (a.isNotEmpty && !artistNames.contains(a)) {
                  artistNames.add(a);
                  if (artistNames.length >= 3) break;
                }
              }
              final caption = artistNames.isNotEmpty
                  ? artistNames.join(', ')
                  : subtitle;

              final topSong = songs.isNotEmpty ? songs.first : null;

              return Container(
                width: 148,
                margin: const EdgeInsets.only(right: 12),
                child: Material(
                  color: color,
                  borderRadius: BorderRadius.circular(12),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () {
                      if (songs.isEmpty) return;
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PlaylistDetailView(
                            title: title,
                            subtitle: subtitle,
                            songs: songs,
                            themeColor: color,
                          ),
                        ),
                      );
                    },
                    splashColor: Colors.black26,
                    highlightColor: Colors.black12,
                    child: Stack(
                      children: [
                        // Single large rotated cover at bottom right at full brightness (no dark overlay, no glow)
                        if (topSong != null && topSong.coverUrl.isNotEmpty)
                          Positioned(
                            right: -10,
                            bottom: -10,
                            child: Transform.rotate(
                              angle: 0.26, // ~15 degrees
                              child: Container(
                                width: 72,
                                height: 72,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Colors.black26,
                                      blurRadius: 4,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: Image.network(
                                  topSong.coverUrl,
                                  fit: BoxFit.cover,
                                  frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                                    if (wasSynchronouslyLoaded || frame != null) {
                                      return child;
                                    }
                                    return Container(color: color);
                                  },
                                  errorBuilder: (_, __, ___) => Container(
                                    color: Colors.white.withOpacity(0.2),
                                    child: const Icon(Icons.music_note, color: Colors.white, size: 32),
                                  ),
                                ),
                              ),
                            ),
                          )
                        else
                          Positioned(
                            right: -8,
                            bottom: -8,
                            child: Transform.rotate(
                              angle: 0.26,
                              child: Container(
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.18),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.album_rounded, color: Colors.white, size: 36),
                              ),
                            ),
                          ),

                        // Card Text Content (top-left, max 2 lines title, artist caption)
                        Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  height: 1.2,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                caption,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.92),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  height: 1.2,
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.25),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '${songs.length} tracks',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
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
                      ArtistAvatar(
                        artistName: artist.name,
                        avatarUrl: artist.avatarUrl,
                        size: 76,
                        borderWidth: 1.5,
                        borderColor: AppColors.elevated,
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
        // Trending Header with title, updated time, refresh button, and 'See all'
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Dimensions.space16,
            Dimensions.space12,
            Dimensions.space16,
            Dimensions.space12,
          ),
          child: Row(
            children: [
              const Icon(Icons.local_fire_department, size: 20, color: AppColors.accent),
              const SizedBox(width: Dimensions.space8),
              Text(
                'Trending Tamil',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.2,
                      color: AppColors.textPrimary,
                    ),
              ),
              const SizedBox(width: Dimensions.space8),
              Text(
                '• ${_getUpdatedTimeText()}',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                ),
              ),
              const Spacer(),
              // Circular Refresh Button with anti-spam lock & loading spinner
              IconButton(
                iconSize: 20,
                splashRadius: 20,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                tooltip: 'Refresh Trending Batch',
                onPressed: _isRefreshing ? null : _handleRefreshTap,
                icon: _isRefreshing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.accent,
                        ),
                      )
                    : const Icon(Icons.refresh, color: AppColors.accent),
              ),
              if (_trendingTamil.isNotEmpty) ...[
                const SizedBox(width: 4),
                InkWell(
                  borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
                  onTap: () async {
                    final poolState = await HomeContentService.getTrendingTamilPool(localCatalog: const []);
                    final fullRanked = poolState.fullRankedPool.isNotEmpty
                        ? poolState.fullRankedPool.take(100).toList()
                        : _trendingTamil;
                    if (context.mounted) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PlaylistDetailView(
                            title: 'Trending Tamil',
                            subtitle: 'Top ranked legal tracks & momentum hits (${fullRanked.length} songs)',
                            songs: fullRanked,
                          ),
                        ),
                      );
                    }
                  },
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    child: Text(
                      'See all',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.accent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (_isLoadingTrending && _trendingTamil.isEmpty)
          _buildSectionSkeleton(height: 140)
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
                  Icon(Icons.wifi_off_rounded, color: AppColors.accent, size: 24),
                  SizedBox(width: Dimensions.space12),
                  Expanded(
                    child: Text(
                      'You are offline or online sources are temporarily unreachable. You can still play all cached playlists and downloaded songs in your Library.',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.3),
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
                  icon: const Icon(Icons.play_arrow, color: Colors.white, size: 18),
                  label: const Text('Play all', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    minimumSize: const Size(90, 36),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: Dimensions.space8),
          // Top 20 ranked trending tracks rendered as SongTiles with rank numbers
          ...List.generate(_trendingTamil.length, (index) {
            final song = _trendingTamil[index];
            final playerState = ref.watch(audioPlayerControllerProvider);
            return SongTile(
              song: song,
              rankNumber: index + 1,
              isPlaying: playerState.currentSong?.id == song.id,
              onTap: () {
                ref.read(audioPlayerControllerProvider.notifier).playSong(
                      song,
                      queue: _trendingTamil,
                      index: index,
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
