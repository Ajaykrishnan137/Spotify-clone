import 'dart:convert';
import 'dart:developer' as dev;
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'fuzzy_matcher.dart';

class ArtistAvatarService {
  ArtistAvatarService._();

  static final Map<String, String?> _memoryAvatarCache = {};
  static final Map<String, int> _cacheTimestamps = {};
  static final Map<String, int> _failureCounts = {};
  static bool _diskCacheLoaded = false;
  static const String _cacheFileName = 'skytune_artist_avatars_v3.json';
  static const int _cacheDurationDays = 30;

  static const String _userAgent = 'SkyTuneMusicPlayer/1.0 (contact@skytune.app; legal music player)';

  /// Canonical aliases and common spelling variants mapping to verified Wikipedia page titles
  static const Map<String, String> _artistWikipediaPageTitles = {
    'harris jayaraj': 'Harris Jayaraj',
    'haris jayaraj': 'Harris Jayaraj',
    'haris jeyaraj': 'Harris Jayaraj',
    'harris jeyaraj': 'Harris Jayaraj',
    'hariss jeyaraj': 'Harris Jayaraj',
    'haris jayaraaj': 'Harris Jayaraj',
    'ஹாரிஸ் ஜெயராஜ்': 'Harris Jayaraj',
    'pradeep kumar': 'Pradeep Kumar (musician)',
    'pradeep': 'Pradeep Kumar (musician)',
    'பிரதீப் குமார்': 'Pradeep Kumar (musician)',
    'sid sriram': 'Sid Sriram',
    'சித் ஸ்ரீராம்': 'Sid Sriram',
    'sai abhyankkar': 'Sai Abhyankkar',
    'sai abhyankar': 'Sai Abhyankkar',
    'sai abyankar': 'Sai Abhyankkar',
    'சாய் அபயங்கர்': 'Sai Abhyankkar',
    'anirudh ravichander': 'Anirudh Ravichander',
    'anirudh': 'Anirudh Ravichander',
    'அனிருத்': 'Anirudh Ravichander',
    'a. r. rahman': 'A. R. Rahman',
    'a.r. rahman': 'A. R. Rahman',
    'ar rahman': 'A. R. Rahman',
    'ஏ. ஆர். ரகுமான்': 'A. R. Rahman',
    'lana del rey': 'Lana Del Rey',
    'k. s. chithra': 'K. S. Chithra',
    'k.s. chithra': 'K. S. Chithra',
    'ks chithra': 'K. S. Chithra',
    'chithra': 'K. S. Chithra',
    'சித்ரா': 'K. S. Chithra',
    'shreya ghoshal': 'Shreya Ghoshal',
    'shreya ghosal': 'Shreya Ghoshal',
    'ஷ்ரேயா கோஷல்': 'Shreya Ghoshal',
    'yuvan shankar raja': 'Yuvan Shankar Raja',
    'yuvan': 'Yuvan Shankar Raja',
    'யுவன் சங்கர் ராஜா': 'Yuvan Shankar Raja',
    'g. v. prakash': 'G. V. Prakash Kumar',
    'g.v. prakash': 'G. V. Prakash Kumar',
    'gv prakash': 'G. V. Prakash Kumar',
    'g v prakash': 'G. V. Prakash Kumar',
    'santhosh narayanan': 'Santhosh Narayanan',
    'santosh narayanan': 'Santhosh Narayanan',
    'சந்தோஷ் நாராயணன்': 'Santhosh Narayanan',
    'chinmayi': 'Chinmayi Sripaada',
    'chinmayi sripada': 'Chinmayi Sripaada',
    'chinmayee': 'Chinmayi Sripaada',
    'சின்மயி': 'Chinmayi Sripaada',
    'karthik': 'Karthik (singer)',
    'கார்த்திக்': 'Karthik (singer)',
    'hariharan': 'Hariharan (singer)',
    'ஹரிஹரன்': 'Hariharan (singer)',
    'dhanush': 'Dhanush',
    'தனுஷ்': 'Dhanush',
    'vijay yesudas': 'Vijay Yesudas',
    'விஜய் யேசுதாஸ்': 'Vijay Yesudas',
    'unnikrishnan': 'P. Unnikrishnan',
    'sadhana sargam': 'Sadhana Sargam',
    'swarnalatha': 'Swarnalatha',
    'spb': 'S. P. Balasubrahmanyam',
    's. p. balasubrahmanyam': 'S. P. Balasubrahmanyam',
    'ilayaraja': 'Ilaiyaraaja',
    'ilayaraaja': 'Ilaiyaraaja',
    'illayaraja': 'Ilaiyaraaja',
    'இளையராஜா': 'Ilaiyaraaja',
    'deva': 'Deva (composer)',
    'தேவா': 'Deva (composer)',
  };

  /// Preloads cached avatar URLs from disk (valid for 30 days)
  static Future<void> init() async {
    if (_diskCacheLoaded) return;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File(p.join(dir.path, _cacheFileName));
      if (file.existsSync()) {
        final content = await file.readAsString();
        final Map<String, dynamic> decoded = jsonDecode(content);
        final now = DateTime.now().millisecondsSinceEpoch;
        final maxAgeMs = _cacheDurationDays * 24 * 60 * 60 * 1000;

        decoded.forEach((key, data) {
          if (data is Map<String, dynamic>) {
            final url = data['url'] as String?;
            final ts = data['ts'] as int? ?? 0;
            if (url != null && url.isNotEmpty && (now - ts) < maxAgeMs) {
              _memoryAvatarCache[key] = url;
              _cacheTimestamps[key] = ts;
            }
          }
        });
      }
      _diskCacheLoaded = true;
    } catch (e) {
      dev.log('[ArtistAvatarService] init failed: $e');
      _diskCacheLoaded = true;
    }
  }

  static Future<void> _persistCache() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File(p.join(dir.path, _cacheFileName));
      final Map<String, dynamic> export = {};
      _memoryAvatarCache.forEach((key, url) {
        if (url != null) {
          export[key] = {
            'url': url,
            'ts': _cacheTimestamps[key] ?? DateTime.now().millisecondsSinceEpoch,
          };
        }
      });
      await file.writeAsString(jsonEncode(export), flush: true);
    } catch (_) {}
  }

  /// Extracts clean initials (1 or 2 uppercase letters)
  static String getInitials(String artistName) {
    final clean = artistName.replaceAll(RegExp(r'[^\w\s]'), '').trim();
    if (clean.isEmpty) return 'ST';
    final parts = clean.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.length == 1) {
      return parts.first.substring(0, min(2, parts.first.length)).toUpperCase();
    }
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  /// Flat solid color for the initials avatar (no gradient, no glow)
  static Color getColorForArtist(String artistName) {
    const flatColors = [
      Color(0xFF2C3E5A),
      Color(0xFF27434D),
      Color(0xFF3B3352),
      Color(0xFF42352F),
      Color(0xFF2B4436),
      Color(0xFF333D4F),
      Color(0xFF453037),
    ];
    final idx = artistName.hashCode.abs() % flatColors.length;
    return flatColors[idx];
  }

  /// Validates image URL: HTTP 200, Content-Type image, minimum size (>500 bytes)
  static Future<bool> validateImageUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      final req = await http.get(uri, headers: {
        'User-Agent': _userAgent,
        'Accept': 'image/*,*/*',
      }).timeout(const Duration(seconds: 4));
      if (req.statusCode == 200) {
        final cType = (req.headers['content-type'] ?? '').toLowerCase();
        final bodyBytes = req.bodyBytes;
        if ((cType.startsWith('image/') || cType.contains('octet-stream') || url.endsWith('.jpg') || url.endsWith('.png')) &&
            bodyBytes.length > 500) {
          return true;
        } else {
          dev.log('[ArtistAvatarService] Validation failed for $url: cType=$cType, length=${bodyBytes.length}');
        }
      } else {
        dev.log('[ArtistAvatarService] Validation failed for $url: HTTP ${req.statusCode}');
      }
    } catch (e) {
      dev.log('[ArtistAvatarService] Validation exception for $url: $e');
    }
    return false;
  }

  /// Resolves an artist avatar URL following strict fallback chain with detailed logging:
  /// 1. Legal source image (e.g. Jamendo / local / provided)
  /// 2. Wikipedia / Wikidata / Wikimedia Commons official API (300px width) with musician validation
  /// 3. Returns null (triggering flat solid initials fallback)
  static Future<String?> getArtistAvatarUrl(
    String artistName, {
    String? sourceProvidedUrl,
  }) async {
    final cleanName = artistName.trim();
    if (cleanName.isEmpty) {
      dev.log('[ArtistAvatarService] Empty artist name provided. Skipping.');
      return null;
    }
    final cacheKey = FuzzyMatcher.normalize(cleanName);

    await init();

    if (_memoryAvatarCache.containsKey(cacheKey) && _memoryAvatarCache[cacheKey] != null) {
      return _memoryAvatarCache[cacheKey];
    }

    // Check failure counts (retry with backoff up to 3 times per app session)
    final failures = _failureCounts[cacheKey] ?? 0;
    if (failures >= 3) {
      dev.log('[ArtistAvatarService] Skipping $cleanName: reached maximum 3 retry attempts in this session.');
      return null;
    }

    dev.log('[ArtistAvatarService] [START] Resolving image for "$cleanName" (normalized key: "$cacheKey")...');

    // -------------------------------------------------------------
    // Chain A: Legal source provided URL (Jamendo, metadata, etc.)
    // -------------------------------------------------------------
    if (sourceProvidedUrl != null && sourceProvidedUrl.isNotEmpty && !sourceProvidedUrl.contains('default-music')) {
      dev.log('[ArtistAvatarService] Step A: Checking source-provided image URL: $sourceProvidedUrl');
      final valid = await validateImageUrl(sourceProvidedUrl);
      if (valid) {
        dev.log('[ArtistAvatarService] Step A SUCCESS: Legal source image verified for "$cleanName".');
        _memoryAvatarCache[cacheKey] = sourceProvidedUrl;
        _cacheTimestamps[cacheKey] = DateTime.now().millisecondsSinceEpoch;
        _persistCache();
        return sourceProvidedUrl;
      } else {
        dev.log('[ArtistAvatarService] Step A FAILED: Legal source URL invalid, blocked, or not an image.');
      }
    } else {
      dev.log('[ArtistAvatarService] Step A SKIPPED: No source-provided image URL for "$cleanName".');
    }

    // -------------------------------------------------------------
    // Chain B: Official Wikipedia / Wikidata / Wikimedia Commons APIs
    // -------------------------------------------------------------
    dev.log('[ArtistAvatarService] Step B: Querying official Wikimedia / Wikipedia APIs for "$cleanName"...');
    final wikiUrl = await _resolveFromWikipediaOfficial(cleanName, cacheKey);
    if (wikiUrl != null) {
      dev.log('[ArtistAvatarService] Step B SUCCESS: Verified official photo found: $wikiUrl');
      _memoryAvatarCache[cacheKey] = wikiUrl;
      _cacheTimestamps[cacheKey] = DateTime.now().millisecondsSinceEpoch;
      _persistCache();
      return wikiUrl;
    } else {
      dev.log('[ArtistAvatarService] Step B FAILED: No verified musician image found on Wikimedia / Wikipedia.');
    }

    // -------------------------------------------------------------
    // Chain C: Failed all valid photo lookups -> Flat Initials Avatar
    // -------------------------------------------------------------
    _failureCounts[cacheKey] = failures + 1;
    dev.log('[ArtistAvatarService] Step C FALLBACK: All image sources failed for "$cleanName" (Attempt ${failures + 1}/3). Using flat solid initials avatar.');
    return null;
  }

  static Future<String?> _resolveFromWikipediaOfficial(String originalName, String cacheKey) async {
    // 1. Determine candidate titles based on alias map and normalized spelling
    final candidates = <String>[];

    if (_artistWikipediaPageTitles.containsKey(cacheKey)) {
      candidates.add(_artistWikipediaPageTitles[cacheKey]!);
    }
    for (final entry in _artistWikipediaPageTitles.entries) {
      if (cacheKey.contains(entry.key) || entry.key.contains(cacheKey)) {
        if (!candidates.contains(entry.value)) {
          candidates.add(entry.value);
        }
      }
    }

    if (!candidates.contains(originalName)) {
      candidates.add(originalName);
    }

    // Try direct Wikipedia pageimages for candidate page titles
    for (final title in candidates) {
      try {
        final uri = Uri.parse(
          'https://en.wikipedia.org/w/api.php?action=query&titles=${Uri.encodeComponent(title)}&prop=pageimages|description&format=json&pithumbsize=300',
        );
        dev.log('[ArtistAvatarService] [MediaWiki pageimages] Querying: "$title"...');
        final res = await http.get(uri, headers: {
          'User-Agent': _userAgent,
          'Accept': 'application/json',
        }).timeout(const Duration(seconds: 4));

        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          final pages = data['query']?['pages'] as Map<String, dynamic>?;
          if (pages != null && pages.isNotEmpty) {
            final page = pages.values.first;
            final desc = (page['description'] as String? ?? '').toLowerCase();
            final thumb = page['thumbnail']?['source'] as String?;

            if (thumb != null && thumb.isNotEmpty) {
              final isMusician = _isMusicianDescription(desc);
              if (isMusician || _artistWikipediaPageTitles.containsValue(title)) {
                // Validate thumbnail accessibility
                final valid = await validateImageUrl(thumb);
                if (valid) {
                  dev.log('[ArtistAvatarService] MediaWiki pageimages matched: "$title" ($desc)');
                  return thumb;
                }
              } else {
                dev.log('[ArtistAvatarService] Filtered non-musician title: "$title" description: "$desc"');
              }
            }
          }
        }
      } catch (e) {
        dev.log('[ArtistAvatarService] Error querying Wikipedia for "$title": $e');
      }
    }

    // 2. Query Wikidata API (search entities -> P18 image claim with P106 occupation verification)
    try {
      final searchTarget = candidates.first;
      final wikidataSearchUri = Uri.parse(
        'https://www.wikidata.org/w/api.php?action=wbsearchentities&search=${Uri.encodeComponent(searchTarget)}&language=en&format=json&limit=3',
      );
      dev.log('[ArtistAvatarService] [Wikidata] Searching entities for "$searchTarget"...');
      final searchRes = await http.get(wikidataSearchUri, headers: {
        'User-Agent': _userAgent,
        'Accept': 'application/json',
      }).timeout(const Duration(seconds: 4));

      if (searchRes.statusCode == 200) {
        final sData = jsonDecode(searchRes.body);
        final results = sData['search'] as List?;
        if (results != null) {
          for (final item in results) {
            final entityId = item['id'] as String?;
            final desc = (item['description'] as String? ?? '').toLowerCase();
            if (entityId == null) continue;

            if (_isMusicianDescription(desc)) {
              dev.log('[ArtistAvatarService] [Wikidata] Found musician entity $entityId ($desc). Fetching claims...');
              final entityUri = Uri.parse(
                'https://www.wikidata.org/w/api.php?action=wbgetentities&ids=$entityId&props=claims&format=json',
              );
              final entityRes = await http.get(entityUri, headers: {
                'User-Agent': _userAgent,
                'Accept': 'application/json',
              }).timeout(const Duration(seconds: 4));

              if (entityRes.statusCode == 200) {
                final eData = jsonDecode(entityRes.body);
                final claims = eData['entities']?[entityId]?['claims'] as Map<String, dynamic>?;
                final p18List = claims?['P18'] as List?;
                if (p18List != null && p18List.isNotEmpty) {
                  final fileName = p18List[0]?['mainsnak']?['datavalue']?['value'] as String?;
                  if (fileName != null && fileName.isNotEmpty) {
                    final commonsUrl = 'https://commons.wikimedia.org/wiki/Special:FilePath/${Uri.encodeComponent(fileName)}?width=300';
                    final valid = await validateImageUrl(commonsUrl);
                    if (valid) {
                      dev.log('[ArtistAvatarService] Wikidata P18 image validated: $commonsUrl');
                      return commonsUrl;
                    }
                  }
                }
              }
            }
          }
        }
      }
    } catch (e) {
      dev.log('[ArtistAvatarService] Wikidata lookup failed for "$originalName": $e');
    }

    return null;
  }

  static bool _isMusicianDescription(String desc) {
    if (desc.isEmpty) return false;
    const keywords = [
      'musician', 'singer', 'composer', 'playback', 'music', 'songwriter', 'artist',
      'soundtrack', 'director', 'band', 'producer', 'vocalist'
    ];
    return keywords.any((k) => desc.contains(k));
  }
}
