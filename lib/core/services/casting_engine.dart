import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../models/cast_device.dart';
import '../models/cast_state.dart';
import '../models/video_source.dart';
import 'cast_discovery_service.dart';

/// Abstract casting engine interface
abstract class CastingEngine {
  Future<List<CastDevice>> discoverDevices({Duration timeout = const Duration(seconds: 15)});
  Future<void> connectToDevice(CastDevice device);
  Future<void> disconnect();
  Future<void> castVideo(VideoSource source);
  Future<void> play();
  Future<void> pause();
  Future<void> stop();
  Future<void> seek(Duration position);
  Future<void> setVolume(double volume);
  Future<void> toggleMute();
  CastState get state;
  Stream<CastState> get stateStream;
  CastDevice? get connectedDevice;
  bool get isConnected;
  void dispose();
}

/// Chromecast/DIAL implementation with real mDNS discovery
class ChromecastEngine extends CastingEngine {
  static const int _dialPort = 8009;
  static const int _httpPort = 8008;

  final CastDiscoveryService _discoveryService = CastDiscoveryService();
  
  CastDevice? _device;
  final _stateController = StreamController<CastState>.broadcast();
  CastState _currentState = CastState.disconnected;
  Timer? _pollTimer;
  final HttpClient _client = HttpClient();

  @override
  CastState get state => _currentState;

  @override
  Stream<CastState> get stateStream => _stateController.stream;

  @override
  CastDevice? get connectedDevice => _device;

  @override
  bool get isConnected => _device != null && _currentState.isConnected;

  @override
  Future<List<CastDevice>> discoverDevices({Duration timeout = const Duration(seconds: 15)}) async {
    debugPrint('Starting device discovery (timeout: ${timeout.inSeconds}s)...');
    
    // Use the mDNS discovery service
    final devices = await _discoveryService.discoverDevices(timeout: timeout);
    
    debugPrint('Discovery complete: found ${devices.length} device(s)');
    return devices;
  }

  @override
  Future<void> connectToDevice(CastDevice device) async {
    debugPrint('Connecting to $device');

    try {
      // Verify device is reachable
      final reachable = await _verifyDevice(device);
      if (!reachable && !device.id.startsWith('manual-')) {
        throw Exception('Device not reachable at ${device.host}');
      }

      _device = device;
      _updateState(_currentState.copyWith(
        isConnected: true,
        playerState: CastPlayerState.idle,
      ));
      
      debugPrint('Connected to ${device.name}');
    } catch (e) {
      debugPrint('Connection failed: $e');
      _updateState(_currentState.copyWith(
        error: 'Connection failed: $e',
        playerState: CastPlayerState.error,
      ));
      rethrow;
    }
  }

  Future<bool> _verifyDevice(CastDevice device) async {
    try {
      // Try to connect to DIAL port
      final socket = await Socket.connect(
        device.host, 
        device.port, 
        timeout: const Duration(seconds: 2)
      );
      socket.destroy();
      
      // Try to get device info
      final info = await _getDeviceInfo(device.host);
      debugPrint('Device info: $info');
      
      return true;
    } catch (e) {
      debugPrint('Device verification failed: $e');
      return false;
    }
  }

  Future<Map<String, String>?> _getDeviceInfo(String host) async {
    try {
      final socket = await Socket.connect(host, _httpPort, timeout: const Duration(seconds: 1));
      socket.write('GET /setup/eureka_info?params=name,model,manufacturer HTTP/1.1\r\nHost: $host\r\n\r\n');
      final bytes = await socket.fold<List<int>>([], (prev, chunk) => prev..addAll(chunk));
      final response = utf8.decode(bytes, allowMalformed: true);
      await socket.close();

      if (response.contains('"name"')) {
        return {
          'name': _extractJsonField(response, 'name') ?? 'Device',
          'model': _extractJsonField(response, 'model') ?? '',
          'manufacturer': _extractJsonField(response, 'manufacturer') ?? '',
        };
      }
    } catch (_) {}
    return null;
  }

  String? _extractJsonField(String json, String field) {
    final match = RegExp('"$field"\\s*:\\s*"([^"]+)"').firstMatch(json);
    return match?.group(1);
  }

  @override
  Future<void> disconnect() async {
    debugPrint('Disconnecting');

    _pollTimer?.cancel();

    if (_device != null) {
      try {
        await stop();
        await _sendHttpRequest(_device!.host, _httpPort, 'POST', '/logout', body: '{}');
      } catch (_) {}
    }

    _device = null;
    _updateState(CastState.disconnected);
  }

  @override
  Future<void> castVideo(VideoSource source) async {
    if (_device == null) throw Exception('No device connected');

    debugPrint('Casting: ${source.url}');

    _updateState(_currentState.copyWith(
      playerState: CastPlayerState.loading,
      currentMediaUrl: source.url,
      currentMediaTitle: source.title,
      currentMediaThumbnail: source.thumbnail,
      currentMediaMimeType: source.mimeTypeResolved,
      error: null,
    ));

    try {
      if (source.isYouTube) {
        await _castYouTube(source);
      } else {
        await _castMedia(source);
      }

      _updateState(_currentState.copyWith(
        playerState: CastPlayerState.playing,
        isPlaying: true,
        isPaused: false,
      ));

      _startPolling();
    } catch (e) {
      debugPrint('Cast failed: $e');
      _updateState(_currentState.copyWith(
        error: 'Cast failed: $e',
        playerState: CastPlayerState.error,
      ));
      rethrow;
    }
  }

  Future<void> _castYouTube(VideoSource source) async {
    final videoId = _extractYouTubeId(source.url);
    if (videoId == null) throw Exception('Invalid YouTube URL');

    await _sendHttpRequest(
      _device!.host,
      _httpPort,
      'POST',
      '/apps/YouTube',
      body: '{"videoId":"$videoId","currentTime":0}',
    );
  }

  Future<void> _castMedia(VideoSource source) async {
    // Launch media receiver
    await _sendHttpRequest(
      _device!.host,
      _httpPort,
      'POST',
      '/apps/ChromeCast',
      body: '{}',
    );

    await Future.delayed(const Duration(milliseconds: 500));

    // Load media
    final mediaLoad = {
      'type': 'LOAD',
      'media': {
        'contentId': source.url,
        'streamType': 'BUFFERED',
        'mimeType': source.mimeTypeResolved,
        'metadata': {
          'type': 0,
          'metadataType': 0,
          'title': source.title ?? 'Video',
          'images': source.thumbnail != null ? [{'url': source.thumbnail}] : [],
        },
      },
      'autoplay': true,
      'currentTime': 0,
    };

    await _sendMediaCommand('LOAD', mediaLoad);
  }

  Future<void> _sendMediaCommand(String type, Map<String, dynamic> data) async {
    final body = json.encode(data);
    await _sendHttpRequest(
      _device!.host,
      _dialPort,
      'POST',
      '/media',
      headers: {'Content-Type': 'application/json'},
      body: body,
    );
  }

  String? _extractYouTubeId(String url) {
    final patterns = [
      RegExp(r'(?:youtube\.com/watch\?v=|youtu\.be/|youtube\.com/embed/)([^&\s]+)'),
    ];
    for (final pattern in patterns) {
      final match = pattern.firstMatch(url);
      if (match != null) return match.group(1);
    }
    return null;
  }

  @override
  Future<void> play() async {
    await _sendMediaCommand('PLAY', {'type': 'PLAY', 'requestId': 1});
    _updateState(_currentState.copyWith(
      isPlaying: true,
      isPaused: false,
      playerState: CastPlayerState.playing,
    ));
  }

  @override
  Future<void> pause() async {
    await _sendMediaCommand('PAUSE', {'type': 'PAUSE', 'requestId': 1});
    _updateState(_currentState.copyWith(
      isPlaying: false,
      isPaused: true,
      playerState: CastPlayerState.paused,
    ));
  }

  @override
  Future<void> stop() async {
    _pollTimer?.cancel();

    if (_device != null) {
      try {
        await _sendMediaCommand('STOP', {'type': 'STOP', 'requestId': 1});
      } catch (_) {}
    }

    _updateState(_currentState.copyWith(
      isPlaying: false,
      isPaused: false,
      playerState: CastPlayerState.stopped,
      currentMediaUrl: null,
      currentMediaTitle: null,
      position: Duration.zero,
    ));
  }

  @override
  Future<void> seek(Duration position) async {
    await _sendMediaCommand('SEEK', {
      'type': 'SEEK',
      'requestId': 1,
      'currentTime': position.inMilliseconds / 1000.0,
    });
    _updateState(_currentState.copyWith(position: position));
  }

  @override
  Future<void> setVolume(double volume) async {
    final volumeData = {
      'type': 'SET_VOLUME',
      'volume': {'level': volume.clamp(0.0, 1.0)},
      'requestId': 1,
    };

    if (_device != null) {
      await _sendHttpRequest(
        _device!.host,
        _httpPort,
        'POST',
        '/receiver',
        headers: {'Content-Type': 'application/json'},
        body: json.encode(volumeData),
      );
    }

    _updateState(_currentState.copyWith(
      volume: volume.clamp(0.0, 1.0),
      isMuted: volume == 0,
    ));
  }

  @override
  Future<void> toggleMute() async {
    final newMuted = !_currentState.isMuted;
    await setVolume(newMuted ? 0 : _currentState.volume);
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (_device == null || !_currentState.isConnected) return;
      try {
        await _pollMediaStatus();
      } catch (_) {}
    });
  }

  Future<void> _pollMediaStatus() async {
    if (_device == null) return;

    try {
      final response = await _sendHttpRequest(
        _device!.host,
        _dialPort,
        'GET',
        '/media',
      );

      if (response != null) {
        final data = json.decode(response) as Map<String, dynamic>;
        final media = data['media'] as Map<String, dynamic>?;
        final currentTime = (media?['currentTime'] as num?) ?? 0;
        final duration = (media?['duration'] as num?) ?? 0;
        final playerState = data['playerState'] as String? ?? 'IDLE';

        _updateState(_currentState.copyWith(
          position: Duration(milliseconds: (currentTime * 1000).round()),
          duration: Duration(milliseconds: (duration * 1000).round()),
          playerState: _parsePlayerState(playerState),
          isPlaying: playerState == 'PLAYING',
          isPaused: playerState == 'PAUSED',
          isBuffering: playerState == 'BUFFERING',
        ));
      }
    } catch (_) {}
  }

  CastPlayerState _parsePlayerState(String state) {
    switch (state.toUpperCase()) {
      case 'PLAYING': return CastPlayerState.playing;
      case 'PAUSED': return CastPlayerState.paused;
      case 'BUFFERING': return CastPlayerState.buffering;
      case 'IDLE': return CastPlayerState.idle;
      case 'STOPPED': return CastPlayerState.stopped;
      default: return CastPlayerState.idle;
    }
  }

  Future<String?> _sendHttpRequest(
    String host,
    int port,
    String method,
    String path, {
    Map<String, String>? headers,
    String? body,
  }) async {
    try {
      final request = await _client.open(method, host, port, path);
      request.headers.set('Content-Type', headers?['Content-Type'] ?? 'application/json');
      headers?.forEach((key, value) {
        if (key != 'Content-Type') request.headers.set(key, value);
      });
      if (body != null) request.write(body);

      final response = await request.close().timeout(const Duration(seconds: 5));
      final bytes = await response.fold<List<int>>([], (prev, chunk) => prev..addAll(chunk));
      final responseBody = utf8.decode(bytes, allowMalformed: true);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return responseBody;
      }
      return null;
    } catch (e) {
      debugPrint('HTTP request failed: $e');
      return null;
    }
  }

  void _updateState(CastState newState) {
    _currentState = newState;
    if (!_stateController.isClosed) {
      _stateController.add(newState);
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _discoveryService.dispose();
    _stateController.close();
    _client.close();
  }
}

void debugPrint(String message) {
  // ignore: avoid_print
  print('[ChromecastEngine] $message');
}
