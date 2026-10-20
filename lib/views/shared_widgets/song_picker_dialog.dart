import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/song_model.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/dimensions.dart';
import '../../core/services/cloud_catalog_service.dart';
import 'app_image.dart';

class SongPickerDialog extends ConsumerStatefulWidget {
  final List<SongModel> currentPlaylistSongs;
  final Function(List<SongModel>) onSongsSelected;

  const SongPickerDialog({
    super.key,
    required this.currentPlaylistSongs,
    required this.onSongsSelected,
  });

  static Future<void> show(
    BuildContext context, {
    required List<SongModel> currentPlaylistSongs,
    required Function(List<SongModel>) onSongsSelected,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Dimensions.radiusLarge)),
      ),
      builder: (ctx) => SongPickerDialog(
        currentPlaylistSongs: currentPlaylistSongs,
        onSongsSelected: onSongsSelected,
      ),
    );
  }

  @override
  ConsumerState<SongPickerDialog> createState() => _SongPickerDialogState();
}

class _SongPickerDialogState extends ConsumerState<SongPickerDialog> {
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _selectedSongIds = {};
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allSongsAsync = ref.watch(allSongsProvider);
    final existingIds = widget.currentPlaylistSongs.map((s) => s.id).toSet();

    return SafeArea(
      child: Container(
        height: MediaQuery.of(context).size.height * 0.85,
        padding: const EdgeInsets.symmetric(vertical: Dimensions.space16),
        child: Column(
          children: [
            // Top Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Dimensions.space16),
              child: Row(
                children: [
                  const Text(
                    'Add songs',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _selectedSongIds.isEmpty
                        ? null
                        : () {
                            allSongsAsync.whenData((allSongs) {
                              final selected = allSongs.where((s) => _selectedSongIds.contains(s.id)).toList();
                              widget.onSongsSelected(selected);
                              Navigator.pop(context);
                            });
                          },
                    child: Text(
                      'Done (${_selectedSongIds.length})',
                      style: TextStyle(
                        color: _selectedSongIds.isEmpty ? AppColors.textSecondary : AppColors.cyanAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Search Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(Dimensions.space16, 8, Dimensions.space16, 12),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Search songs, artists...',
                  hintStyle: const TextStyle(color: AppColors.textSecondary),
                  prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: AppColors.textSecondary),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: AppColors.card,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(Dimensions.radiusMedium),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
                onChanged: (val) {
                  setState(() => _searchQuery = val.trim().toLowerCase());
                },
              ),
            ),

            // Song list with checkboxes and "Already in playlist" badge
            Expanded(
              child: allSongsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator(color: AppColors.accent)),
                error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: Colors.red))),
                data: (allSongs) {
                  final filtered = allSongs.where((s) {
                    if (_searchQuery.isEmpty) return true;
                    return s.title.toLowerCase().contains(_searchQuery) ||
                        s.artist.toLowerCase().contains(_searchQuery) ||
                        s.album.toLowerCase().contains(_searchQuery);
                  }).toList();

                  if (filtered.isEmpty) {
                    return const Center(
                      child: Text('No songs found matching query', style: TextStyle(color: AppColors.textSecondary)),
                    );
                  }

                  return ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (ctx, idx) {
                      final song = filtered[idx];
                      final isAlreadyIn = existingIds.contains(song.id);
                      final isSelected = _selectedSongIds.contains(song.id);

                      return CheckboxListTile(
                        value: isSelected || isAlreadyIn,
                        activeColor: isAlreadyIn ? AppColors.textSecondary.withOpacity(0.5) : AppColors.cyanAccent,
                        checkColor: Colors.black,
                        secondary: AppImage(
                          url: song.coverUrl,
                          width: 44,
                          height: 44,
                          borderRadius: Dimensions.radiusSmall,
                        ),
                        title: Text(
                          song.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isAlreadyIn ? AppColors.textSecondary : AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Row(
                          children: [
                            Expanded(
                              child: Text(
                                song.artist,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                              ),
                            ),
                            if (isAlreadyIn) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.card,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'In playlist',
                                  style: TextStyle(color: AppColors.textSecondary, fontSize: 10),
                                ),
                              ),
                            ],
                          ],
                        ),
                        onChanged: isAlreadyIn
                            ? null // Cannot uncheck from here if already in playlist
                            : (val) {
                                setState(() {
                                  if (val == true) {
                                    _selectedSongIds.add(song.id);
                                  } else {
                                    _selectedSongIds.remove(song.id);
                                  }
                                });
                              },
                      );
                    },
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
