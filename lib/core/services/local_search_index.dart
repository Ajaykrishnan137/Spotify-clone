import 'package:flutter/foundation.dart';
import '../../models/song_model.dart';
import 'fuzzy_matcher.dart';

/// Pre-indexed metadata entry for instant O(1) & prefix lookups
class IndexedSong {
  final SongModel song;
  final String normalizedTitle;
  final String normalizedArtist;
  final String normalizedAlbum;
  final String normalizedGenre;
  final String normalizedCombined;
  final Set<String> tokens;

  IndexedSong({
    required this.song,
    required this.normalizedTitle,
    required this.normalizedArtist,
    required this.normalizedAlbum,
    required this.normalizedGenre,
    required this.normalizedCombined,
    required this.tokens,
  });

  factory IndexedSong.fromSong(SongModel song) {
    final nTitle = FuzzyMatcher.normalize(song.title);
    final nArtist = FuzzyMatcher.normalize(song.artist);
    final nAlbum = FuzzyMatcher.normalize(song.album);
    final nGenre = FuzzyMatcher.normalize(song.genre);
    final nCombined = '$nTitle $nArtist $nAlbum $nGenre';

    final tokens = <String>{};
    for (final part in [nTitle, nArtist, nAlbum, nGenre]) {
      tokens.addAll(part.split(' ').where((t) => t.length >= 2));
    }

    return IndexedSong(
      song: song,
      normalizedTitle: nTitle,
      normalizedArtist: nArtist,
      normalizedAlbum: nAlbum,
      normalizedGenre: nGenre,
      normalizedCombined: nCombined,
      tokens: tokens,
    );
  }
}

/// In-memory & isolated search index for local catalog and downloaded tracks
class LocalSearchIndex {
  LocalSearchIndex._();

  static final Map<String, IndexedSong> _index = {};
  static bool _isIndexed = false;

  /// Index songs once in memory or isolate
  static void buildIndex(List<SongModel> catalog) {
    for (final song in catalog) {
      if (!_index.containsKey(song.id)) {
        _index[song.id] = IndexedSong.fromSong(song);
      }
    }
    _isIndexed = true;
  }

  /// Add dynamic songs (downloaded, playlists, repeat queries) to index
  static void addSongsToIndex(List<SongModel> songs) {
    for (final song in songs) {
      if (!_index.containsKey(song.id)) {
        _index[song.id] = IndexedSong.fromSong(song);
      }
    }
  }

  /// Lightning-fast local search (target < 50ms)
  static List<SongModel> searchFast(String rawQuery, {int limit = 50}) {
    if (rawQuery.trim().isEmpty) return const [];
    final qNorm = FuzzyMatcher.normalize(rawQuery);
    if (qNorm.isEmpty) return const [];

    final qTokens = qNorm.split(' ').where((t) => t.isNotEmpty).toList();
    final List<MapEntry<IndexedSong, double>> matches = [];

    for (final entry in _index.values) {
      double score = 0.0;

      // Exact title or combined match
      if (entry.normalizedTitle == qNorm) {
        score = 1.0;
      } else if (entry.normalizedArtist == qNorm) {
        score = 0.95;
      } else if (entry.normalizedTitle.startsWith(qNorm)) {
        score = 0.9;
      } else if (entry.normalizedArtist.startsWith(qNorm)) {
        score = 0.85;
      } else if (entry.normalizedCombined.contains(qNorm)) {
        score = 0.75;
      } else {
        // Multi-token prefix check
        int matchedTokens = 0;
        for (final qt in qTokens) {
          if (entry.tokens.any((et) => et.startsWith(qt) || et == qt)) {
            matchedTokens++;
          }
        }
        if (matchedTokens == qTokens.length) {
          score = 0.65;
        } else if (matchedTokens > 0) {
          score = (matchedTokens / qTokens.length) * 0.5;
        }
      }

      if (score >= 0.35) {
        matches.add(MapEntry(entry, score));
      }
    }

    matches.sort((a, b) => b.value.compareTo(a.value));
    return matches.take(limit).map((e) => e.key.song.copyWith(source: 'Local Storage')).toList();
  }

  /// Fast strict artist search using pre-indexed entries
  static List<SongModel> searchArtistStrictFast(String canonicalArtistNorm) {
    final List<SongModel> results = [];
    for (final entry in _index.values) {
      if (entry.normalizedArtist == canonicalArtistNorm ||
          entry.tokens.contains(canonicalArtistNorm) ||
          entry.normalizedArtist.contains(canonicalArtistNorm)) {
        results.add(entry.song.copyWith(source: 'Local Storage'));
      }
    }
    return results;
  }
}
