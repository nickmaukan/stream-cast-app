import 'package:equatable/equatable.dart';

/// Represents a video source detected from a web page or URL
class VideoSource extends Equatable {
  final String url;
  final String? title;
  final String? thumbnail;
  final VideoSourceType type;
  final String? mimeType;
  final int? duration;
  final Map<String, String>? headers;
  final List<QualityLevel>? qualities;
  final String? referer;

  const VideoSource({
    required this.url,
    this.title,
    this.thumbnail,
    required this.type,
    this.mimeType,
    this.duration,
    this.headers,
    this.qualities,
    this.referer,
  });

  bool get isHLS => type == VideoSourceType.hls || url.contains('.m3u8');
  bool get isDash => type == VideoSourceType.dash || url.contains('.mpd');
  bool get isMp4 => type == VideoSourceType.mp4 || url.contains('.mp4');
  bool get isWebM => type == VideoSourceType.webm || url.contains('.webm');
  bool get isYouTube => type == VideoSourceType.youtube;
  bool get isVimeo => type == VideoSourceType.vimeo;

  String get typeLabel {
    switch (type) {
      case VideoSourceType.youtube:
        return 'YouTube';
      case VideoSourceType.vimeo:
        return 'Vimeo';
      case VideoSourceType.hls:
        return 'HLS';
      case VideoSourceType.dash:
        return 'DASH';
      case VideoSourceType.mp4:
        return 'MP4';
      case VideoSourceType.webm:
        return 'WebM';
      case VideoSourceType.mov:
        return 'MOV';
      case VideoSourceType.other:
        return 'Video';
    }
  }

  String get mimeTypeResolved {
    if (mimeType != null) return mimeType!;
    switch (type) {
      case VideoSourceType.hls:
        return 'application/x-mpegURL';
      case VideoSourceType.dash:
        return 'application/dash+xml';
      case VideoSourceType.mp4:
        return 'video/mp4';
      case VideoSourceType.webm:
        return 'video/webm';
      case VideoSourceType.mov:
        return 'video/quicktime';
      default:
        return 'video/mp4';
    }
  }

  VideoSource copyWith({
    String? url,
    String? title,
    String? thumbnail,
    VideoSourceType? type,
    String? mimeType,
    int? duration,
    Map<String, String>? headers,
    List<QualityLevel>? qualities,
    String? referer,
  }) {
    return VideoSource(
      url: url ?? this.url,
      title: title ?? this.title,
      thumbnail: thumbnail ?? this.thumbnail,
      type: type ?? this.type,
      mimeType: mimeType ?? this.mimeType,
      duration: duration ?? this.duration,
      headers: headers ?? this.headers,
      qualities: qualities ?? this.qualities,
      referer: referer ?? this.referer,
    );
  }

  @override
  List<Object?> get props => [url, type, title];
}

enum VideoSourceType {
  youtube,
  vimeo,
  hls,
  dash,
  mp4,
  webm,
  mov,
  other;

  static VideoSourceType fromUrl(String url) {
    final lower = url.toLowerCase();
    if (lower.contains('.m3u8') || lower.contains('hls')) return VideoSourceType.hls;
    if (lower.contains('.mpd') || lower.contains('dash')) return VideoSourceType.dash;
    if (lower.contains('.webm')) return VideoSourceType.webm;
    if (lower.contains('.mov')) return VideoSourceType.mov;
    if (lower.contains('.mp4')) return VideoSourceType.mp4;
    return VideoSourceType.other;
  }
}

class QualityLevel extends Equatable {
  final String id;
  final String label;
  final int height;
  final int bitrate;

  const QualityLevel({
    required this.id,
    required this.label,
    required this.height,
    required this.bitrate,
  });

  String get resolution => '${height}p';

  @override
  List<Object?> get props => [id, label, height, bitrate];
}
