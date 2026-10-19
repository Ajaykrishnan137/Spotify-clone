import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../../models/song_model.dart';
import '../../models/playlist_model.dart';

class DeletedPlaylistBackup {
  final String id;
  final String name;
  final bool isImported;
  final List<SongModel> songs;
  final String? coverUrl;

  DeletedPlaylistBackup({
    required this.id,
    required this.name,
    required this.isImported,
    this.songs = const [],
    this.coverUrl,
  });
}

class HiddenPlaylistsService {
  static const String _fileName = 'hidden_playlists.json';
  File? _cachedFile;
  Set<String>? _hiddenSet;

  Future<File> _getFile() async {
    if (_cachedFile != null) return _cachedFile!;
    final dir = await getApplicationDocumentsDirectory();
    _cachedFile = File(p.join(dir.path, _fileName));
    return _cachedFile!;
  }

  Future<Set<String>> getHiddenPlaylists() async {
    if (_hiddenSet != null) return _hiddenSet!;
    try {
      final file = await _getFile();
      if (!file.existsSync()) {
        _hiddenSet = <String>{};
        return _hiddenSet!;
      }
      final content = await file.readAsString();
      if (content.isEmpty) {
        _hiddenSet = <String>{};
        return _hiddenSet!;
      }
      final list = jsonDecode(content) as List<dynamic>;
      _hiddenSet = list.map((e) => e.toString().toLowerCase().trim()).toSet();
      return _hiddenSet!;
    } catch (_) {
      _hiddenSet = <String>{};
      return _hiddenSet!;
    }
  }

  Future<void> hidePlaylists(Iterable<String> playlistNames) async {
    final current = await getHiddenPlaylists();
    for (final name in playlistNames) {
      current.add(name.toLowerCase().trim());
    }
    _hiddenSet = current;
    await _persist();
  }

  Future<void> unhidePlaylists(Iterable<String> playlistNames) async {
    final current = await getHiddenPlaylists();
    for (final name in playlistNames) {
      current.remove(name.toLowerCase().trim());
    }
    _hiddenSet = current;
    await _persist();
  }

  Future<void> _persist() async {
    try {
      final file = await _getFile();
      final list = (_hiddenSet ?? <String>{}).toList();
      await file.writeAsString(jsonEncode(list), flush: true);
    } catch (_) {}
  }
}

class HiddenPlaylistsNotifier extends StateNotifier<Set<String>> {
  final HiddenPlaylistsService _service;

  HiddenPlaylistsNotifier(this._service) : super({}) {
    _init();
  }

  Future<void> _init() async {
    final hidden = await _service.getHiddenPlaylists();
    state = Set.from(hidden);
  }

  Future<void> hidePlaylist(String name) async {
    await _service.hidePlaylists([name]);
    state = {...state, name.toLowerCase().trim()};
  }

  Future<void> hideMultiplePlaylists(Iterable<String> names) async {
    await _service.hidePlaylists(names);
    state = {...state, ...names.map((n) => n.toLowerCase().trim())};
  }

  Future<void> unhidePlaylist(String name) async {
    await _service.unhidePlaylists([name]);
    final updated = Set<String>.from(state);
    updated.remove(name.toLowerCase().trim());
    state = updated;
  }

  Future<void> unhideMultiplePlaylists(Iterable<String> names) async {
    await _service.unhidePlaylists(names);
    final updated = Set<String>.from(state);
    for (final n in names) {
      updated.remove(n.toLowerCase().trim());
    }
    state = updated;
  }

  bool isHidden(String name) {
    return state.contains(name.toLowerCase().trim());
  }
}

final hiddenPlaylistsServiceProvider = Provider<HiddenPlaylistsService>((ref) {
  return HiddenPlaylistsService();
});

final hiddenPlaylistsProvider = StateNotifierProvider<HiddenPlaylistsNotifier, Set<String>>((ref) {
  final service = ref.watch(hiddenPlaylistsServiceProvider);
  return HiddenPlaylistsNotifier(service);
});
