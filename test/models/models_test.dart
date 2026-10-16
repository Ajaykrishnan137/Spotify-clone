import 'package:flutter_test/flutter_test.dart';
import 'package:wavely/models/song_model.dart';
import 'package:wavely/models/playlist_model.dart';

void main() {
  group('SongModel Tests', () {
    test('SongModel fromJson and toJson serialization roundtrip', () {
      final json = {
        'id': 'test-song-1',
        'title': 'Moongil Thottam',
        'artist': 'A.R. Rahman',
        'album': 'Kadal',
        'duration_ms': 275000,
        'cover_url': 'https://example.com/kadal.jpg',
        'storage_path': 'audio/moongil_thottam.mp3',
        'file_hash': 'abcdef123456',
        'local_path': null,
        'is_downloaded': false,
        'downloaded_at': null,
        'genre': 'Tamil Melody',
      };

      final song = SongModel.fromJson(json);

      expect(song.id, 'test-song-1');
      expect(song.title, 'Moongil Thottam');
      expect(song.artist, 'A.R. Rahman');
      expect(song.durationMs, 275000);
      expect(song.isDownloaded, false);

      final outputJson = song.toJson();
      expect(outputJson['id'], json['id']);
      expect(outputJson['title'], json['title']);
      expect(outputJson['artist'], json['artist']);
    });
  });

  group('PlaylistModel Tests', () {
    test('PlaylistModel correctly parses Liked Songs auto-playlist', () {
      final now = DateTime.now();
      final playlist = PlaylistModel(
        id: 'liked-playlist',
        ownerId: 'user-123',
        name: 'Liked Songs',
        isLikedSongs: true,
        createdAt: now,
        updatedAt: now,
        songCount: 15,
      );

      expect(playlist.isLikedSongs, true);
      expect(playlist.songCount, 15);
      expect(playlist.name, 'Liked Songs');
    });
  });
}
