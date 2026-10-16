import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../models/playlist_model.dart';
import '../../../models/song_model.dart';
import '../../../core/utils/result.dart';

class SupabasePlaylistsRepository {
  final SupabaseClient _client;

  SupabasePlaylistsRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  Future<Result<List<PlaylistModel>>> fetchUserPlaylists() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        return const Failure('User not authenticated');
      }

      final response = await _client
          .from('playlists')
          .select()
          .eq('owner_id', user.id)
          .order('updated_at', ascending: false);

      final List<PlaylistModel> playlists = (response as List<dynamic>)
          .map((json) => PlaylistModel.fromJson(json as Map<String, dynamic>))
          .toList();

      return Success(playlists);
    } catch (e) {
      return Failure('Failed to fetch user playlists: $e');
    }
  }

  Future<Result<PlaylistModel>> createPlaylist(String name, {bool isLikedSongs = false}) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return const Failure('User not authenticated');

      final response = await _client.from('playlists').insert({
        'owner_id': user.id,
        'name': name,
        'is_liked_songs': isLikedSongs,
      }).select().single();

      return Success(PlaylistModel.fromJson(response));
    } catch (e) {
      return Failure('Failed to create playlist: $e');
    }
  }

  Future<Result<void>> addSongToPlaylist({
    required String playlistId,
    required String songId,
    required int position,
  }) async {
    try {
      await _client.from('playlist_songs').insert({
        'playlist_id': playlistId,
        'song_id': songId,
        'position': position,
      });
      return const Success(null);
    } catch (e) {
      return Failure('Failed to add song to playlist: $e');
    }
  }

  Future<Result<void>> removeSongFromPlaylist({
    required String playlistId,
    required String songId,
  }) async {
    try {
      await _client
          .from('playlist_songs')
          .delete()
          .match({'playlist_id': playlistId, 'song_id': songId});
      return const Success(null);
    } catch (e) {
      return Failure('Failed to remove song: $e');
    }
  }

  Future<Result<List<SongModel>>> fetchPlaylistSongs(String playlistId) async {
    try {
      final response = await _client
          .from('playlist_songs')
          .select('position, songs (*)')
          .eq('playlist_id', playlistId)
          .order('position', ascending: true);

      final List<SongModel> songs = [];
      for (final item in response as List<dynamic>) {
        final songJson = (item as Map<String, dynamic>)['songs'];
        if (songJson != null) {
          songs.add(SongModel.fromJson(songJson as Map<String, dynamic>));
        }
      }

      return Success(songs);
    } catch (e) {
      return Failure('Failed to fetch playlist songs: $e');
    }
  }
}
