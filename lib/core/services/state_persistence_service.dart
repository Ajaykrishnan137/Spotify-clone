import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../../models/song_model.dart';

class AppSavedState {
  final SongModel? currentSong;
  final int positionMs;
  final List<SongModel> queue;
  final int currentIndex;
  final String currentRoute;
  final List<SongModel> recentlyPlayed;

  const AppSavedState({
    this.currentSong,
    this.positionMs = 0,
    this.queue = const [],
    this.currentIndex = -1,
    this.currentRoute = '/home',
    this.recentlyPlayed = const [],
  });

  Map<String, dynamic> toJson() => {
    'currentSong': currentSong?.toJson(),
    'positionMs': positionMs,
    'queue': queue.map((s) => s.toJson()).toList(),
    'currentIndex': currentIndex,
    'currentRoute': currentRoute,
    'recentlyPlayed': recentlyPlayed.map((s) => s.toJson()).toList(),
  };

  factory AppSavedState.fromJson(Map<String, dynamic> json) {
    return AppSavedState(
      currentSong: json['currentSong'] != null ? SongModel.fromJson(json['currentSong']) : null,
      positionMs: json['positionMs'] as int? ?? 0,
      queue: (json['queue'] as List<dynamic>?)
              ?.map((e) => SongModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      currentIndex: json['currentIndex'] as int? ?? -1,
      currentRoute: json['currentRoute'] as String? ?? '/home',
      recentlyPlayed: (json['recentlyPlayed'] as List<dynamic>?)
              ?.map((e) => SongModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class StatePersistenceService {
  static const String _fileName = 'app_playback_state.json';
  File? _cachedFile;

  Future<File> _getFile() async {
    if (_cachedFile != null) return _cachedFile!;
    final dir = await getApplicationDocumentsDirectory();
    _cachedFile = File(p.join(dir.path, _fileName));
    return _cachedFile!;
  }

  Future<void> saveState(AppSavedState state) async {
    try {
      final file = await _getFile();
      final jsonStr = jsonEncode(state.toJson());
      await file.writeAsString(jsonStr, flush: true);
    } catch (_) {}
  }

  Future<AppSavedState?> loadState() async {
    try {
      final file = await _getFile();
      if (!file.existsSync()) return null;
      final content = await file.readAsString();
      if (content.isEmpty) return null;
      final map = jsonDecode(content) as Map<String, dynamic>;
      return AppSavedState.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveRecentlyPlayed(List<SongModel> list) async {
    final existing = await loadState() ?? const AppSavedState();
    final updated = AppSavedState(
      currentSong: existing.currentSong,
      positionMs: existing.positionMs,
      queue: existing.queue,
      currentIndex: existing.currentIndex,
      currentRoute: existing.currentRoute,
      recentlyPlayed: list,
    );
    await saveState(updated);
  }

  Future<List<SongModel>> loadRecentlyPlayed() async {
    final state = await loadState();
    return state?.recentlyPlayed ?? [];
  }
}

final statePersistenceServiceProvider = Provider<StatePersistenceService>((ref) {
  return StatePersistenceService();
});
