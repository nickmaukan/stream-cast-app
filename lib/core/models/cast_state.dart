import 'package:equatable/equatable.dart';

/// Represents the current state of a casting session
class CastState extends Equatable {
  final bool isConnected;
  final bool isPlaying;
  final bool isPaused;
  final bool isBuffering;
  final Duration position;
  final Duration duration;
  final double volume;
  final bool isMuted;
  final String? currentMediaUrl;
  final String? currentMediaTitle;
  final String? currentMediaThumbnail;
  final String? currentMediaMimeType;
  final List<QualityLevel> availableQualities;
  final QualityLevel? currentQuality;
  final String? error;
  final CastPlayerState playerState;
  final DateTime? lastUpdated;

  const CastState({
    this.isConnected = false,
    this.isPlaying = false,
    this.isPaused = false,
    this.isBuffering = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.volume = 1.0,
    this.isMuted = false,
    this.currentMediaUrl,
    this.currentMediaTitle,
    this.currentMediaThumbnail,
    this.currentMediaMimeType,
    this.availableQualities = const [],
    this.currentQuality,
    this.error,
    this.playerState = CastPlayerState.idle,
    this.lastUpdated,
  });

  bool get hasMedia => currentMediaUrl != null;
  bool get hasError => error != null;
  bool get isIdle => playerState == CastPlayerState.idle;
  bool get isActive => isConnected && hasMedia;
  bool get canPlay => isConnected && hasMedia;

  double get progress {
    if (duration.inMilliseconds == 0) return 0.0;
    return (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
  }

  CastState copyWith({
    bool? isConnected,
    bool? isPlaying,
    bool? isPaused,
    bool? isBuffering,
    Duration? position,
    Duration? duration,
    double? volume,
    bool? isMuted,
    String? currentMediaUrl,
    String? currentMediaTitle,
    String? currentMediaThumbnail,
    String? currentMediaMimeType,
    List<QualityLevel>? availableQualities,
    QualityLevel? currentQuality,
    String? error,
    CastPlayerState? playerState,
    DateTime? lastUpdated,
  }) {
    return CastState(
      isConnected: isConnected ?? this.isConnected,
      isPlaying: isPlaying ?? this.isPlaying,
      isPaused: isPaused ?? this.isPaused,
      isBuffering: isBuffering ?? this.isBuffering,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      volume: volume ?? this.volume,
      isMuted: isMuted ?? this.isMuted,
      currentMediaUrl: currentMediaUrl ?? this.currentMediaUrl,
      currentMediaTitle: currentMediaTitle ?? this.currentMediaTitle,
      currentMediaThumbnail: currentMediaThumbnail ?? this.currentMediaThumbnail,
      currentMediaMimeType: currentMediaMimeType ?? this.currentMediaMimeType,
      availableQualities: availableQualities ?? this.availableQualities,
      currentQuality: currentQuality ?? this.currentQuality,
      error: error,
      playerState: playerState ?? this.playerState,
      lastUpdated: lastUpdated ?? DateTime.now(),
    );
  }

  static const CastState disconnected = CastState();

  @override
  List<Object?> get props => [
    isConnected,
    isPlaying,
    isPaused,
    isBuffering,
    position,
    duration,
    volume,
    isMuted,
    currentMediaUrl,
    playerState,
    error,
  ];
}

enum CastPlayerState {
  idle,
  loading,
  buffering,
  playing,
  paused,
  stopped,
  error;

  String get displayName {
    switch (this) {
      case CastPlayerState.idle:
        return 'Sin actividad';
      case CastPlayerState.loading:
        return 'Cargando...';
      case CastPlayerState.buffering:
        return 'Buffering...';
      case CastPlayerState.playing:
        return 'Reproduciendo';
      case CastPlayerState.paused:
        return 'Pausado';
      case CastPlayerState.stopped:
        return 'Detenido';
      case CastPlayerState.error:
        return 'Error';
    }
  }
}

class QualityLevel extends Equatable {
  final String id;
  final String label;
  final int width;
  final int height;
  final int bitrate;
  final int framerate;

  const QualityLevel({
    required this.id,
    required this.label,
    required this.width,
    required this.height,
    required this.bitrate,
    this.framerate = 30,
  });

  String get resolution => '${height}p';

  @override
  List<Object?> get props => [id, label, width, height, bitrate];
}
