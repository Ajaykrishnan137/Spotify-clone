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
import '../../core/services/local_search_index.dart';
import '../playlist/playlist_detail_view.dart';
import 'generated_playlist_card.dart';
import 'artist_header_card.dart';

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
  String _artistSortOrder = 'Popularity'; // 'Popularity' or 'Newest first'
  QueryIntentResult? _currentIntent;
  String? _spellingSuggestion;
  List<String> _autocompleteSuggestions = [];

  final List<String> _recentSearches = [
    'Harris Jayaraj',
    'Tamil new songs',
    'Travelling songs',
    'Sleep songs',
    'Pradeep Kumar',
    'Sid Sriram',
  ];

  static const List<Map<String, dynamic>> _browseGenres = [
    {'title': 'Tamil', 'color': Color(0xFFE8115B), 'icon': Icons.audiotrack},
    {'title': 'New Releases', 'color': Color(0xFF1E90FF), 'icon': Icons.fiber_new},
    {'title': 'Trending', 'color': Color(0xFFF59B23), 'icon': Icons.trending_up},
    {'title': 'Travel', 'color': Color(0xFF2ECC71), 'icon': Icons.flight_takeoff},
    {'title': 'Sleep', 'color': Color(0xFF8D67AB), 'icon': Icons.nightlight_round},
    {'title': 'Workout', 'color': Color(0xFFE13300), 'icon': Icons.fitness_center},
    {'title': 'Romantic', 'color': Color(0xFF00A3A3), 'icon': Icons.favorite},
    {'title': 'Chill', 'color': Color(0xFFF037A5), 'icon': Icons.spa},
    {'title': 'Party', 'color': Color(0xFF509BF5), 'icon': Icons.celebration},
    {'title': 'Focus', 'color': Color(0xFFBA5D07), 'icon': Icons.psychology},
    {'title': 'Devotional', 'color': Color(0xFF148A08), 'icon': Icons.auto_awesome},
    {'title': 'Melody', 'color': Color(0xFF477D95), 'icon': Icons.music_note},
    {'title': '90s Hits', 'color': Color(0xFFE8115B), 'icon': Icons.radio},
    {'title': 'Instrumental', 'color': Color(0xFF1E90FF), 'icon': Icons.piano},
  ];

  StreamSubscription<SearchStreamBatch>? _searchSubscription;

  @override
  void initState() {
    super.initState();
    // Warm up local search index and cloud catalog in background
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final catalog = await ref.read(cloudCatalogServiceProvider).getCatalog();
      LocalSearchIndex.buildIndex(catalog);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchSubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    _updateAutocomplete(query);

    // 250ms debounce as specified in requirements
    _debounce = Timer(const Duration(milliseconds: 250), () {
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
      'Harris Jayaraj',
      'Haris Jeyaraj',
      'Pradeep Kumar',
      'Sid Sriram',
      'Sai Abhyankkar',
      'Anirudh Ravichander',
      'A. R. Rahman',
      'Tamil new songs',
      'Tamil trending songs',
      'Travelling songs',
      'Sleep songs',
      'Workout songs',
      'Romantic songs',
      'Chill vibes',
      '90s tamil hits',
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

    // Cancel any ongoing active search stream
    await _searchSubscription?.cancel();
    _searchSubscription = null;

    if (cleanQuery.isEmpty) {
      setState(() {
        _searchResult = [];
        _isLoading = false;
        _currentIntent = null;
        _spellingSuggestion = null;
      });
      return;
    }

    final intent = QueryIntentEngine.analyzeQuery(cleanQuery);

    setState(() {
      _isLoading = true;
      _currentIntent = intent;
    });

    final catalog = await ref.read(cloudCatalogServiceProvider).getCatalog();

    final candidatePool = catalog.map((s) => s.title).followedBy(catalog.map((s) => s.artist));
    final suggestion = FuzzyMatcher.findSpellingSuggestion(cleanQuery, candidatePool);

    // Listen to progressive updates from searchAllSourcesProgressive
    _searchSubscription = LegalSearchEngineService.searchAllSourcesProgressive(
      query: cleanQuery,
      localCatalog: catalog,
      sourceFilter: _selectedSourceFilter != 'All' ? _selectedSourceFilter : null,
      qualityFilter: _selectedQualityFilter != 'All' ? _selectedQualityFilter : null,
    ).listen((progressiveBatch) {
      if (!mounted || requestId != _searchRequestId) return;

      List<SongModel> finalResults = List<SongModel>.from(progressiveBatch.songs);
      if (intent.type == QueryIntentType.artistStrictQuery) {
        _applyArtistSort(finalResults);
      }

      setState(() {
        _searchResult = finalResults;
        _spellingSuggestion = suggestion;
      });
    }, onDone: () {
      if (!mounted || requestId != _searchRequestId) return;
      setState(() {
        _isLoading = false;
      });
    }, onError: (err) {
      if (!mounted || requestId != _searchRequestId) return;
      setState(() {
        _isLoading = false;
      });
    });
  }

  void _applyArtistSort(List<SongModel> list) {
    if (_artistSortOrder == 'Newest first') {
      list.sort((a, b) {
        final ya = int.tryParse(a.releaseDate ?? '0') ?? 0;
        final yb = int.tryParse(b.releaseDate ?? '0') ?? 0;
        return yb.compareTo(ya);
      });
    } else {
      list.sort((a, b) => b.popularity.compareTo(a.popularity));
    }
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
          content: Text('Saved "$playlistTitle" to your library'),
          backgroundColor: AppColors.primarySkyBlue,
          action: SnackBarAction(
            label: 'View',
            textColor: Colors.white,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PlaylistDetailView(
                    title: playlistTitle,
                    subtitle: 'Saved Playlist',
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
  }

  Widget _buildSearchResults(AudioPlayerController playerController, PlayerStateData playerState) {
    if (_searchResult.isEmpty && !_isLoading) {
      final isArtistQuery = _currentIntent?.type == QueryIntentType.artistStrictQuery;
      final artistName = _currentIntent?.matchedArtistName ?? _searchController.text;

      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.search_off_rounded, size: 48, color: AppColors.textSecondary),
              const SizedBox(height: 12),
              Text(
                isArtistQuery
                    ? 'No songs by $artistName found in free sources'
                    : 'No songs found, try another spelling',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                isArtistQuery
                    ? 'SkyTune strictly uses legal, licensed, and open sources. Songs not available from these sources cannot be streamed.'
                    : 'SkyTune searches across all legal sources (Local files, Jamendo, Free Music Archive, Internet Archive).\nTry checking for typos or searching by artist or movie.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              if (_spellingSuggestion != null) ...[
                const SizedBox(height: 14),
                ActionChip(
                  backgroundColor: AppColors.card,
                  avatar: const Icon(Icons.search, size: 16, color: AppColors.primarySkyBlue),
                  label: Text('Did you mean "${_spellingSuggestion}"?',
                      style: const TextStyle(color: AppColors.primarySkyBlue, fontSize: 13, fontWeight: FontWeight.bold)),
                  onPressed: () {
                    _searchController.text = _spellingSuggestion!;
                    _performSearch(_spellingSuggestion!);
                  },
                ),
              ],
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                children: ['Harris Jayaraj', 'Pradeep Kumar', 'Travelling songs', 'Tamil new songs', 'Sleep songs'].map((hint) {
                  return ActionChip(
                    backgroundColor: AppColors.card,
                    label: Text(hint, style: const TextStyle(color: AppColors.textPrimary, fontSize: 12)),
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

    final isArtistStrict = _currentIntent?.type == QueryIntentType.artistStrictQuery;
    final isPlaylistQuery = _currentIntent != null && _currentIntent!.type == QueryIntentType.playlistType;
    final relatedList = _currentIntent?.relatedPlaylists ?? [];

    int extraItemCount = 0;
    if (isArtistStrict) {
      extraItemCount = 1; // ArtistHeaderCard
    } else if (isPlaylistQuery) {
      extraItemCount = 1 + (relatedList.isNotEmpty ? 1 : 0);
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: _searchResult.length + extraItemCount,
      padding: const EdgeInsets.only(bottom: Dimensions.miniPlayerHeight + Dimensions.space64),
      itemBuilder: (context, index) {
        // Strict Artist Header
        if (isArtistStrict && index == 0) {
          final artistName = _currentIntent!.matchedArtistName!;
          return Column(
            children: [
              ArtistHeaderCard(
                artistName: artistName,
                songCount: _searchResult.length,
                onPlay: () {
                  _onSearchSubmitted(_searchController.text);
                  playerController.playSong(_searchResult.first, queue: _searchResult, index: 0);
                },
                onShuffle: () {
                  _onSearchSubmitted(_searchController.text);
                  final shuffled = List<SongModel>.from(_searchResult)..shuffle();
                  playerController.playSong(shuffled.first, queue: shuffled, index: 0);
                },
              ),
              // Sort Option Row & Free Sources Notice
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Dimensions.space16, vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_searchResult.length <= 10)
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.dividers),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline, size: 14, color: AppColors.textSecondary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Only ${_searchResult.length} songs by this artist are available from free sources.',
                                style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                              ),
                            ),
                          ],
                        ),
                      ),
                    Row(
                      children: [
                        Text(
                          '${_searchResult.length} songs by $artistName',
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppColors.dividers),
                          ),
                          child: DropdownButton<String>(
                            value: _artistSortOrder,
                            underline: const SizedBox.shrink(),
                            dropdownColor: AppColors.surface,
                            style: const TextStyle(color: AppColors.textPrimary, fontSize: 11),
                            items: ['Popularity', 'Newest first'].map((s) {
                              return DropdownMenuItem(value: s, child: Text(s));
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _artistSortOrder = val;
                                  _applyArtistSort(_searchResult);
                                });
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
            ],
          );
        }

        // Generated Playlist Card
        if (isPlaylistQuery && index == 0) {
          return GeneratedPlaylistCard(
            title: _currentIntent!.title,
            songs: _searchResult,
            onPlay: () {
              _onSearchSubmitted(_searchController.text);
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

        // Related Playlists
        if (isPlaylistQuery && relatedList.isNotEmpty && index == 1) {
          return Container(
            height: 36,
            margin: const EdgeInsets.only(bottom: 12, left: Dimensions.space16, right: Dimensions.space16),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: relatedList.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (ctx, rIdx) {
                final relTitle = relatedList[rIdx];
                return ActionChip(
                  backgroundColor: AppColors.surface,
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

        final songIndex = index - extraItemCount;
        final song = _searchResult[songIndex];

        return SongTile(
          key: ValueKey(song.id),
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

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Header: Title & Search Field
            Container(
              color: AppColors.background,
              padding: const EdgeInsets.fromLTRB(Dimensions.space16, Dimensions.space12, Dimensions.space16, Dimensions.space8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Search',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    onSubmitted: (val) {
                      _onSearchSubmitted(val);
                      _performSearch(val);
                    },
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppColors.surface,
                      hintText: 'Search songs, artists, moods...',
                      hintStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
                      prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, color: AppColors.textSecondary),
                              onPressed: () {
                                _searchController.clear();
                                _onSearchChanged('');
                              },
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(vertical: Dimensions.space12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.dividers),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.dividers),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.primarySkyBlue),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Autocomplete bar
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
                            backgroundColor: AppColors.elevated,
                            label: Text(sug, style: const TextStyle(color: AppColors.textPrimary, fontSize: 12)),
                            avatar: const Icon(Icons.search, size: 14, color: AppColors.textSecondary),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),

            // Total Count Header
            if (_searchController.text.isNotEmpty)
              Container(
                color: AppColors.background,
                padding: const EdgeInsets.symmetric(horizontal: Dimensions.space16, vertical: 6),
                child: Row(
                  children: [
                    Text(
                      _currentIntent?.type == QueryIntentType.artistStrictQuery
                          ? '${_searchResult.length} songs by ${_currentIntent!.matchedArtistName}'
                          : '${_searchResult.length} ${_searchResult.length == 1 ? 'song found' : 'songs found'}',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    if (_isLoading)
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primarySkyBlue),
                      ),
                  ],
                ),
              ),

            // Main Content
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
                        if (_recentSearches.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          const Text(
                            'Recent searches',
                            style: TextStyle(
                              fontSize: 15,
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
                                backgroundColor: AppColors.surface,
                                label: Text(term, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13)),
                                avatar: const Icon(Icons.history, size: 15, color: AppColors.textSecondary),
                                onPressed: () {
                                  _searchController.text = term;
                                  _performSearch(term);
                                },
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 24),
                        ],
                        const Text(
                          'Browse catalogs',
                          style: TextStyle(
                            fontSize: 16,
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
                            childAspectRatio: 1.65,
                          ),
                          itemBuilder: (context, index) {
                            final item = _browseGenres[index];
                            final title = item['title'] as String;
                            final color = item['color'] as Color;
                            final icon = item['icon'] as IconData;

                            return Material(
                              color: color,
                              borderRadius: BorderRadius.circular(12),
                              clipBehavior: Clip.antiAlias,
                              child: InkWell(
                                onTap: () {
                                  _searchController.text = title;
                                  _performSearch(title);
                                },
                                splashColor: Colors.black26,
                                highlightColor: Colors.black12,
                                child: Stack(
                                  children: [
                                    // Rotated category icon in bottom right corner (full brightness, no glow)
                                    Positioned(
                                      right: -8,
                                      bottom: -8,
                                      child: Transform.rotate(
                                        angle: 0.35, // ~20 degrees
                                        child: Container(
                                          width: 58,
                                          height: 58,
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(0.18),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Icon(
                                            icon,
                                            size: 36,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                    // Card title (top-left, bold white, 16-18px, max 2 lines, ellipsis)
                                    Padding(
                                      padding: const EdgeInsets.all(12.0),
                                      child: Text(
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
