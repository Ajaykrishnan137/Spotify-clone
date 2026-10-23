import 'dart:math';
import 'fuzzy_matcher.dart';

enum QueryIntentType {
  artistStrictQuery,
  playlistType,
  specificSongOrTitle,
}

class QueryIntentResult {
  final QueryIntentType type;
  final String title;
  final String? matchedArtistName;
  final List<String> tags;
  final List<String> genres;
  final List<String> relatedPlaylists;
  final bool isLatestOrTrending;
  final String? sortMode; // 'latest', 'trending', 'mixed'

  const QueryIntentResult({
    required this.type,
    required this.title,
    this.matchedArtistName,
    required this.tags,
    required this.genres,
    this.relatedPlaylists = const [],
    this.isLatestOrTrending = false,
    this.sortMode,
  });
}

class QueryIntentEngine {
  QueryIntentEngine._();

  /// Canonical artists list with known aliases and spelling variants
  static const Map<String, List<String>> _artistAliases = {
    'Harris Jayaraj': [
      'harris jayaraj', 'haris jayaraj', 'haris jeyaraj', 'harris jeyaraj', 'hariss jeyaraj',
      'ஹாரிஸ் ஜெயராஜ்', 'harris', 'jayaraj', 'jeyaraj'
    ],
    'Pradeep Kumar': [
      'pradeep kumar', 'pradeep', 'பிரதீப் குமார்', 'pradeepkumar'
    ],
    'Sid Sriram': [
      'sid sriram', 'sidsriram', 'சித் ஸ்ரீராம்', 'sid'
    ],
    'Sai Abhyankkar': [
      'sai abhyankkar', 'sai abhyankar', 'sai abyankar', 'சாய் அபயங்கர்'
    ],
    'Anirudh Ravichander': [
      'anirudh ravichander', 'anirudh', 'அனிருத்', 'ani'
    ],
    'A. R. Rahman': [
      'a. r. rahman', 'a.r. rahman', 'ar rahman', 'arrahman', 'rahman', 'ஏ. ஆர். ரகுமான்'
    ],
    'Lana Del Rey': [
      'lana del rey', 'lana del ray', 'lanadelrey', 'lana'
    ],
    'K. S. Chithra': [
      'k. s. chithra', 'k.s. chithra', 'ks chithra', 'chithra', 'சித்ரா'
    ],
    'Shreya Ghoshal': [
      'shreya ghoshal', 'shreya ghosal', 'ஷ்ரேயா கோஷல்', 'shreya'
    ],
    'Yuvan Shankar Raja': [
      'yuvan shankar raja', 'yuvan', 'யுவன் சங்கர் ராஜா', 'u1'
    ],
    'G. V. Prakash': [
      'g. v. prakash', 'g.v. prakash', 'gv prakash', 'g v prakash'
    ],
    'Santhosh Narayanan': [
      'santhosh narayanan', 'santosh narayanan', 'சந்தோஷ் நாராயணன்', 'sana'
    ],
    'Chinmayi': [
      'chinmayi', 'chinmayi sripada', 'chinmayee', 'சின்மயி'
    ],
    'Karthik': [
      'karthik', 'கார்த்திக்'
    ],
    'Hariharan': [
      'hariharan', 'ஹரிஹரன்'
    ],
    'Deva': [
      'deva', 'தேவா'
    ],
    'Ilayaraja': [
      'ilayaraja', 'ilayaraaja', 'illayaraja', 'இளையராஜா'
    ],
    'Vijay Yesudas': [
      'vijay yesudas', 'விஜய் யேசுதாஸ்'
    ],
    'Dhanush': [
      'dhanush', 'தனுஷ்'
    ],
  };

  /// Mood/keyword dictionary mapping queries to tags, genres, and languages for each legal source
  static final Map<String, Map<String, dynamic>> _keywordDictionary = {
    // Sleep / Calm / Relax
    'sleep': {
      'title': 'Sleep & Calm Songs',
      'tags': ['ambient', 'lullaby', 'calm', 'piano', 'instrumental', 'relaxing', 'meditation'],
      'genres': ['Sleep', 'Ambient', 'Chillout', 'Classical', 'Piano'],
      'related': ['Deep Sleep Piano', 'Night Rain Lullabies', 'Peaceful Mind'],
    },
    'sleeping': {
      'title': 'Sleep & Calm Songs',
      'tags': ['ambient', 'lullaby', 'calm', 'piano', 'instrumental', 'relaxing'],
      'genres': ['Sleep', 'Ambient', 'Chillout', 'Piano'],
      'related': ['Deep Sleep Piano', 'Night Rain Lullabies', 'Peaceful Mind'],
    },
    'urakkam': {
      'title': 'Sleep & Calm Songs',
      'tags': ['lullaby', 'calm', 'ambient', 'relaxing', 'sleep'],
      'genres': ['Sleep', 'Melody', 'Instrumental'],
      'related': ['Night Lullabies', 'Peaceful Sleep Tamil'],
    },
    'தூக்கம்': {
      'title': 'தூக்க பாடல்கள் (Sleep Songs)',
      'tags': ['ambient', 'lullaby', 'calm', 'piano', 'instrumental', 'relaxing'],
      'genres': ['Sleep', 'Melody', 'Tamil Lullaby'],
      'related': ['இரவு பாடல்கள்', 'அமைதியான இசை'],
    },

    // Travel / Road Trip / Adventure
    'travel': {
      'title': 'Travelling Songs',
      'tags': ['road trip', 'upbeat', 'folk', 'acoustic', 'adventure', 'driving', 'journey'],
      'genres': ['Travel', 'Acoustic', 'Folk', 'Indie', 'Pop'],
      'related': ['Travel Chill', 'Road Trip Anthems', 'Wanderlust Vibes'],
    },
    'travelling': {
      'title': 'Travelling Songs',
      'tags': ['road trip', 'upbeat', 'folk', 'acoustic', 'adventure', 'driving', 'journey'],
      'genres': ['Travel', 'Acoustic', 'Folk', 'Indie', 'Pop'],
      'related': ['Travel Chill', 'Road Trip Anthems', 'Wanderlust Vibes'],
    },
    'traveling': {
      'title': 'Travelling Songs',
      'tags': ['road trip', 'upbeat', 'folk', 'acoustic', 'adventure', 'driving', 'journey'],
      'genres': ['Travel', 'Acoustic', 'Folk', 'Indie', 'Pop'],
      'related': ['Travel Chill', 'Road Trip Anthems', 'Wanderlust Vibes'],
    },
    'payanam': {
      'title': 'Payanam Travelling Songs',
      'tags': ['journey', 'road trip', 'travel', 'acoustic', 'breeze'],
      'genres': ['Travel', 'Tamil Melody', 'Acoustic'],
      'related': ['Road Trip Tamil', 'Highway Melodies', 'Breeze Drive'],
    },
    'பயணம்': {
      'title': 'பயண பாடல்கள் (Travel Hits)',
      'tags': ['road trip', 'upbeat', 'acoustic', 'travel', 'journey'],
      'genres': ['Travel', 'Tamil Melody'],
      'related': ['ரோட் ட்ரிப் தமிழ்', 'பயண ராகங்கள்'],
    },

    // Tamil language & styles
    'tamil': {
      'title': 'Tamil Hits & Melodies',
      'tags': ['tamil', 'kollywood', 'south', 'melody', 'folk'],
      'genres': ['Tamil', 'Melody', 'South India'],
      'related': ['Tamil Melody', 'Tamil Folk', 'Tamil 90s Hits'],
    },
    'தமிழ்': {
      'title': 'தமிழ் ஹிட்ஸ் (Tamil Hits)',
      'tags': ['tamil', 'kollywood', 'melody', 'south'],
      'genres': ['Tamil', 'Melody'],
      'related': ['தமிழ் மெலடி', 'தமிழ் டிரெண்டிங்'],
    },

    // Workout / Gym / Energy
    'workout': {
      'title': 'Workout & Gym Motivation',
      'tags': ['energy', 'fitness', 'workout', 'bass', 'gym', 'electronic', 'dance'],
      'genres': ['Workout', 'Electronic', 'Dance', 'Hip-Hop'],
      'related': ['Gym Motivation', 'Beast Mode EDM', 'Cardio Boost'],
    },
    'gym': {
      'title': 'Gym & Fitness Beats',
      'tags': ['energy', 'fitness', 'bass', 'power', 'electronic'],
      'genres': ['Workout', 'Electronic', 'Power'],
      'related': ['Pump Up EDM', 'Strength Focus'],
    },

    // Romantic / Love / Melody
    'romantic': {
      'title': 'Romantic Melodies & Love Hits',
      'tags': ['love', 'romantic', 'heart', 'acoustic', 'melody', 'duet', 'passion'],
      'genres': ['Romantic', 'Melody', 'Pop', 'Acoustic'],
      'related': ['Love Melodies', 'Sweet Romance', 'Acoustic Love'],
    },
    'love': {
      'title': 'Heartfelt Love Songs',
      'tags': ['love', 'romantic', 'melody', 'acoustic', 'heart'],
      'genres': ['Romantic', 'Love', 'Melody'],
      'related': ['Pure Love', 'Romantic Duets', 'Midnight Love'],
    },
    'kadhal': {
      'title': 'Kaadhal Tamil Melodies',
      'tags': ['love', 'romantic', 'tamil', 'kadhal', 'melody'],
      'genres': ['Tamil', 'Melody', 'Romantic'],
      'related': ['Kaadhal Hits', 'Tamil Love Beats', 'Heartfelt Tamil'],
    },
    'காதல்': {
      'title': 'காதல் பாடல்கள் (Tamil Love Songs)',
      'tags': ['love', 'romantic', 'tamil', 'melody'],
      'genres': ['Tamil', 'Melody', 'Love'],
      'related': ['காதல் ராகம்', 'இதயக் கீதம்'],
    },

    // Chill / Relax / Breeze
    'chill': {
      'title': 'Chill & Relaxing Vibes',
      'tags': ['chill', 'relaxing', 'lo-fi', 'lounge', 'calm', 'downtempo'],
      'genres': ['Chill', 'Lo-Fi', 'Lounge', 'Ambient'],
      'related': ['Chill Lo-Fi', 'Evening Breeze', 'Coffee Beats'],
    },
    'relax': {
      'title': 'Relaxing & Peaceful Songs',
      'tags': ['calm', 'relax', 'peaceful', 'ambient', 'acoustic'],
      'genres': ['Relaxing', 'Acoustic', 'Ambient'],
      'related': ['Peace of Mind', 'Quiet Evening', 'Relaxing Piano'],
    },

    // Party / Dance / Celebration
    'party': {
      'title': 'Party & Dance Anthems',
      'tags': ['dance', 'party', 'club', 'celebration', 'upbeat', 'groove'],
      'genres': ['Party', 'Dance', 'EDM', 'Pop'],
      'related': ['Club Nights', 'Weekend Party', 'Dance Floor Hits'],
    },

    // Focus / Study / Coding
    'focus': {
      'title': 'Focus & Study Flow',
      'tags': ['focus', 'study', 'instrumental', 'concentration', 'brain', 'ambient'],
      'genres': ['Focus', 'Instrumental', 'Ambient', 'Classical'],
      'related': ['Deep Focus', 'Coding Flow', 'Study Lo-Fi'],
    },

    // Devotional / Spiritual
    'devotional': {
      'title': 'Devotional & Spiritual Songs',
      'tags': ['devotional', 'spiritual', 'prayer', 'temple', 'divine', 'peace'],
      'genres': ['Devotional', 'Spiritual', 'Traditional'],
      'related': ['Morning Prayers', 'Peaceful Devotion', 'Divine Chants'],
    },

    // Melody
    'melody': {
      'title': 'Pure Melodies & Soft Hits',
      'tags': ['melody', 'soft', 'acoustic', 'soulful', 'sweet'],
      'genres': ['Melody', 'Acoustic', 'Pop'],
      'related': ['Soulful Melodies', 'Evergreen Melodies', 'Gentle Breeze'],
    },

    // Era: 90s
    '90s': {
      'title': 'Golden 90s Hits',
      'tags': ['90s', 'golden era', 'retro', 'vintage', 'nostalgia', 'classic'],
      'genres': ['90s', 'Retro', 'Classic Pop'],
      'related': ['90s Tamil Classics', '90s Pop Gold', 'Retro Nostalgia'],
    },
  };

  static const Set<String> _playlistIntentKeywords = {
    'songs', 'song', 'playlist', 'hits', 'tracks', 'music', 'mix', 'top', 'best',
    'collection', 'anthems', 'tunes', 'vibes', 'beats', 'paadalgal', 'paatu', 'padalgal',
    'பாடல்கள்', 'பாட்டு', 'இசை'
  };

  static const Set<String> _latestKeywords = {
    'new', 'latest', 'newest', 'recent', 'pudhu', 'puthiya', 'புதிய', 'this week', '2025', '2026'
  };

  static const Set<String> _trendingKeywords = {
    'trending', 'trend', 'top', 'popular', 'hits', 'viral', 'best of', 'famous'
  };

  /// Match query against known artists and aliases
  static String? matchArtistQuery(String cleanQuery) {
    final qNorm = FuzzyMatcher.normalize(cleanQuery);

    for (final entry in _artistAliases.entries) {
      final canonical = entry.key;
      final aliases = entry.value;

      for (final alias in aliases) {
        final aNorm = FuzzyMatcher.normalize(alias);
        if (qNorm == aNorm) return canonical;

        // Check high threshold fuzzy match (>= 0.85)
        final sim = FuzzyMatcher.computeCombinedFuzzyScore(qNorm, aNorm);
        if (sim >= 0.85) {
          return canonical;
        }
      }
    }
    return null;
  }

  /// Analyze raw query string and return intent classification
  static QueryIntentResult analyzeQuery(String rawQuery) {
    final clean = rawQuery.trim().toLowerCase();
    if (clean.isEmpty) {
      return const QueryIntentResult(
        type: QueryIntentType.specificSongOrTitle,
        title: '',
        tags: [],
        genres: [],
      );
    }

    // 1. Check strict artist detection first
    final matchedArtist = matchArtistQuery(clean);
    if (matchedArtist != null) {
      return QueryIntentResult(
        type: QueryIntentType.artistStrictQuery,
        title: matchedArtist,
        matchedArtistName: matchedArtist,
        tags: const [],
        genres: const [],
      );
    }

    final tokens = clean
        .replaceAll(RegExp(r'''[.,\/#!$%\^&\*;:{}=\-_`~()?'"\[\]]'''), ' ')
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList();

    bool hasPlaylistKeyword = tokens.any((t) => _playlistIntentKeywords.contains(t));
    bool hasLatestKeyword = tokens.any((t) => _latestKeywords.contains(t));
    bool hasTrendingKeyword = tokens.any((t) => _trendingKeywords.contains(t));

    String? sortMode;
    if (hasLatestKeyword && hasTrendingKeyword) {
      sortMode = 'mixed';
    } else if (hasLatestKeyword) {
      sortMode = 'latest';
    } else if (hasTrendingKeyword) {
      sortMode = 'trending';
    }

    // Check matching keywords in dictionary
    final matchedTags = <String>{};
    final matchedGenres = <String>{};
    final matchedRelated = <String>{};
    String? resolvedTitle;

    for (final token in tokens) {
      if (_keywordDictionary.containsKey(token)) {
        final dict = _keywordDictionary[token]!;
        resolvedTitle ??= dict['title'] as String?;
        matchedTags.addAll((dict['tags'] as List).cast<String>());
        matchedGenres.addAll((dict['genres'] as List).cast<String>());
        if (dict['related'] != null) {
          matchedRelated.addAll((dict['related'] as List).cast<String>());
        }
      }
    }

    for (final key in _keywordDictionary.keys) {
      if (clean.contains(key)) {
        final dict = _keywordDictionary[key]!;
        resolvedTitle ??= dict['title'] as String?;
        matchedTags.addAll((dict['tags'] as List).cast<String>());
        matchedGenres.addAll((dict['genres'] as List).cast<String>());
        if (dict['related'] != null) {
          matchedRelated.addAll((dict['related'] as List).cast<String>());
        }
      }
    }

    final bool isPlaylistQuery = matchedTags.isNotEmpty ||
        hasPlaylistKeyword ||
        (hasLatestKeyword && tokens.length > 1) ||
        (hasTrendingKeyword && tokens.length > 1);

    if (isPlaylistQuery) {
      String title = resolvedTitle ?? '';
      if (title.isEmpty) {
        final meaningfulTokens = tokens.where((t) =>
            t != 'songs' && t != 'song' && t != 'playlist' && t != 'music' && t != 'tracks');
        if (meaningfulTokens.isNotEmpty) {
          title = meaningfulTokens.map((w) => w[0].toUpperCase() + w.substring(1)).join(' ') + ' Songs';
        } else {
          title = 'Curated Mix';
        }
      }

      if (clean.contains('tamil') && clean.contains('travel')) {
        title = 'Tamil Travelling Songs';
        matchedRelated.add('Road Trip Tamil');
        matchedRelated.add('Travel Chill');
      } else if (clean.contains('tamil') && (clean.contains('new') || clean.contains('latest'))) {
        title = 'Tamil New Songs';
        matchedRelated.add('Tamil Latest Hits');
        matchedRelated.add('Tamil Trending 2026');
      } else if (clean.contains('tamil') && clean.contains('trending')) {
        title = 'Tamil Trending Songs';
        matchedRelated.add('Top Tamil Melodies');
        matchedRelated.add('Tamil Viral Hits');
      } else if (clean.contains('sleep')) {
        matchedRelated.add('Travel Chill');
        matchedRelated.add('Peaceful Piano');
      } else if (clean.contains('travel')) {
        matchedRelated.add('Travel Chill');
        matchedRelated.add('Road Trip Anthems');
      }

      return QueryIntentResult(
        type: QueryIntentType.playlistType,
        title: title,
        tags: matchedTags.toList(),
        genres: matchedGenres.toList(),
        relatedPlaylists: matchedRelated.take(4).toList(),
        isLatestOrTrending: sortMode != null,
        sortMode: sortMode,
      );
    }

    return QueryIntentResult(
      type: QueryIntentType.specificSongOrTitle,
      title: rawQuery,
      tags: const [],
      genres: const [],
      isLatestOrTrending: sortMode != null,
      sortMode: sortMode,
    );
  }
}
