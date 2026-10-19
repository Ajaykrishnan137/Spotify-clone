import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/song_model.dart';
import '../../controllers/audio_player_controller.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/dimensions.dart';
import '../shared_widgets/song_tile.dart';
import '../../core/services/cloud_catalog_service.dart';
import '../../core/services/legal_search_engine_service.dart';
import '../playlist/playlist_detail_view.dart';

class SearchView extends ConsumerStatefulWidget {
  const SearchView({super.key});

  @override
  ConsumerState<SearchView> createState() => _SearchViewState();
}

class _SearchViewState extends ConsumerState<SearchView> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  bool _isLoading = false;

  List<SongModel> _searchResult = [];
  String _selectedSourceFilter = 'All';
  String _selectedQualityFilter = 'All';

  final List<String> _recentSearches = ['With Love', 'Pradeep Kumar', 'Sid Sriram', 'Tamil Melody', 'Jamendo Acoustic'];

  static const List<Map<String, dynamic>> _browseGenres = [
    {'title': 'Pop & Melody', 'color': Color(0xFFE91E63), 'icon': Icons.music_note},
    {'title': 'Tamil Hits', 'color': Color(0xFFFF5722), 'icon': Icons.audiotrack},
    {'title': 'Malayalam Hits', 'color': Color(0xFF00B0FF), 'icon': Icons.waves},
    {'title': 'Acoustic / Indie', 'color': Color(0xFF8E24AA), 'icon': Icons.mic},
    {'title': 'Chill & Focus', 'color': Color(0xFF00897B), 'icon': Icons.spa},
    {'title': 'Dance / Party', 'color': Color(0xFFFF8F00), 'icon': Icons.celebration},
  ];

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _performSearch(query);
    });
  }

  Future<void> _performSearch(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) {
      setState(() {
        _searchResult = [];
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final catalog = await ref.read(cloudCatalogServiceProvider).getCatalog();
    final result = await LegalSearchEngineService.searchAllSources(
      query: cleanQuery,
      localCatalog: catalog,
      sourceFilter: _selectedSourceFilter != 'All' ? _selectedSourceFilter : null,
      qualityFilter: _selectedQualityFilter != 'All' ? _selectedQualityFilter : null,
    );

    if (mounted) {
      setState(() {
        _searchResult = result;
        _isLoading = false;
      });
    }
  }

  void _onSearchSubmitted(String query) {
    final clean = query.trim();
    if (clean.isNotEmpty && !_recentSearches.contains(clean)) {
      setState(() {
        _recentSearches.insert(0, clean);
        if (_recentSearches.length > 8) _recentSearches.removeLast();
      });
    }
  }

  Widget _buildSingleSongsList(AudioPlayerController playerController, PlayerStateData playerState) {
    if (_searchResult.isEmpty && !_isLoading) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.search_off_rounded, size: 54, color: AppColors.textSecondary),
              const SizedBox(height: 12),
              const Text(
                'No songs found, try another spelling',
                style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              const Text(
                'SkyTune searches across all legal sources (Local files, Jamendo, Free Music Archive, Internet Archive).\nTry checking for typos or searching by artist or movie.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                children: ['Acoustic', 'Chill', 'Melody', 'Safar', 'Banger'].map((hint) {
                  return ActionChip(
                    backgroundColor: AppColors.card,
                    label: Text('Try "$hint"', style: const TextStyle(color: AppColors.cyanAccent, fontSize: 12)),
                    onPressed: () {
                      _searchController.text = hint;
                      _performSearch(hint);
                    },
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: _searchResult.length,
      padding: const EdgeInsets.only(bottom: Dimensions.miniPlayerHeight + Dimensions.space64),
      itemBuilder: (context, index) {
        final song = _searchResult[index];
        return SongTile(
          song: song,
          isPlaying: playerState.currentSong?.id == song.id,
          onTap: () {
            _onSearchSubmitted(_searchController.text);
            playerController.playSong(song, queue: _searchResult, index: index);
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final playerController = ref.read(audioPlayerControllerProvider.notifier);
    final playerState = ref.watch(audioPlayerControllerProvider);
    final allSongsAsync = ref.watch(allSongsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Fixed Top Header: Search Title & Input
            Container(
              color: AppColors.background,
              padding: const EdgeInsets.fromLTRB(Dimensions.space16, Dimensions.space12, Dimensions.space16, Dimensions.space8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Search',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Search Input with debounced search-as-you-type
                  TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    onSubmitted: _onSearchSubmitted,
                    style: const TextStyle(color: Colors.black),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      hintText: 'Search songs, albums, artists, or movies...',
                      hintStyle: const TextStyle(color: Color(0xFF757575), fontSize: 14),
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
                ],
              ),
            ),

            // Filter Chips (Legal Sources & Quality)
            if (_searchController.text.isNotEmpty)
              Container(
                color: AppColors.background,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: Dimensions.space16, vertical: 4),
                  child: Row(
                    children: [
                      // Source filter dropdown
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
                        ),
                        child: DropdownButton<String>(
                          value: _selectedSourceFilter,
                          underline: const SizedBox.shrink(),
                          dropdownColor: AppColors.card,
                          style: const TextStyle(color: AppColors.textPrimary, fontSize: 12),
                          icon: const Icon(Icons.filter_list, size: 16, color: AppColors.cyanAccent),
                          items: ['All', 'Local', 'Jamendo', 'Archive', 'Release'].map((src) {
                            return DropdownMenuItem(value: src, child: Text('Source: $src'));
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _selectedSourceFilter = val);
                              _performSearch(_searchController.text);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Quality filter dropdown
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
                        ),
                        child: DropdownButton<String>(
                          value: _selectedQualityFilter,
                          underline: const SizedBox.shrink(),
                          dropdownColor: AppColors.card,
                          style: const TextStyle(color: AppColors.textPrimary, fontSize: 12),
                          icon: const Icon(Icons.high_quality, size: 16, color: AppColors.cyanAccent),
                          items: ['All', 'High (320kbps)', 'Lossless'].map((q) {
                            return DropdownMenuItem(value: q, child: Text('Quality: $q'));
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _selectedQualityFilter = val);
                              _performSearch(_searchController.text);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Live Results Count Header (Requirement 2: Total count live updating)
            if (_searchController.text.isNotEmpty)
              Container(
                color: AppColors.background,
                padding: const EdgeInsets.symmetric(horizontal: Dimensions.space16, vertical: 8),
                child: Row(
                  children: [
                    Text(
                      '${_searchResult.length} ${_searchResult.length == 1 ? 'song found' : 'songs found'}',
                      style: const TextStyle(
                        color: AppColors.cyanAccent,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const Spacer(),
                    if (_isLoading)
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.cyanAccent),
                      ),
                  ],
                ),
              ),

            if (_isLoading && _searchResult.isEmpty)
              const LinearProgressIndicator(
                backgroundColor: AppColors.surface,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.cyanAccent),
                minHeight: 2.5,
              ),

            // Scrollable Content
            Expanded(
              child: _searchController.text.isEmpty
                  ? ListView(
                      key: const ValueKey('browse_and_recent'),
                      padding: const EdgeInsets.only(
                        left: Dimensions.space16,
                        right: Dimensions.space16,
                        bottom: Dimensions.miniPlayerHeight + Dimensions.space64,
                      ),
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
                          'Browse legal catalogs',
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
                                      subtitle: 'Legal Music Collection',
                                      songs: filtered.isNotEmpty ? filtered : allSongs.take(15).toList(),
                                    ),
                                  ),
                                );
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  color: item['color'] as Color,
                                  borderRadius: BorderRadius.circular(Dimensions.radiusMedium),
                                  boxShadow: [
                                    BoxShadow(
                                      color: (item['color'] as Color).withOpacity(0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
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
                      ],
                    )
                  : _buildSingleSongsList(playerController, playerState),
            ),
          ],
        ),
      ),
    );
  }
}
