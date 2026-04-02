import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../models/cast_device.dart';

/// Service for discovering Chromecast and Fire TV devices on the local network.
/// Uses fast parallel socket-based scanning.
class CastDiscoveryService {
  static const int _dialPort = 8009;
  static const int _httpPort = 8008;

  bool _isDiscovering = false;

  /// Check if we have required permissions
  Future<bool> checkPermissions() async {
    return true;
  }

  /// Request required permissions at runtime
  Future<bool> requestPermissions() async {
    return true;
  }

  /// Discover all cast devices on the network using parallel scanning
  Future<List<CastDevice>> discoverDevices({Duration? timeout}) async {
    if (_isDiscovering) {
      debugPrint('Discovery already in progress');
      return [];
    }

    final timeoutDuration = timeout ?? const Duration(seconds: 8);
    final devices = <CastDevice>[];
    final startTime = DateTime.now();

    _isDiscovering = true;

    try {
      debugPrint('Starting fast device discovery...');

      // Get local IP to determine subnet
      final localIp = await _getLocalIp();
      if (localIp == null) {
        debugPrint('Could not determine local IP');
        return [];
      }

      final subnet = _getSubnet(localIp);
      debugPrint('Local IP: $localIp, Scanning subnet: $subnet.x');

      // Create batch of futures - scan in parallel
      final futures = <Future<CastDevice?>>[];
      
      for (int i = 2; i <= 254; i++) {
        if (DateTime.now().difference(startTime) > timeoutDuration) break;

        final ip = '$subnet.$i';
        futures.add(_checkDeviceFast(ip));
      }

      // Use wait with timeout
      try {
        final results = await Future.wait(futures).timeout(timeoutDuration);
        
        for (final device in results) {
          if (device != null) {
            // Try to get device info asynchronously
            final info = await _getDeviceInfo(device.host);
            if (info != null) {
              devices.add(CastDevice(
                id: device.id,
                name: info['name'] ?? 'Chromecast',
                host: device.host,
                port: device.port,
                type: _detectDeviceType(info['model'], info['manufacturer']),
                manufacturer: info['manufacturer'],
                model: info['model'],
              ));
            } else {
              devices.add(device);
            }
          }
        }
      } catch (_) {
        // Timeout or error - return what we have
      }

      debugPrint('Discovery complete: found ${devices.length} device(s)');
      return devices;
    } catch (e) {
      debugPrint('Discovery error: $e');
      return devices;
    } finally {
      _isDiscovering = false;
    }
  }

  /// Fast check using TCP with short timeout
  Future<CastDevice?> _checkDeviceFast(String host) async {
    try {
      final socket = await Socket.connect(
        host,
        _dialPort,
        timeout: const Duration(milliseconds: 100),
      );
      socket.destroy();

      return CastDevice(
        id: host,
        name: 'Device',
        host: host,
        port: _dialPort,
        type: CastDeviceType.chromecast,
      );
    } catch (_) {
      return null;
    }
  }

  /// Get device info from Chromecast via HTTP
  Future<Map<String, String>?> _getDeviceInfo(String host) async {
    HttpClient? client;
    try {
      client = HttpClient();
      final request = await client.open(
        'GET',
        host,
        _httpPort,
        '/setup/eureka_info?params=name,model,manufacturer,device_info',
      );
      request.headers.set('Host', '$host:$_httpPort');
      
      final response = await request.close().timeout(const Duration(seconds: 1));
      final responseBody = await response.transform(utf8.decoder).join();

      if (responseBody.contains('"name"')) {
        return {
          'name': _extractJsonField(responseBody, 'name') ?? 'Chromecast',
          'model': _extractJsonField(responseBody, 'model') ?? '',
          'manufacturer': _extractJsonField(responseBody, 'manufacturer') ?? '',
        };
      }
    } catch (_) {
      // Ignore errors
    } finally {
      client?.close();
    }
    return null;
  }

  String? _extractJsonField(String json, String field) {
    final patterns = [
      RegExp('"$field"\\s*:\\s*"([^"]+)"'),
      RegExp("'$field'\\s*:\\s*'([^']+)'"),
    ];
    for (final pattern in patterns) {
      final match = pattern.firstMatch(json);
      if (match != null) return match.group(1);
    }
    return null;
  }

  CastDeviceType _detectDeviceType(String? model, String? manufacturer) {
    final lowerModel = (model ?? '').toLowerCase();
    final lowerMan = (manufacturer ?? '').toLowerCase();
    
    if (lowerModel.contains('fire') || lowerMan.contains('amazon')) {
      return CastDeviceType.firetv;
    }
    if (lowerModel.contains('tv') || 
        lowerMan.contains('samsung') || 
        lowerMan.contains('lg') || 
        lowerMan.contains('sony') ||
        lowerMan.contains('roku')) {
      return CastDeviceType.smarttv;
    }
    if (lowerModel.contains('android')) {
      return CastDeviceType.androidtv;
    }
    return CastDeviceType.chromecast;
  }

  Future<String?> _getLocalIp() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );
      
      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          if (!addr.isLoopback && addr.type == InternetAddressType.IPv4) {
            return addr.address;
          }
        }
      }
    } catch (e) {
      debugPrint('Error getting local IP: $e');
    }
    return null;
  }

  String _getSubnet(String ip) {
    final parts = ip.split('.');
    if (parts.length >= 3) {
      return '${parts[0]}.${parts[1]}.${parts[2]}';
    }
    return '192.168.1';
  }

  void dispose() {
    _isDiscovering = false;
  }
}

void debugPrint(String message) {
  // ignore: avoid_print
  print('[CastDiscovery] $message');
}
