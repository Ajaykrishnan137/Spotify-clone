import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class ArtistAvatarService {
  ArtistAvatarService._();

  static final Map<String, String?> _memoryAvatarCache = {};
  static bool _diskCacheLoaded = false;
  static const String _cacheFileName = 'skytune_artist_avatars.json';

  /// Standard curated fallback legal images (Wikimedia / Open license) for key artists
  static const Map<String, String> _curatedLegalAvatars = {
    'sid sriram': 'https://upload.wikimedia.org/wikipedia/commons/thumb/2/22/Sid_Sriram_at_Mersal_Audio_Launch.jpg/500px-Sid_Sriram_at_Mersal_Audio_Launch.jpg',
    'pradeep kumar': 'https://upload.wikimedia.org/wikipedia/commons/thumb/e/e0/Pradeep_Kumar_Singer.jpg/500px-Pradeep_Kumar_Singer.jpg',
    'harris jayaraj': 'https://upload.wikimedia.org/wikipedia/commons/thumb/9/90/Harris_Jayaraj_at_Kaappaan_Audio_Launch.jpg/500px-Harris_Jayaraj_at_Kaappaan_Audio_Launch.jpg',
    'sai abhyankar': 'https://upload.wikimedia.org/wikipedia/commons/thumb/d/d4/Sai_Abhyankkar.jpg/500px-Sai_Abhyankkar.jpg',
    'sai abyankar': 'https://upload.wikimedia.org/wikipedia/commons/thumb/d/d4/Sai_Abhyankkar.jpg/500px-Sai_Abhyankkar.jpg',
    'anirudh ravichander': 'https://upload.wikimedia.org/wikipedia/commons/thumb/9/97/Anirudh_Ravichander_at_Audi_Ritz_Style_Awards_2015.jpg/500px-Anirudh_Ravichander_at_Audi_Ritz_Style_Awards_2015.jpg',
    'anirudh': 'https://upload.wikimedia.org/wikipedia/commons/thumb/9/97/Anirudh_Ravichander_at_Audi_Ritz_Style_Awards_2015.jpg/500px-Anirudh_Ravichander_at_Audi_Ritz_Style_Awards_2015.jpg',
    'lana del rey': 'https://upload.wikimedia.org/wikipedia/commons/thumb/4/4c/Lana_Del_Rey_at_the_2019_Grammy_Awards.jpg/500px-Lana_Del_Rey_at_the_2019_Grammy_Awards.jpg',
    'a.r. rahman': 'https://upload.wikimedia.org/wikipedia/commons/thumb/b/b3/A._R._Rahman_at_the_Global_Indian_Music_Awards_2012.jpg/500px-A._R._Rahman_at_the_Global_Indian_Music_Awards_2012.jpg',
    'ar rahman': 'https://upload.wikimedia.org/wikipedia/commons/thumb/b/b3/A._R._Rahman_at_the_Global_Indian_Music_Artist_2012.jpg/500px-A._R._Rahman_at_the_Global_Indian_Music_Artist_2012.jpg',
    'k.s. chithra': 'https://upload.wikimedia.org/wikipedia/commons/thumb/7/7b/K._S._Chithra_2019.jpg/500px-K._S._Chithra_2019.jpg',
    'ks chithra': 'https://upload.wikimedia.org/wikipedia/commons/thumb/7/7b/K._S._Chithra_2019.jpg/500px-K._S._Chithra_2019.jpg',
    'shreya ghoshal': 'https://upload.wikimedia.org/wikipedia/commons/thumb/5/5e/Shreya_Ghoshal_at_Filmfare_Awards.jpg/500px-Shreya_Ghoshal_at_Filmfare_Awards.jpg',
    'yuvan shankar raja': 'https://upload.wikimedia.org/wikipedia/commons/thumb/3/30/Yuvan_Shankar_Raja_at_Raja_Rani_Audio_Launch.jpg/500px-Yuvan_Shankar_Raja_at_Raja_Rani_Audio_Launch.jpg',
    'g.v. prakash': 'https://upload.wikimedia.org/wikipedia/commons/thumb/0/00/GV_Prakash_Kumar_at_Kaala_Audio_Launch.jpg/500px-GV_Prakash_Kumar_at_Kaala_Audio_Launch.jpg',
    'gv prakash': 'https://upload.wikimedia.org/wikipedia/commons/thumb/0/00/GV_Prakash_Kumar_at_Kaala_Audio_Launch.jpg/500px-GV_Prakash_Kumar_at_Kaala_Audio_Launch.jpg',
    'santhosh narayanan': 'https://upload.wikimedia.org/wikipedia/commons/thumb/2/23/Santhosh_Narayanan_at_Kaala_Audio_Launch.jpg/500px-Santhosh_Narayanan_at_Kaala_Audio_Launch.jpg',
    'chinmayi': 'https://upload.wikimedia.org/wikipedia/commons/thumb/2/27/Chinmayi_Sripaada.jpg/500px-Chinmayi_Sripaada.jpg',
    'karthik': 'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c5/Karthik_Singer_2016.jpg/500px-Karthik_Singer_2016.jpg',
    'hariharan': 'https://upload.wikimedia.org/wikipedia/commons/thumb/0/0e/Hariharan_singer.jpg/500px-Hariharan_singer.jpg',
  };

  /// Preloads cached avatar URLs from disk
  static Future<void> init() async {
    if (_diskCacheLoaded) return;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File(p.join(dir.path, _cacheFileName));
      if (file.existsSync()) {
        final content = await file.readAsString();
        final Map<String, dynamic> decoded = jsonDecode(content);
        decoded.forEach((key, val) {
          if (val is String && val.isNotEmpty) {
            _memoryAvatarCache[key.toLowerCase().trim()] = val;
          }
        });
      }
      _diskCacheLoaded = true;
    } catch (_) {
      _diskCacheLoaded = true;
    }
  }

  static Future<void> _persistCache() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File(p.join(dir.path, _cacheFileName));
      await file.writeAsString(jsonEncode(_memoryAvatarCache), flush: true);
    } catch (_) {}
  }

  /// Extracts clean initials from an artist name (up to 2 letters, capitalized)
  static String getInitials(String artistName) {
    final clean = artistName.replaceAll(RegExp(r'[^\w\s]'), '').trim();
    if (clean.isEmpty) return 'ST';
    final parts = clean.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.length == 1) {
      return parts.first.substring(0, min(2, parts.first.length)).toUpperCase();
    }
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  /// Returns a curated SkyTune gradient for an artist based on their name hash
  static LinearGradient getGradientForArtist(String artistName) {
    const gradients = [
      LinearGradient(colors: [Color(0xFF38D6FF), Color(0xFF1E90FF)], begin: Alignment.topLeft, end: Alignment.bottomRight),
      LinearGradient(colors: [Color(0xFF00E676), Color(0xFF00B0FF)], begin: Alignment.topLeft, end: Alignment.bottomRight),
      LinearGradient(colors: [Color(0xFFFF5252), Color(0xFFFF7043)], begin: Alignment.topLeft, end: Alignment.bottomRight),
      LinearGradient(colors: [Color(0xFF7C4DFF), Color(0xFF38D6FF)], begin: Alignment.topLeft, end: Alignment.bottomRight),
      LinearGradient(colors: [Color(0xFFFFC857), Color(0xFFFF8F00)], begin: Alignment.topLeft, end: Alignment.bottomRight),
      LinearGradient(colors: [Color(0xFFE91E63), Color(0xFF9C27B0)], begin: Alignment.topLeft, end: Alignment.bottomRight),
      LinearGradient(colors: [Color(0xFF00B4D8), Color(0xFF0077B6)], begin: Alignment.topLeft, end: Alignment.bottomRight),
    ];
    final idx = artistName.hashCode.abs() % gradients.length;
    return gradients[idx];
  }

  /// Resolves an artist avatar URL from memory/disk cache, curated legal mappings, Jamendo API, or Wikimedia Commons
  static Future<String?> getArtistAvatarUrl(String artistName) async {
    final key = artistName.toLowerCase().trim();
    if (key.isEmpty) return null;

    await init();

    if (_memoryAvatarCache.containsKey(key)) {
      return _memoryAvatarCache[key];
    }

    // 1. Check curated list
    if (_curatedLegalAvatars.containsKey(key)) {
      final url = _curatedLegalAvatars[key]!;
      _memoryAvatarCache[key] = url;
      _persistCache();
      return url;
    }

    // Check fuzzy match in curated list
    for (final entry in _curatedLegalAvatars.entries) {
      if (key.contains(entry.key) || entry.key.contains(key)) {
        _memoryAvatarCache[key] = entry.value;
        _persistCache();
        return entry.value;
      }
    }

    // 2. Fetch from Jamendo Artist API (Creative Commons Legal)
    try {
      final jamendoUrl = Uri.parse(
        'https://api.jamendo.com/v3.0/artists/?client_id=56d30c95&format=json&namesearch=${Uri.encodeComponent(artistName)}&limit=1',
      );
      final res = await http.get(jamendoUrl).timeout(const Duration(seconds: 3));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final results = data['results'] as List?;
        if (results != null && results.isNotEmpty) {
          final img = (results.first['image'] as String? ?? '').trim();
          if (img.isNotEmpty) {
            _memoryAvatarCache[key] = img;
            _persistCache();
            return img;
          }
        }
      }
    } catch (_) {}

    // 3. Fallback to Wikimedia Commons API (Public Domain / CC-BY-SA)
    try {
      final wikiUrl = Uri.parse(
        'https://en.wikipedia.org/w/api.php?action=query&titles=${Uri.encodeComponent(artistName)}&prop=pageimages&format=json&pithumbsize=256',
      );
      final res = await http.get(wikiUrl, headers: {
        'User-Agent': 'SkyTuneMusicPlayer/1.0 (legal open-source music player)',
      }).timeout(const Duration(seconds: 3));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final pages = data['query']?['pages'] as Map<String, dynamic>?;
        if (pages != null && pages.isNotEmpty) {
          final firstPage = pages.values.first;
          final source = firstPage['thumbnail']?['source'] as String?;
          if (source != null && source.isNotEmpty) {
            _memoryAvatarCache[key] = source;
            _persistCache();
            return source;
          }
        }
      }
    } catch (_) {}

    return null;
  }
}
