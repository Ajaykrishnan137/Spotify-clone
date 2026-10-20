import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../../models/song_model.dart';

class HistoryEntry {
  final String id;
  final SongModel song;
  final DateTime playedAt;

  const HistoryEntry({
    required this.id,
    required this.song,
    required this.playedAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'song': song.toJson(),
    'playedAt': playedAt.toIso8601String(),
  };

  factory HistoryEntry.fromJson(Map<String, dynamic> json) {
    return HistoryEntry(
      id: json['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString(),
      song: SongModel.fromJson(json['song'] as Map<String, dynamic>),
      playedAt: json['playedAt'] != null
          ? DateTime.parse(json['playedAt'] as String)
          : DateTime.now(),
    );
  }
}

class HistoryService {
  static const String _fileName = 'skytune_listening_history.json';
  File? _cachedFile;

  Future<File> _getFile() async {
    if (_cachedFile != null) return _cachedFile!;
    final dir = await getApplicationDocumentsDirectory();
    _cachedFile = File(p.join(dir.path, _fileName));
    return _cachedFile!;
  }

  Future<List<HistoryEntry>> loadHistory() async {
    try {
      final file = await _getFile();
      if (!file.existsSync()) return [];
      final content = await file.readAsString();
      if (content.isEmpty) return [];
      final list = jsonDecode(content) as List<dynamic>;
      return list.map((e) => HistoryEntry.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveHistory(List<HistoryEntry> entries) async {
    try {
      final file = await _getFile();
      final jsonStr = jsonEncode(entries.map((e) => e.toJson()).toList());
      await file.writeAsString(jsonStr, flush: true);
    } catch (_) {}
  }
}

class HistoryNotifier extends StateNotifier<List<HistoryEntry>> {
  final HistoryService _service;

  HistoryNotifier(this._service) : super([]) {
    _load();
  }

  Future<void> _load() async {
    final list = await _service.loadHistory();
    // Sort newest first
    list.sort((a, b) => b.playedAt.compareTo(a.playedAt));
    state = list;
  }

  Future<void> recordPlay(SongModel song) async {
    final newEntry = HistoryEntry(
      id: '${song.id}_${DateTime.now().millisecondsSinceEpoch}',
      song: song,
      playedAt: DateTime.now(),
    );
    final updated = [newEntry, ...state];
    // Keep max 500 history entries
    if (updated.length > 500) {
      updated.removeRange(500, updated.length);
    }
    state = updated;
    await _service.saveHistory(updated);
  }

  Future<void> removeEntry(String id) async {
    final updated = state.where((e) => e.id != id).toList();
    state = updated;
    await _service.saveHistory(updated);
  }

  Future<void> clearHistory() async {
    state = [];
    await _service.saveHistory([]);
  }
}

final historyServiceProvider = Provider<HistoryService>((ref) {
  return HistoryService();
});

final historyNotifierProvider = StateNotifierProvider<HistoryNotifier, List<HistoryEntry>>((ref) {
  final service = ref.watch(historyServiceProvider);
  return HistoryNotifier(service);
});
