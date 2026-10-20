import 'package:equatable/equatable.dart';

enum DownloadStatus {
  notDownloaded,
  enqueued,
  downloading,
  paused,
  encrypting,
  downloaded,
  failed,
  canceled,
}

class DownloadTaskState extends Equatable {
  final String songId;
  final DownloadStatus status;
  final double progress; // 0.0 to 1.0
  final String? error;
  final int retryCount;

  const DownloadTaskState({
    required this.songId,
    this.status = DownloadStatus.notDownloaded,
    this.progress = 0.0,
    this.error,
    this.retryCount = 0,
  });

  DownloadTaskState copyWith({
    String? songId,
    DownloadStatus? status,
    double? progress,
    String? error,
    int? retryCount,
  }) {
    return DownloadTaskState(
      songId: songId ?? this.songId,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      error: error,
      retryCount: retryCount ?? this.retryCount,
    );
  }

  Map<String, dynamic> toJson() => {
    'songId': songId,
    'status': status.name,
    'progress': progress,
    'error': error,
    'retryCount': retryCount,
  };

  factory DownloadTaskState.fromJson(Map<String, dynamic> json) {
    return DownloadTaskState(
      songId: json['songId'] as String,
      status: DownloadStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => DownloadStatus.notDownloaded,
      ),
      progress: (json['progress'] as num?)?.toDouble() ?? 0.0,
      error: json['error'] as String?,
      retryCount: json['retryCount'] as int? ?? 0,
    );
  }

  @override
  List<Object?> get props => <Object?>[
        songId,
        status,
        progress,
        error,
        retryCount,
      ];
}

class PlaylistDownloadProgress extends Equatable {
  final String playlistId;
  final bool isActive;
  final bool isPaused;
  final int completedCount;
  final int totalCount;
  final String? currentSongTitle;

  const PlaylistDownloadProgress({
    required this.playlistId,
    this.isActive = false,
    this.isPaused = false,
    this.completedCount = 0,
    this.totalCount = 0,
    this.currentSongTitle,
  });

  PlaylistDownloadProgress copyWith({
    String? playlistId,
    bool? isActive,
    bool? isPaused,
    int? completedCount,
    int? totalCount,
    String? currentSongTitle,
  }) {
    return PlaylistDownloadProgress(
      playlistId: playlistId ?? this.playlistId,
      isActive: isActive ?? this.isActive,
      isPaused: isPaused ?? this.isPaused,
      completedCount: completedCount ?? this.completedCount,
      totalCount: totalCount ?? this.totalCount,
      currentSongTitle: currentSongTitle ?? this.currentSongTitle,
    );
  }

  Map<String, dynamic> toJson() => {
    'playlistId': playlistId,
    'isActive': isActive,
    'isPaused': isPaused,
    'completedCount': completedCount,
    'totalCount': totalCount,
    'currentSongTitle': currentSongTitle,
  };

  factory PlaylistDownloadProgress.fromJson(Map<String, dynamic> json) {
    return PlaylistDownloadProgress(
      playlistId: json['playlistId'] as String,
      isActive: json['isActive'] as bool? ?? false,
      isPaused: json['isPaused'] as bool? ?? false,
      completedCount: json['completedCount'] as int? ?? 0,
      totalCount: json['totalCount'] as int? ?? 0,
      currentSongTitle: json['currentSongTitle'] as String?,
    );
  }

  @override
  List<Object?> get props => [
        playlistId,
        isActive,
        isPaused,
        completedCount,
        totalCount,
        currentSongTitle,
      ];
}
