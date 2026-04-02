import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Helper extensions
extension StringExtensions on String {
  String get capitalize {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }

  String truncate(int maxLength) {
    if (length <= maxLength) return this;
    return '${substring(0, maxLength)}...';
  }
}

extension DurationExtensions on Duration {
  String get formatted {
    final h = inHours;
    final m = inMinutes.remainder(60);
    final s = inSeconds.remainder(60);

    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}

extension DateTimeExtensions on DateTime {
  String get timeAgo {
    final diff = DateTime.now().difference(this);

    if (diff.inMinutes < 60) {
      return 'Hace ${diff.inMinutes}m';
    } else if (diff.inHours < 24) {
      return 'Hace ${diff.inHours}h';
    } else if (diff.inDays < 7) {
      return 'Hace ${diff.inDays}d';
    } else {
      return '${day}/${month}/${year}';
    }
  }
}

/// Keyboard shortcuts
class KeyboardShortcuts {
  KeyboardShortcuts._();

  static const playPause = SingleActivator(LogicalKeyboardKey.space);
  static const seekForward = SingleActivator(LogicalKeyboardKey.arrowRight);
  static const seekBackward = SingleActivator(LogicalKeyboardKey.arrowLeft);
  static const fullscreen = SingleActivator(LogicalKeyboardKey.keyF);
  static const mute = SingleActivator(LogicalKeyboardKey.keyM);
}

/// URL validation
class UrlValidator {
  UrlValidator._();

  static final _urlRegex = RegExp(
    r'^(https?:\/\/)?([\da-z\.-]+)\.([a-z\.]{2,6})([\/\w \.-]*)*\/?$',
  );

  static final _videoRegex = RegExp(
    r'\.(mp4|m3u8|mpd|webm|mov|mkv|avi)(\?.*)?$',
    caseSensitive: false,
  );

  static bool isValidUrl(String url) {
    return _urlRegex.hasMatch(url);
  }

  static bool isVideoUrl(String url) {
    return _videoRegex.hasMatch(url);
  }

  static String normalizeUrl(String url) {
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      if (url.contains('.') && !url.contains(' ')) {
        return 'https://$url';
      }
      return 'https://www.google.com/search?q=${Uri.encodeComponent(url)}';
    }
    return url;
  }
}

/// Safe navigation
T? safe<T>(T? value, [T? fallback]) => value ?? fallback;
