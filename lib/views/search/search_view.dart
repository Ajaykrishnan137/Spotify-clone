import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/song_model.dart';
import '../../controllers/audio_player_controller.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/dimensions.dart';
import '../shared_widgets/song_tile.dart';
import '../shared_widgets/empty_view.dart';
import '../shared_widgets/spotify_logo.dart';
import '../../core/services/cloud_catalog_service.dart';
import '../playlist/playlist_detail_view.dart';

class SearchView extends ConsumerStatefulWidget {
  const SearchView({super.key});

  @override
  ConsumerState<SearchView> createState() => _SearchViewState();
}

class _SearchViewState extends ConsumerState<SearchView> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  List<SongModel> _results = [];
  bool _isLoading = false;
  final List<String> _recentSearches = ['With Love', 'Pradeep Kumar', 'Sid Sriram', 'Tamil Melody'];

  static const List<Map<String, dynamic>> _browseGenres = [
    {'title': 'Pop & Melody', 'color': Color(0xFFE91E63), 'icon': Icons.music_note},
    {'title': 'Tamil Hits', 'color': Color(0xFFFF5722), 'icon': Icons.audiotrack},
    {'title': 'Malayalam Hits', 'color': Color(0xFF00B0FF), 'icon': Icons.waves},
    {'title': 'Acoustic / Indie', 'color': Color(0xFF8E24AA), 'icon': Icons.mic},
    {'title': 'Chill & Focus', 'color': Color(0xFF00897B), 'icon': Icons.spa},
    {'title': 'Dance / Party', 'color': Color(0xFFFF8F00), 'icon': Icons.celebration},
  ];

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _performSearch(query);
    });
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _results = [];
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final searchService = ref.read(cloudCatalogServiceProvider);
    final results = await searchService.searchSongs(query);

    if (mounted) {
      setState(() {
        _isLoading = false;
        _results = results;
      });
    }
  }

  void _onSearchSubmitted(String query) {
    if (query.trim().isNotEmpty && !_recentSearches.contains(query.trim())) {
      setState(() {
        _recentSearches.insert(0, query.trim());
        if (_recentSearches.length > 8) _recentSearches.removeLast();
      });
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final playerState = ref.watch(audioPlayerControllerProvider);
    final allSongsAsync = ref.watch(allSongsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(Dimensions.space16, Dimensions.space16, Dimensions.space16, Dimensions.space8),
              child: Text(
                'Search',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            // Search Input
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Dimensions.space16, vertical: Dimensions.space8),
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                onSubmitted: _onSearchSubmitted,
                style: const TextStyle(color: Colors.black),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  hintText: 'What do you want to listen to?',
                  hintStyle: const TextStyle(color: Color(0xFF757575), fontSize: 15),
                  prefixIcon: const Icon(Icons.search, color: Colors.black),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Colors.black),
                          onPressed: () {
                            _searchController.clear();
                            _onSearchChanged('');
                          },
                        )
                      : null,
                  contentPadding: const EdgeInsets.symmetric(vertical: Dimensions.space12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            if (_isLoading)
              Consumer(
                builder: (_, ref, __) {
                  final themeColor = ref.watch(nowPlayingThemeColorProvider);
                  return LinearProgressIndicator(
                    backgroundColor: AppColors.surface,
                    valueColor: AlwaysStoppedAnimation<Color>(themeColor),
                    minHeight: 2.5,
                  );
                },
              ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: _searchController.text.isEmpty
                    ? ListView(
                        key: const ValueKey('browse_and_recent'),
                        padding: const EdgeInsets.symmetric(horizontal: Dimensions.space16),
                        children: [
                          // Recent Searches
                          if (_recentSearches.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            const Text(
                              'Recent searches',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _recentSearches.map((term) {
                                return ActionChip(
                                  backgroundColor: AppColors.card,
                                  label: Text(term, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13)),
                                  avatar: const Icon(Icons.history, size: 16, color: AppColors.textSecondary),
                                  onPressed: () {
                                    _searchController.text = term;
                                    _performSearch(term);
                                  },
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 24),
                          ],

                          // Genre / Mood Browse Tiles
                          const Text(
                            'Browse all',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _browseGenres.length,
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: 1.6,
                            ),
                            itemBuilder: (context, index) {
                              final item = _browseGenres[index];
                              return InkWell(
                                borderRadius: BorderRadius.circular(Dimensions.radiusMedium),
                                onTap: () {
                                  final title = item['title'] as String;
                                  final allSongs = allSongsAsync.value ?? [];
                                  final filtered = allSongs.where((s) {
                                    final g = s.genre.toLowerCase();
                                    final t = title.toLowerCase();
                                    return g.contains(t.split(' ').first) || t.contains(g);
                                  }).toList();

                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => PlaylistDetailView(
                                        title: title,
                                        subtitle: 'Browse Category',
                                        songs: filtered.isNotEmpty ? filtered : allSongs.take(15).toList(),
                                      ),
                                    ),
                                  );
                                },
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: item['color'] as Color,
                                    borderRadius: BorderRadius.circular(Dimensions.radiusMedium),
                                  ),
                                  padding: const EdgeInsets.all(Dimensions.space12),
                                  child: Stack(
                                    children: [
                                      Text(
                                        item['title'] as String,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Positioned(
                                        bottom: 0,
                                        right: 0,
                                        child: Transform.rotate(
                                          angle: 0.3,
                                          child: Icon(
                                            item['icon'] as IconData,
                                            size: 40,
                                            color: Colors.white.withOpacity(0.4),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: Dimensions.space64),
                        ],
                      )
                    : _results.isEmpty && !_isLoading
                        ? const EmptyView(
                            key: ValueKey('no_results'),
                            title: 'No results found',
                            subtitle: 'Please check your spelling or try another keyword.',
                            icon: Icons.music_off,
                          )
                        : ListView.builder(
                            key: const ValueKey('results_list'),
                            itemCount: _results.length,
                            itemBuilder: (context, index) {
                              final song = _results[index];
                              return SongTile(
                                song: song,
                                isPlaying: playerState.currentSong?.id == song.id,
                                onTap: () {
                                  _onSearchSubmitted(_searchController.text);
                                  ref.read(audioPlayerControllerProvider.notifier).playSong(
                                        song,
                                        queue: _results,
                                        index: index,
                                      );
                                },
                              );
                            },
                          ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
