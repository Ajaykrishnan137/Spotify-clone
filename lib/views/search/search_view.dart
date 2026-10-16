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

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final playerState = ref.watch(audioPlayerControllerProvider);

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
                    ? const EmptyView(
                        key: ValueKey('empty_search'),
                        title: 'Play what you love',
                        subtitle: 'Search for artists, songs, and albums.',
                        icon: Icons.search,
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
