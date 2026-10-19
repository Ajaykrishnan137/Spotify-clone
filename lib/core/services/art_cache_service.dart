import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:http/http.dart' as http;

class ArtCacheService {
  ArtCacheService._();

  static String? _cachedFallbackUri;

  /// Returns a valid file:// URI to a local bitmap for the song's album art.
  /// If the URL is remote, downloads and caches it locally.
  /// If the URL is an asset, copies it to local cache.
  /// If art fails to load or is empty, creates/returns the fallback SkyTune gradient cloud icon.
  static Future<Uri?> getLocalArtUri(String? coverUrl) async {
    try {
      final cacheDir = await _getArtCacheDir();

      if (coverUrl != null && coverUrl.trim().isNotEmpty) {
        final trimmed = coverUrl.trim();

        // 1. Local file path
        if (trimmed.startsWith('/') || (trimmed.length > 2 && trimmed[1] == ':')) {
          final file = File(trimmed);
          if (file.existsSync()) {
            return file.uri;
          }
        }

        // 2. Local asset (e.g., assets/covers/... or assets/branding/...)
        if (trimmed.startsWith('assets/')) {
          final filename = p.basename(trimmed);
          final cachedTarget = File(p.join(cacheDir.path, 'asset_$filename'));
          if (cachedTarget.existsSync() && cachedTarget.lengthSync() > 0) {
            return cachedTarget.uri;
          }
          try {
            final byteData = await rootBundle.load(trimmed);
            final bytes = byteData.buffer.asUint8List();
            await cachedTarget.writeAsBytes(bytes);
            return cachedTarget.uri;
          } catch (_) {}
        }

        // 3. Remote URL (http / https)
        if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
          final filename = 'net_${trimmed.hashCode.abs()}.jpg';
          final cachedTarget = File(p.join(cacheDir.path, filename));
          if (cachedTarget.existsSync() && cachedTarget.lengthSync() > 0) {
            return cachedTarget.uri;
          }
          try {
            final response = await http
                .get(Uri.parse(trimmed))
                .timeout(const Duration(seconds: 5));
            if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
              await cachedTarget.writeAsBytes(response.bodyBytes);
              return cachedTarget.uri;
            }
          } catch (_) {}
        }
      }

      // 4. Fallback: Return pre-packaged SkyTune cloud icon or extract it
      return await _getFallbackArtUri(cacheDir);
    } catch (_) {
      return null;
    }
  }

  static Future<Directory> _getArtCacheDir() async {
    final tempDir = await getTemporaryDirectory();
    final dir = Directory(p.join(tempDir.path, 'skytune_art_cache'));
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    return dir;
  }

  static Future<Uri?> _getFallbackArtUri(Directory cacheDir) async {
    if (_cachedFallbackUri != null && File(_cachedFallbackUri!).existsSync()) {
      return Uri.file(_cachedFallbackUri!);
    }

    final fallbackFile = File(p.join(cacheDir.path, 'skytune_fallback_art.png'));
    if (fallbackFile.existsSync() && fallbackFile.lengthSync() > 0) {
      _cachedFallbackUri = fallbackFile.path;
      return fallbackFile.uri;
    }

    try {
      // Copy the high-res SkyTune branding icon from assets
      final byteData = await rootBundle.load('assets/branding/skytune_icon.png');
      final bytes = byteData.buffer.asUint8List();
      await fallbackFile.writeAsBytes(bytes);
      _cachedFallbackUri = fallbackFile.path;
      return fallbackFile.uri;
    } catch (_) {
      return null;
    }
  }
}
