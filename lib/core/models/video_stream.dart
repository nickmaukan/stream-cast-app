import 'package:equatable/equatable.dart';

/// Represents a video stream in history/favorites
class VideoStream extends Equatable {
  final int? id;
  final String title;
  final String url;
  final String? thumbnailUrl;
  final String? description;
  final String sourceType;
  final DateTime addedAt;
  final DateTime? lastPlayedAt;
  final int playCount;
  final bool isFavorite;
  final String? deviceId;

  const VideoStream({
    this.id,
    required this.title,
    required this.url,
    this.thumbnailUrl,
    this.description,
    this.sourceType = 'direct',
    required this.addedAt,
    this.lastPlayedAt,
    this.playCount = 0,
    this.isFavorite = false,
    this.deviceId,
  });

  String get formatLabel {
    final lower = url.toLowerCase();
    if (lower.contains('youtube.com') || lower.contains('youtu.be')) return 'YouTube';
    if (lower.contains('vimeo.com')) return 'Vimeo';
    if (lower.contains('.m3u8')) return 'HLS';
    if (lower.contains('.mpd')) return 'DASH';
    if (lower.contains('.webm')) return 'WebM';
    if (lower.contains('.mov')) return 'MOV';
    if (lower.contains('.mp4')) return 'MP4';
    return 'Video';
  }

  VideoStream copyWith({
    int? id,
    String? title,
    String? url,
    String? thumbnailUrl,
    String? description,
    String? sourceType,
    DateTime? addedAt,
    DateTime? lastPlayedAt,
    int? playCount,
    bool? isFavorite,
    String? deviceId,
  }) {
    return VideoStream(
      id: id ?? this.id,
      title: title ?? this.title,
      url: url ?? this.url,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      description: description ?? this.description,
      sourceType: sourceType ?? this.sourceType,
      addedAt: addedAt ?? this.addedAt,
      lastPlayedAt: lastPlayedAt ?? this.lastPlayedAt,
      playCount: playCount ?? this.playCount,
      isFavorite: isFavorite ?? this.isFavorite,
      deviceId: deviceId ?? this.deviceId,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'url': url,
    'thumbnailUrl': thumbnailUrl,
    'description': description,
    'sourceType': sourceType,
    'addedAt': addedAt.toIso8601String(),
    'lastPlayedAt': lastPlayedAt?.toIso8601String(),
    'playCount': playCount,
    'isFavorite': isFavorite ? 1 : 0,
    'deviceId': deviceId,
  };

  factory VideoStream.fromMap(Map<String, dynamic> map) => VideoStream(
    id: map['id'] as int?,
    title: map['title'] as String,
    url: map['url'] as String,
    thumbnailUrl: map['thumbnailUrl'] as String?,
    description: map['description'] as String?,
    sourceType: map['sourceType'] as String? ?? 'direct',
    addedAt: DateTime.parse(map['addedAt'] as String),
    lastPlayedAt: map['lastPlayedAt'] != null
        ? DateTime.parse(map['lastPlayedAt'] as String)
        : null,
    playCount: map['playCount'] as int? ?? 0,
    isFavorite: (map['isFavorite'] as int?) == 1,
    deviceId: map['deviceId'] as String?,
  );

  @override
  List<Object?> get props => [id, url, title, isFavorite];
}
