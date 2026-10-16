import 'package:equatable/equatable.dart';

enum DownloadStatus {
  notDownloaded,
  enqueued,
  downloading,
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

  @override
  List<Object?> get props => <Object?>[
        songId,
        status,
        progress,
        error,
        retryCount,
      ];
}
