import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../models/song_model.dart';
import '../../../core/utils/result.dart';

class SupabaseSongsRepository {
  final SupabaseClient _client;

  SupabaseSongsRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  Future<Result<List<SongModel>>> fetchSongs({int limit = 50, int offset = 0}) async {
    try {
      final response = await _client
          .from('songs')
          .select()
          .range(offset, offset + limit - 1)
          .order('created_at', ascending: false);

      final List<SongModel> songs = (response as List<dynamic>)
          .map((json) => SongModel.fromJson(json as Map<String, dynamic>))
          .toList();

      return Success(songs);
    } catch (e) {
      return Failure('Failed to fetch songs from Supabase: $e');
    }
  }

  Future<Result<List<SongModel>>> searchSongs(String query) async {
    try {
      final response = await _client
          .from('songs')
          .select()
          .or('title.ilike.%$query%,artist.ilike.%$query%,album.ilike.%$query%')
          .limit(30);

      final List<SongModel> songs = (response as List<dynamic>)
          .map((json) => SongModel.fromJson(json as Map<String, dynamic>))
          .toList();

      return Success(songs);
    } catch (e) {
      return Failure('Failed to search songs: $e');
    }
  }

  /// Obtains an audio URL for streaming or downloading.
  /// If the storagePath is already a direct URL (e.g. GitHub Release or CDN), returns it immediately.
  Future<Result<String>> getSignedAudioUrl(String storagePath) async {
    try {
      if (storagePath.startsWith('http://') || storagePath.startsWith('https://')) {
        return Success(storagePath);
      }

      final String signedUrl = await _client.storage
          .from('audio')
          .createSignedUrl(storagePath, 3600); // 1 hour validity

      return Success(signedUrl);
    } catch (e) {
      return Failure('Failed to generate audio URL: $e');
    }
  }
}
