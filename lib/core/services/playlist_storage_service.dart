import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../../models/song_model.dart';
import '../../models/playlist_model.dart';

class CustomPlaylistData {
  final PlaylistModel playlist;
  final List<SongModel> songs;

  CustomPlaylistData({
    required this.playlist,
    required this.songs,
  });

  Map<String, dynamic> toJson() => {
    'playlist': playlist.toJson(),
    'songs': songs.map((s) => s.toJson()).toList(),
  };

  factory CustomPlaylistData.fromJson(Map<String, dynamic> json) {
    return CustomPlaylistData(
      playlist: PlaylistModel.fromJson(json['playlist'] as Map<String, dynamic>),
      songs: (json['songs'] as List<dynamic>?)
              ?.map((e) => SongModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class PlaylistStorageService {
  static const String _fileName = 'skytune_custom_playlists.json';
  File? _cachedFile;

  Future<File> _getFile() async {
    if (_cachedFile != null) return _cachedFile!;
    final dir = await getApplicationDocumentsDirectory();
    _cachedFile = File(p.join(dir.path, _fileName));
    return _cachedFile!;
  }

  Future<Map<String, CustomPlaylistData>> loadAllPlaylists() async {
    try {
      final file = await _getFile();
      if (!file.existsSync()) return {};
      final content = await file.readAsString();
      if (content.isEmpty) return {};
      final map = jsonDecode(content) as Map<String, dynamic>;
      final result = <String, CustomPlaylistData>{};
      map.forEach((k, v) {
        result[k] = CustomPlaylistData.fromJson(v as Map<String, dynamic>);
      });
      return result;
    } catch (_) {
      return {};
    }
  }

  Future<void> saveAllPlaylists(Map<String, CustomPlaylistData> data) async {
    try {
      final file = await _getFile();
      final map = data.map((k, v) => MapEntry(k, v.toJson()));
      await file.writeAsString(jsonEncode(map), flush: true);
    } catch (_) {}
  }
}

final playlistStorageServiceProvider = Provider<PlaylistStorageService>((ref) {
  return PlaylistStorageService();
});
