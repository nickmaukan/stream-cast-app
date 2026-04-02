/// App-wide constants
class AppConstants {
  AppConstants._();

  // App info
  static const String appName = 'Maukan Cast';
  static const String appVersion = '2.0.6';

  // API / Network
  static const Duration connectionTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);

  // Cast
  static const int castDialPort = 8009;
  static const int castHttpPort = 8008;
  static const Duration castDiscoveryTimeout = Duration(seconds: 10);
  static const Duration castStatusPollInterval = Duration(seconds: 5);

  // Database
  static const String dbName = 'maukan_cast.db';
  static const int dbVersion = 1;

  // History
  static const int maxHistoryItems = 100;

  // UI
  static const Duration animationDuration = Duration(milliseconds: 300);
  static const Duration toastDuration = Duration(seconds: 3);
}

/// Video sites for quick access
class VideoSites {
  VideoSites._();

  static const List<Map<String, String>> popular = [
    {'name': 'YouTube', 'url': 'https://youtube.com', 'icon': '▶️'},
    {'name': 'Netflix', 'url': 'https://netflix.com', 'icon': '🎬'},
    {'name': 'Amazon', 'url': 'https://primevideo.com', 'icon': '📺'},
    {'name': 'Disney+', 'url': 'https://disneyplus.com', 'icon': '🏰'},
    {'name': 'HBO Max', 'url': 'https://max.com', 'icon': '🎥'},
    {'name': 'Vimeo', 'url': 'https://vimeo.com', 'icon': '🎞️'},
    {'name': 'Tubi', 'url': 'https://tubi.tv', 'icon': '📺'},
    {'name': 'Pluto TV', 'url': 'https://pluto.tv', 'icon': '🌙'},
    {'name': 'Plex', 'url': 'https://plex.tv', 'icon': '🏠'},
    {'name': 'Crackle', 'url': 'https://crackle.com', 'icon': '🎬'},
  ];

  // Sites that are known to have castable videos
  static const List<Map<String, String>> castable = [
    {'name': 'YouTube', 'url': 'https://youtube.com'},
    {'name': 'Vimeo', 'url': 'https://vimeo.com'},
    {'name': 'Dailymotion', 'url': 'https://dailymotion.com'},
    {'name': 'Tubi', 'url': 'https://tubi.tv'},
    {'name': 'Pluto TV', 'url': 'https://pluto.tv'},
    {'name': 'Xumo', 'url': 'https://xumo.com'},
  ];
}
