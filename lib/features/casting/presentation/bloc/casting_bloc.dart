import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/models/cast_device.dart';
import '../../../../core/models/cast_state.dart';
import '../../../../core/models/video_source.dart';
import '../../../../core/services/casting_engine.dart';
import '../../../../core/services/notification_service.dart';

// Events
abstract class CastingEvent extends Equatable {
  const CastingEvent();

  @override
  List<Object?> get props => [];
}

class DiscoverDevices extends CastingEvent {}

class ConnectToDevice extends CastingEvent {
  final CastDevice device;
  const ConnectToDevice(this.device);

  @override
  List<Object?> get props => [device];
}

class DisconnectFromDevice extends CastingEvent {}

class CastVideo extends CastingEvent {
  final VideoSource source;
  const CastVideo(this.source);

  @override
  List<Object?> get props => [source];
}

class PlayMedia extends CastingEvent {}

class PauseMedia extends CastingEvent {}

class StopMedia extends CastingEvent {}

class SeekMedia extends CastingEvent {
  final Duration position;
  const SeekMedia(this.position);

  @override
  List<Object?> get props => [position];
}

class SetVolume extends CastingEvent {
  final double volume;
  const SetVolume(this.volume);

  @override
  List<Object?> get props => [volume];
}

class ToggleMute extends CastingEvent {}

class _CastStateChanged extends CastingEvent {
  final CastState state;
  const _CastStateChanged(this.state);

  @override
  List<Object?> get props => [state];
}

// State
class CastingBlocState extends Equatable {
  final List<CastDevice> devices;
  final CastDevice? connectedDevice;
  final CastState castState;
  final bool isDiscovering;
  final String? error;

  const CastingBlocState({
    this.devices = const [],
    this.connectedDevice,
    this.castState = CastState.disconnected,
    this.isDiscovering = false,
    this.error,
  });

  bool get isConnected => connectedDevice != null && castState.isConnected;
  bool get isCasting => isConnected && castState.hasMedia;

  CastingBlocState copyWith({
    List<CastDevice>? devices,
    CastDevice? connectedDevice,
    CastState? castState,
    bool? isDiscovering,
    String? error,
    bool clearError = false,
    bool clearDevice = false,
  }) {
    return CastingBlocState(
      devices: devices ?? this.devices,
      connectedDevice: clearDevice ? null : (connectedDevice ?? this.connectedDevice),
      castState: castState ?? this.castState,
      isDiscovering: isDiscovering ?? this.isDiscovering,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => [devices, connectedDevice, castState, isDiscovering, error];
}

// Bloc
class CastingBloc extends Bloc<CastingEvent, CastingBlocState> {
  final CastingEngine _engine;
  final NotificationService _notificationService;
  StreamSubscription<CastState>? _stateSubscription;

  CastingBloc({
    CastingEngine? engine,
    NotificationService? notificationService,
  })  : _engine = engine ?? ChromecastEngine(),
        _notificationService = notificationService ?? NotificationService(),
        super(const CastingBlocState()) {
    on<DiscoverDevices>(_onDiscoverDevices);
    on<ConnectToDevice>(_onConnectToDevice);
    on<DisconnectFromDevice>(_onDisconnectFromDevice);
    on<CastVideo>(_onCastVideo);
    on<PlayMedia>(_onPlayMedia);
    on<PauseMedia>(_onPauseMedia);
    on<StopMedia>(_onStopMedia);
    on<SeekMedia>(_onSeekMedia);
    on<SetVolume>(_onSetVolume);
    on<ToggleMute>(_onToggleMute);
    on<_CastStateChanged>(_onCastStateChanged);

    _stateSubscription = _engine.stateStream.listen((castState) {
      add(_CastStateChanged(castState));
    });
  }

  Future<void> _onDiscoverDevices(DiscoverDevices event, Emitter<CastingBlocState> emit) async {
    emit(state.copyWith(isDiscovering: true, clearError: true));

    try {
      final devices = await _engine.discoverDevices();
      emit(state.copyWith(devices: devices, isDiscovering: false));
    } catch (e) {
      emit(state.copyWith(error: 'Discovery failed: $e', isDiscovering: false));
    }
  }

  Future<void> _onConnectToDevice(ConnectToDevice event, Emitter<CastingBlocState> emit) async {
    emit(state.copyWith(clearError: true));

    try {
      await _engine.connectToDevice(event.device);
      emit(state.copyWith(connectedDevice: event.device));
    } catch (e) {
      emit(state.copyWith(error: 'Connection failed: $e'));
    }
  }

  Future<void> _onDisconnectFromDevice(DisconnectFromDevice event, Emitter<CastingBlocState> emit) async {
    await _engine.disconnect();
    await _notificationService.hideCastingNotification();
    emit(state.copyWith(clearDevice: true, castState: CastState.disconnected));
  }

  Future<void> _onCastVideo(CastVideo event, Emitter<CastingBlocState> emit) async {
    if (!state.isConnected) {
      emit(state.copyWith(error: 'No device connected'));
      return;
    }

    emit(state.copyWith(clearError: true));

    try {
      await _engine.castVideo(event.source);
      await _notificationService.showCastingNotification(
        title: event.source.title ?? 'Video',
        deviceName: state.connectedDevice?.name ?? 'TV',
      );
    } catch (e) {
      emit(state.copyWith(error: 'Cast failed: $e'));
    }
  }

  Future<void> _onPlayMedia(PlayMedia event, Emitter<CastingBlocState> emit) async {
    await _engine.play();
  }

  Future<void> _onPauseMedia(PauseMedia event, Emitter<CastingBlocState> emit) async {
    await _engine.pause();
  }

  Future<void> _onStopMedia(StopMedia event, Emitter<CastingBlocState> emit) async {
    await _engine.stop();
    await _notificationService.hideCastingNotification();
  }

  Future<void> _onSeekMedia(SeekMedia event, Emitter<CastingBlocState> emit) async {
    await _engine.seek(event.position);
  }

  Future<void> _onSetVolume(SetVolume event, Emitter<CastingBlocState> emit) async {
    await _engine.setVolume(event.volume);
  }

  Future<void> _onToggleMute(ToggleMute event, Emitter<CastingBlocState> emit) async {
    await _engine.toggleMute();
  }

  void _onCastStateChanged(_CastStateChanged event, Emitter<CastingBlocState> emit) {
    emit(state.copyWith(castState: event.state));

    // Update notification
    if (state.connectedDevice != null) {
      _notificationService.updateCastingNotification(
        state: event.state,
        deviceName: state.connectedDevice!.name,
      );
    }

    // Clear device on disconnect
    if (!event.state.isConnected) {
      emit(state.copyWith(clearDevice: true));
    }
  }

  @override
  Future<void> close() {
    _stateSubscription?.cancel();
    _engine.dispose();
    return super.close();
  }
}
