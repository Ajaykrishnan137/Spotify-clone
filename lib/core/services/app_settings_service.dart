import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class AppSettingsState {
  final String streamingQuality;
  final String downloadQuality;
  final bool gapless;
  final bool crossfade;
  final int crossfadeDurationSec;
  final bool volumeNormalization;
  final bool wifiOnly;
  final int concurrentDownloads;
  final String themeMode; // 'dark' or 'light'
  final bool enableNotifications;

  const AppSettingsState({
    this.streamingQuality = 'High (320 kbps)',
    this.downloadQuality = 'High (320 kbps)',
    this.gapless = true,
    this.crossfade = false,
    this.crossfadeDurationSec = 3,
    this.volumeNormalization = true,
    this.wifiOnly = false,
    this.concurrentDownloads = 3,
    this.themeMode = 'dark',
    this.enableNotifications = true,
  });

  AppSettingsState copyWith({
    String? streamingQuality,
    String? downloadQuality,
    bool? gapless,
    bool? crossfade,
    int? crossfadeDurationSec,
    bool? volumeNormalization,
    bool? wifiOnly,
    int? concurrentDownloads,
    String? themeMode,
    bool? enableNotifications,
  }) {
    return AppSettingsState(
      streamingQuality: streamingQuality ?? this.streamingQuality,
      downloadQuality: downloadQuality ?? this.downloadQuality,
      gapless: gapless ?? this.gapless,
      crossfade: crossfade ?? this.crossfade,
      crossfadeDurationSec: crossfadeDurationSec ?? this.crossfadeDurationSec,
      volumeNormalization: volumeNormalization ?? this.volumeNormalization,
      wifiOnly: wifiOnly ?? this.wifiOnly,
      concurrentDownloads: concurrentDownloads ?? this.concurrentDownloads,
      themeMode: themeMode ?? this.themeMode,
      enableNotifications: enableNotifications ?? this.enableNotifications,
    );
  }

  Map<String, dynamic> toJson() => {
    'streamingQuality': streamingQuality,
    'downloadQuality': downloadQuality,
    'gapless': gapless,
    'crossfade': crossfade,
    'crossfadeDurationSec': crossfadeDurationSec,
    'volumeNormalization': volumeNormalization,
    'wifiOnly': wifiOnly,
    'concurrentDownloads': concurrentDownloads,
    'themeMode': themeMode,
    'enableNotifications': enableNotifications,
  };

  factory AppSettingsState.fromJson(Map<String, dynamic> json) {
    return AppSettingsState(
      streamingQuality: json['streamingQuality'] as String? ?? 'High (320 kbps)',
      downloadQuality: json['downloadQuality'] as String? ?? 'High (320 kbps)',
      gapless: json['gapless'] as bool? ?? true,
      crossfade: json['crossfade'] as bool? ?? false,
      crossfadeDurationSec: json['crossfadeDurationSec'] as int? ?? 3,
      volumeNormalization: json['volumeNormalization'] as bool? ?? true,
      wifiOnly: json['wifiOnly'] as bool? ?? false,
      concurrentDownloads: json['concurrentDownloads'] as int? ?? 3,
      themeMode: json['themeMode'] as String? ?? 'dark',
      enableNotifications: json['enableNotifications'] as bool? ?? true,
    );
  }
}

class AppSettingsService {
  static const String _fileName = 'skytune_app_settings.json';
  File? _cachedFile;

  Future<File> _getFile() async {
    if (_cachedFile != null) return _cachedFile!;
    final dir = await getApplicationDocumentsDirectory();
    _cachedFile = File(p.join(dir.path, _fileName));
    return _cachedFile!;
  }

  Future<AppSettingsState> loadSettings() async {
    try {
      final file = await _getFile();
      if (!file.existsSync()) return const AppSettingsState();
      final content = await file.readAsString();
      if (content.isEmpty) return const AppSettingsState();
      return AppSettingsState.fromJson(jsonDecode(content) as Map<String, dynamic>);
    } catch (_) {
      return const AppSettingsState();
    }
  }

  Future<void> saveSettings(AppSettingsState settings) async {
    try {
      final file = await _getFile();
      await file.writeAsString(jsonEncode(settings.toJson()), flush: true);
    } catch (_) {}
  }
}

class AppSettingsNotifier extends StateNotifier<AppSettingsState> {
  final AppSettingsService _service;

  AppSettingsNotifier(this._service) : super(const AppSettingsState()) {
    _load();
  }

  Future<void> _load() async {
    state = await _service.loadSettings();
  }

  Future<void> updateSettings(AppSettingsState Function(AppSettingsState) updateFn) async {
    state = updateFn(state);
    await _service.saveSettings(state);
  }

  Future<void> setWifiOnly(bool val) async {
    await updateSettings((s) => s.copyWith(wifiOnly: val));
  }

  Future<void> setConcurrentDownloads(int count) async {
    await updateSettings((s) => s.copyWith(concurrentDownloads: count.clamp(1, 4)));
  }

  Future<void> setStreamingQuality(String q) async {
    await updateSettings((s) => s.copyWith(streamingQuality: q));
  }

  Future<void> setDownloadQuality(String q) async {
    await updateSettings((s) => s.copyWith(downloadQuality: q));
  }

  Future<void> setGapless(bool val) async {
    await updateSettings((s) => s.copyWith(gapless: val));
  }

  Future<void> setCrossfade(bool val) async {
    await updateSettings((s) => s.copyWith(crossfade: val));
  }

  Future<void> setVolumeNormalization(bool val) async {
    await updateSettings((s) => s.copyWith(volumeNormalization: val));
  }

  Future<void> setThemeMode(String mode) async {
    await updateSettings((s) => s.copyWith(themeMode: mode));
  }

  Future<void> setEnableNotifications(bool val) async {
    await updateSettings((s) => s.copyWith(enableNotifications: val));
  }
}

final appSettingsServiceProvider = Provider<AppSettingsService>((ref) {
  return AppSettingsService();
});

final appSettingsProvider = StateNotifierProvider<AppSettingsNotifier, AppSettingsState>((ref) {
  final service = ref.watch(appSettingsServiceProvider);
  return AppSettingsNotifier(service);
});
