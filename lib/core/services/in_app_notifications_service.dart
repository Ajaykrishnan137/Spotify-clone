import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../../models/song_model.dart';

enum NotificationType {
  downloadCompleted,
  downloadFailed,
  playlistUpdated,
  appTip,
}

class InAppNotificationItem {
  final String id;
  final String title;
  final String message;
  final NotificationType type;
  final DateTime timestamp;
  final bool isRead;
  final SongModel? song;
  final String? playlistId;
  final String? playlistName;

  const InAppNotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.timestamp,
    this.isRead = false,
    this.song,
    this.playlistId,
    this.playlistName,
  });

  InAppNotificationItem copyWith({
    String? id,
    String? title,
    String? message,
    NotificationType? type,
    DateTime? timestamp,
    bool? isRead,
    SongModel? song,
    String? playlistId,
    String? playlistName,
  }) {
    return InAppNotificationItem(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      type: type ?? this.type,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      song: song ?? this.song,
      playlistId: playlistId ?? this.playlistId,
      playlistName: playlistName ?? this.playlistName,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'message': message,
    'type': type.name,
    'timestamp': timestamp.toIso8601String(),
    'isRead': isRead,
    'song': song?.toJson(),
    'playlistId': playlistId,
    'playlistName': playlistName,
  };

  factory InAppNotificationItem.fromJson(Map<String, dynamic> json) {
    return InAppNotificationItem(
      id: json['id'] as String,
      title: json['title'] as String,
      message: json['message'] as String,
      type: NotificationType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => NotificationType.appTip,
      ),
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : DateTime.now(),
      isRead: json['isRead'] as bool? ?? false,
      song: json['song'] != null ? SongModel.fromJson(json['song'] as Map<String, dynamic>) : null,
      playlistId: json['playlistId'] as String?,
      playlistName: json['playlistName'] as String?,
    );
  }
}

class InAppNotificationsService {
  static const String _fileName = 'skytune_inapp_notifications.json';
  File? _cachedFile;

  Future<File> _getFile() async {
    if (_cachedFile != null) return _cachedFile!;
    final dir = await getApplicationDocumentsDirectory();
    _cachedFile = File(p.join(dir.path, _fileName));
    return _cachedFile!;
  }

  Future<List<InAppNotificationItem>> loadNotifications() async {
    try {
      final file = await _getFile();
      if (!file.existsSync()) {
        // Return initial welcome tip
        return [
          InAppNotificationItem(
            id: 'welcome_tip',
            title: 'Welcome to SkyTune!',
            message: 'Stream and download 100% legal music from Jamendo, Free Music Archive, and Internet Archive.',
            type: NotificationType.appTip,
            timestamp: DateTime.now(),
            isRead: false,
          ),
        ];
      }
      final content = await file.readAsString();
      if (content.isEmpty) return [];
      final list = jsonDecode(content) as List<dynamic>;
      return list.map((e) => InAppNotificationItem.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveNotifications(List<InAppNotificationItem> items) async {
    try {
      final file = await _getFile();
      final jsonStr = jsonEncode(items.map((e) => e.toJson()).toList());
      await file.writeAsString(jsonStr, flush: true);
    } catch (_) {}
  }
}

class InAppNotificationsNotifier extends StateNotifier<List<InAppNotificationItem>> {
  final InAppNotificationsService _service;

  InAppNotificationsNotifier(this._service) : super([]) {
    _load();
  }

  Future<void> _load() async {
    final list = await _service.loadNotifications();
    list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    state = list;
  }

  int get unreadCount => state.where((n) => !n.isRead).length;

  Future<void> addNotification({
    required String title,
    required String message,
    required NotificationType type,
    SongModel? song,
    String? playlistId,
    String? playlistName,
  }) async {
    final item = InAppNotificationItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      message: message,
      type: type,
      timestamp: DateTime.now(),
      isRead: false,
      song: song,
      playlistId: playlistId,
      playlistName: playlistName,
    );

    final updated = [item, ...state];
    state = updated;
    await _service.saveNotifications(updated);
  }

  Future<void> markAllAsRead() async {
    final updated = state.map((n) => n.copyWith(isRead: true)).toList();
    state = updated;
    await _service.saveNotifications(updated);
  }

  Future<void> removeNotification(String id) async {
    final updated = state.where((n) => n.id != id).toList();
    state = updated;
    await _service.saveNotifications(updated);
  }

  Future<void> clearAll() async {
    state = [];
    await _service.saveNotifications([]);
  }
}

final inAppNotificationsServiceProvider = Provider<InAppNotificationsService>((ref) {
  return InAppNotificationsService();
});

final inAppNotificationsNotifierProvider =
    StateNotifierProvider<InAppNotificationsNotifier, List<InAppNotificationItem>>((ref) {
  final service = ref.watch(inAppNotificationsServiceProvider);
  return InAppNotificationsNotifier(service);
});
