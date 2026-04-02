import 'package:equatable/equatable.dart';

/// Represents a Cast device (Chromecast, Fire TV, Smart TV, etc.)
class CastDevice extends Equatable {
  final String id;
  final String name;
  final String host;
  final int port;
  final CastDeviceType type;
  final String? manufacturer;
  final String? model;
  final String? iconUrl;
  final Map<String, dynamic>? capabilities;

  const CastDevice({
    required this.id,
    required this.name,
    required this.host,
    this.port = 8009,
    this.type = CastDeviceType.chromecast,
    this.manufacturer,
    this.model,
    this.iconUrl,
    this.capabilities,
  });

  bool get supportsDial => type == CastDeviceType.firetv;
  bool get supportsMediaReceiver => type == CastDeviceType.chromecast;
  bool get isSmartTv => type == CastDeviceType.smarttv;

  CastDevice copyWith({
    String? id,
    String? name,
    String? host,
    int? port,
    CastDeviceType? type,
    String? manufacturer,
    String? model,
    String? iconUrl,
    Map<String, dynamic>? capabilities,
  }) {
    return CastDevice(
      id: id ?? this.id,
      name: name ?? this.name,
      host: host ?? this.host,
      port: port ?? this.port,
      type: type ?? this.type,
      manufacturer: manufacturer ?? this.manufacturer,
      model: model ?? this.model,
      iconUrl: iconUrl ?? this.iconUrl,
      capabilities: capabilities ?? this.capabilities,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'host': host,
    'port': port,
    'type': type.name,
    'manufacturer': manufacturer,
    'model': model,
    'iconUrl': iconUrl,
  };

  factory CastDevice.fromJson(Map<String, dynamic> json) => CastDevice(
    id: json['id'] as String,
    name: json['name'] as String,
    host: json['host'] as String,
    port: json['port'] as int? ?? 8009,
    type: CastDeviceType.values.firstWhere(
      (e) => e.name == json['type'],
      orElse: () => CastDeviceType.chromecast,
    ),
    manufacturer: json['manufacturer'] as String?,
    model: json['model'] as String?,
    iconUrl: json['iconUrl'] as String?,
  );

  @override
  List<Object?> get props => [id, host, port];
}

enum CastDeviceType {
  chromecast,
  firetv,
  smarttv,
  androidtv,
  dlna,
  unknown;

  String get displayName {
    switch (this) {
      case CastDeviceType.chromecast:
        return 'Chromecast';
      case CastDeviceType.firetv:
        return 'Fire TV';
      case CastDeviceType.smarttv:
        return 'Smart TV';
      case CastDeviceType.androidtv:
        return 'Android TV';
      case CastDeviceType.dlna:
        return 'DLNA';
      case CastDeviceType.unknown:
        return 'Dispositivo';
    }
  }

  String get icon {
    switch (this) {
      case CastDeviceType.chromecast:
        return '📺';
      case CastDeviceType.firetv:
        return '🔥';
      case CastDeviceType.smarttv:
        return '📺';
      case CastDeviceType.androidtv:
        return '📱';
      case CastDeviceType.dlna:
        return '🌐';
      case CastDeviceType.unknown:
        return '📡';
    }
  }
}
