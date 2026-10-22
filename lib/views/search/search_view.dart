import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/song_model.dart';
import '../../controllers/audio_player_controller.dart';
import '../../controllers/playlist_controller.dart';
import '../../controllers/download_controller.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/dimensions.dart';
import '../shared_widgets/song_tile.dart';
import '../../core/services/cloud_catalog_service.dart';
import '../../core/services/legal_search_engine_service.dart';
import '../../core/services/query_intent_engine.dart';
import '../../core/services/fuzzy_matcher.dart';
import '../playlist/playlist_detail_view.dart';
import 'generated_playlist_card.dart';

class SearchView extends ConsumerStatefulWidget {
  const SearchView({super.key});

  @override
  ConsumerState<SearchView> createState() => _SearchViewState();
}

class _SearchViewState extends ConsumerState<SearchView> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  bool _isLoading = false;
  int _searchRequestId = 0;

  List<SongModel> _searchResult = [];
  String _selectedSourceFilter = 'All';
  String _selectedQualityFilter = 'All';
  QueryIntentResult? _currentIntent;
  String? _spellingSuggestion;
  List<String> _autocompleteSuggestions = [];

  final List<String> _recentSearches = [
    'Tamil new songs',
    'Travelling songs',
    'Sleep songs',
    'With Love',
    'Pradeep Kumar',
    'Sid Sriram',
  ];

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

    // Fast autocomplete updates
    _updateAutocomplete(query);

    _debounce = Timer(const Duration(milliseconds: 300), () {
      _performSearch(query);
    });
  }

  void _updateAutocomplete(String query) {
    final clean = query.trim().toLowerCase();
    if (clean.length < 2) {
      if (_autocompleteSuggestions.isNotEmpty) {
        setState(() => _autocompleteSuggestions = []);
      }
      return;
    }

    const standardSuggestions = [
      'Tamil new songs',
      'Tamil trending songs',
      'Travelling songs',
      'Sleep songs',
      'Workout songs',
      'Romantic songs',
      'Chill vibes',
      '90s tamil hits',
      'Sid Sriram hits',
      'Pradeep Kumar melody',
      'Harris Jayaraj hits',
      'With Love songs',
      'Lana Del Rey acoustic',
      'Acoustic guitar melodies',
      'Focus study beats',
    ];

    final matches = standardSuggestions.where((s) {
      return FuzzyMatcher.normalize(s).contains(FuzzyMatcher.normalize(clean));
    }).take(4).toList();

    setState(() {
      _autocompleteSuggestions = matches;
    });
  }

  Future<void> _performSearch(String query) async {
    final cleanQuery = query.trim();
    final requestId = ++_searchRequestId;

    if (cleanQuery.isEmpty) {
      setState(() {
        _searchResult = [];
        _isLoading = false;
        _currentIntent = null;
        _spellingSuggestion = null;
      });
      return;
    }

    // Intent detection
    final intent = QueryIntentEngine.analyzeQuery(cleanQuery);

    setState(() {
      _isLoading = true;
      _currentIntent = intent;
    });

    final catalog = await ref.read(cloudCatalogServiceProvider).getCatalog();

    // Check spelling suggestions from catalog titles and artists
    final candidatePool = catalog.map((s) => s.title).followedBy(catalog.map((s) => s.artist));
    final suggestion = FuzzyMatcher.findSpellingSuggestion(cleanQuery, candidatePool);

    final result = await LegalSearchEngineService.searchAllSources(
      query: cleanQuery,
      localCatalog: catalog,
      sourceFilter: _selectedSourceFilter != 'All' ? _selectedSourceFilter : null,
      qualityFilter: _selectedQualityFilter != 'All' ? _selectedQualityFilter : null,
    );

    // Cancel outdated requests so results never flicker or show stale data
    if (!mounted || requestId != _searchRequestId) return;

    setState(() {
      _searchResult = result;
      _isLoading = false;
      _spellingSuggestion = suggestion;
    });
  }

  void _onSearchSubmitted(String query) {
    final clean = query.trim();
    if (clean.isNotEmpty) {
      setState(() {
        _recentSearches.remove(clean);
        _recentSearches.insert(0, clean);
        if (_recentSearches.length > 8) _recentSearches.removeLast();
        _autocompleteSuggestions = [];
      });
    }
  }

  void _saveGeneratedPlaylist() async {
    if (_searchResult.isEmpty || _currentIntent == null) return;
    final playlistTitle = _currentIntent!.title;
    final playlistController = ref.read(localPlaylistControllerProvider.notifier);

    await playlistController.createPlaylist(
      playlistTitle,
      initialSongs: _searchResult,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Saved "$playlistTitle" to your library!'),
          backgroundColor: AppColors.cyanAccent,
          action: SnackBarAction(
            label: 'View',
            textColor: Colors.black,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PlaylistDetailView(
                    title: playlistTitle,
                    subtitle: 'Saved Auto-Generated Playlist',
                    songs: _searchResult,
                  ),
                ),
              );
            },
          ),
        ),
      );
    }
  }

  void _downloadAllSongs() {
    if (_searchResult.isEmpty) return;
    final downloadNotifier = ref.read(downloadControllerProvider.notifier);
    for (final song in _searchResult) {
      downloadNotifier.startDownload(song);
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Downloading ${_searchResult.length} legal tracks for offline play...'),
        backgroundColor: AppColors.cyanAccent,
      ),
    );
  }

  Widget _buildSearchResults(AudioPlayerController playerController, PlayerStateData playerState) {
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
                'SkyTune searches across all legal sources (Local files, Jamendo, Free Music Archive, Internet Archive).\nTry checking for typos or searching by mood, artist, or movie.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              if (_spellingSuggestion != null) ...[
                const SizedBox(height: 14),
                ActionChip(
                  backgroundColor: AppColors.card,
                  avatar: const Icon(Icons.auto_fix_high, size: 16, color: AppColors.cyanAccent),
                  label: Text('Did you mean "${_spellingSuggestion}"?',
                      style: const TextStyle(color: AppColors.cyanAccent, fontSize: 13, fontWeight: FontWeight.bold)),
                  onPressed: () {
                    _searchController.text = _spellingSuggestion!;
                    _performSearch(_spellingSuggestion!);
                  },
                ),
              ],
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                children: ['Travelling songs', 'Tamil new songs', 'Sleep songs', 'With Love', 'Chill'].map((hint) {
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

    final bool isPlaylistQuery = _currentIntent != null && _currentIntent!.type == QueryIntentType.playlistType;
    final relatedList = _currentIntent?.relatedPlaylists ?? [];

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: _searchResult.length + (isPlaylistQuery ? 1 : 0) + (isPlaylistQuery && relatedList.isNotEmpty ? 1 : 0),
      padding: const EdgeInsets.only(bottom: Dimensions.miniPlayerHeight + Dimensions.space64),
      itemBuilder: (context, index) {
        // 1. Auto-generated playlist card at the very top for playlist-type queries
        if (isPlaylistQuery && index == 0) {
          return GeneratedPlaylistCard(
            title: _currentIntent!.title,
            songs: _searchResult,
            onPlay: () {
              _onSearchSubmitted(_searchController.text);
              // Tapping Play sets whole list as queue with Repeat All
              playerController.setLoopMode(PlayerLoopMode.all);
              playerController.playSong(_searchResult.first, queue: _searchResult, index: 0);
            },
            onShuffle: () {
              _onSearchSubmitted(_searchController.text);
              final shuffled = List<SongModel>.from(_searchResult)..shuffle();
              playerController.setLoopMode(PlayerLoopMode.all);
              playerController.playSong(shuffled.first, queue: shuffled, index: 0);
            },
            onSave: _saveGeneratedPlaylist,
            onDownloadAll: _downloadAllSongs,
          );
        }

        // 2. Optional compact horizontal row of "Related playlists" under the main card
        if (isPlaylistQuery && relatedList.isNotEmpty && index == 1) {
          return Container(
            height: 38,
            margin: const EdgeInsets.only(bottom: 12, left: Dimensions.space16, right: Dimensions.space16),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: relatedList.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (ctx, rIdx) {
                final relTitle = relatedList[rIdx];
                return ActionChip(
                  backgroundColor: AppColors.card,
                  avatar: const Icon(Icons.playlist_play, size: 16, color: AppColors.cyanAccent),
                  label: Text(relTitle, style: const TextStyle(color: AppColors.textPrimary, fontSize: 12)),
                  onPressed: () {
                    _searchController.text = relTitle;
                    _performSearch(relTitle);
                  },
                );
              },
            ),
          );
        }

        // 3. Continuous list of matching songs
        final songIndex = isPlaylistQuery ? (relatedList.isNotEmpty ? index - 2 : index - 1) : index;
        final song = _searchResult[songIndex];

        return SongTile(
          song: song,
          isPlaying: playerState.currentSong?.id == song.id,
          showMetadataDetails: true,
          onTap: () {
            _onSearchSubmitted(_searchController.text);
            playerController.playSong(song, queue: _searchResult, index: songIndex);
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
                  // Search Input with 300ms debounced search-as-you-type
                  TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    onSubmitted: (val) {
                      _onSearchSubmitted(val);
                      _performSearch(val);
                    },
                    style: const TextStyle(color: Colors.black),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      hintText: 'Search songs, moods, travel, sleep, artists...',
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

            // Autocomplete suggestions popup bar
            if (_autocompleteSuggestions.isNotEmpty && _searchController.text.isNotEmpty)
              Container(
                color: AppColors.surface,
                padding: const EdgeInsets.symmetric(horizontal: Dimensions.space16, vertical: 6),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _autocompleteSuggestions.map((sug) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: InkWell(
                          onTap: () {
                            _searchController.text = sug;
                            _performSearch(sug);
                            _onSearchSubmitted(sug);
                          },
                          child: Chip(
                            backgroundColor: AppColors.card,
                            label: Text(sug, style: const TextStyle(color: AppColors.cyanAccent, fontSize: 12)),
                            avatar: const Icon(Icons.search, size: 14, color: AppColors.cyanAccent),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
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

            // Live Results Count Header & "Did you mean..." banner
            if (_searchController.text.isNotEmpty)
              Container(
                color: AppColors.background,
                padding: const EdgeInsets.symmetric(horizontal: Dimensions.space16, vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          _searchResult.isEmpty && !_isLoading
                              ? '0 songs found'
                              : (_searchResult.length < 20 && _currentIntent?.type == QueryIntentType.playlistType && !_isLoading)
                                  ? 'Only ${_searchResult.length} free songs found for this mood'
                                  : '${_searchResult.length} ${_searchResult.length == 1 ? 'song found' : 'songs found'}',
                          style: TextStyle(
                            color: (_searchResult.length < 20 && _currentIntent?.type == QueryIntentType.playlistType && !_isLoading)
                                ? const Color(0xFFFFC107)
                                : AppColors.cyanAccent,
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
                    if (_spellingSuggestion != null && _searchResult.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      InkWell(
                        onTap: () {
                          _searchController.text = _spellingSuggestion!;
                          _performSearch(_spellingSuggestion!);
                        },
                        child: Text(
                          'Did you mean: "${_spellingSuggestion}"?',
                          style: const TextStyle(
                            color: Color(0xFF38D6FF),
                            fontSize: 12.5,
                            fontStyle: FontStyle.italic,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
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
                                _searchController.text = title;
                                _performSearch(title);
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
                  : _buildSearchResults(playerController, playerState),
            ),
          ],
        ),
      ),
    );
  }
}
