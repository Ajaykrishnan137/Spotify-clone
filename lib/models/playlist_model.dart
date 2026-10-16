import 'package:equatable/equatable.dart';

class PlaylistModel extends Equatable {
  final String id;
  final String ownerId;
  final String name;
  final String? coverUrl;
  final bool isLikedSongs;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int songCount;

  const PlaylistModel({
    required this.id,
    required this.ownerId,
    required this.name,
    this.coverUrl,
    this.isLikedSongs = false,
    required this.createdAt,
    required this.updatedAt,
    this.songCount = 0,
  });

  PlaylistModel copyWith({
    String? id,
    String? ownerId,
    String? name,
    String? coverUrl,
    bool? isLikedSongs,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? songCount,
  }) {
    return PlaylistModel(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      name: name ?? this.name,
      coverUrl: coverUrl ?? this.coverUrl,
      isLikedSongs: isLikedSongs ?? this.isLikedSongs,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      songCount: songCount ?? this.songCount,
    );
  }

  factory PlaylistModel.fromJson(Map<String, dynamic> json) {
    return PlaylistModel(
      id: json['id'] as String,
      ownerId: json['owner_id'] as String? ?? '',
      name: json['name'] as String,
      coverUrl: json['cover_url'] as String?,
      isLikedSongs: json['is_liked_songs'] as bool? ?? false,
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at'] as String) 
          : DateTime.now(),
      updatedAt: json['updated_at'] != null 
          ? DateTime.parse(json['updated_at'] as String) 
          : DateTime.now(),
      songCount: (json['song_count'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'owner_id': ownerId,
      'name': name,
      'cover_url': coverUrl,
      'is_liked_songs': isLikedSongs,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'song_count': songCount,
    };
  }

  @override
  List<Object?> get props => <Object?>[
        id,
        ownerId,
        name,
        coverUrl,
        isLikedSongs,
        createdAt,
        updatedAt,
        songCount,
      ];
}
