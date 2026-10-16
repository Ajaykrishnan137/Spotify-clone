import 'package:equatable/equatable.dart';

class SongModel extends Equatable {
  final String id;
  final String title;
  final String artist;
  final String album;
  final int durationMs;
  final String coverUrl;
  final String storagePath;
  final String fileHash;
  final String? localPath;
  final bool isDownloaded;
  final DateTime? downloadedAt;
  final String genre;

  const SongModel({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.durationMs,
    required this.coverUrl,
    required this.storagePath,
    this.fileHash = '',
    this.localPath,
    this.isDownloaded = false,
    this.downloadedAt,
    this.genre = 'General',
  });

  SongModel copyWith({
    String? id,
    String? title,
    String? artist,
    String? album,
    int? durationMs,
    String? coverUrl,
    String? storagePath,
    String? fileHash,
    String? localPath,
    bool? isDownloaded,
    DateTime? downloadedAt,
    String? genre,
  }) {
    return SongModel(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      durationMs: durationMs ?? this.durationMs,
      coverUrl: coverUrl ?? this.coverUrl,
      storagePath: storagePath ?? this.storagePath,
      fileHash: fileHash ?? this.fileHash,
      localPath: localPath ?? this.localPath,
      isDownloaded: isDownloaded ?? this.isDownloaded,
      downloadedAt: downloadedAt ?? this.downloadedAt,
      genre: genre ?? this.genre,
    );
  }

  factory SongModel.fromJson(Map<String, dynamic> json) {
    return SongModel(
      id: json['id'] as String,
      title: json['title'] as String,
      artist: json['artist'] as String,
      album: json['album'] as String? ?? 'Single',
      durationMs: (json['duration_ms'] as num?)?.toInt() ?? 0,
      coverUrl: json['cover_url'] as String? ?? '',
      storagePath: json['storage_path'] as String? ?? '',
      fileHash: json['file_hash'] as String? ?? '',
      localPath: json['local_path'] as String?,
      isDownloaded: json['is_downloaded'] as bool? ?? false,
      downloadedAt: json['downloaded_at'] != null 
          ? DateTime.tryParse(json['downloaded_at'] as String) 
          : null,
      genre: json['genre'] as String? ?? 'General',
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'artist': artist,
      'album': album,
      'duration_ms': durationMs,
      'cover_url': coverUrl,
      'storage_path': storagePath,
      'file_hash': fileHash,
      'local_path': localPath,
      'is_downloaded': isDownloaded,
      'downloaded_at': downloadedAt?.toIso8601String(),
      'genre': genre,
    };
  }

  @override
  List<Object?> get props => <Object?>[
        id,
        title,
        artist,
        album,
        durationMs,
        coverUrl,
        storagePath,
        fileHash,
        localPath,
        isDownloaded,
        downloadedAt,
        genre,
      ];
}
