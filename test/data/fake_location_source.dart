import 'dart:async';

import 'package:fitapp/data/tracking/location_source.dart';
import 'package:fitapp/domain/tracking/track_sample.dart';

/// A controllable [LocationSource] for tests.
class FakeLocationSource implements LocationSource {
  new({
    this.permission = LocationPermissionState.granted,
    this.requestResult,
    this.service = true,
  });

  LocationPermissionState permission;

  /// What [requestPermission] yields; defaults to the current [permission].
  LocationPermissionState? requestResult;
  bool service;
  int appSettingsOpened = 0;
  int locationSettingsOpened = 0;
  bool? lastBackground;
  bool? lastRawGps;
  String? lastNotificationTitle;
  String? lastNotificationText;

  /// What [lastKnownPosition] yields.
  TrackSample? lastKnown;

  /// How many times [positions] was subscribed to.
  int positionsCalls = 0;

  final _serviceController = StreamController<bool>.broadcast(sync: true);

  StreamController<TrackSample>? _controller;

  /// Whether someone is currently listening to [positions].
  bool get listening => _controller?.hasListener ?? false;

  /// Adds one fix to the stream (no-op when nobody listens).
  void emit(TrackSample sample) {
    final c = _controller;
    if (c != null && c.hasListener) c.add(sample);
  }

  /// Fails the current position stream with [error] (no-op without listener).
  void emitError(Object error) {
    final c = _controller;
    if (c != null && c.hasListener) c.addError(error);
  }

  /// Ends the current position stream.
  void closeStream() => unawaited(_controller?.close());

  /// Switches the location service and notifies [serviceStatus] listeners.
  void setService(bool enabled) {
    service = enabled;
    _serviceController.add(enabled);
  }

  /// Whether someone listens to [serviceStatus].
  bool get watchingService => _serviceController.hasListener;

  /// Emits every sample of [samples] in order.
  void replay(Iterable<TrackSample> samples) => samples.forEach(emit);

  @override
  Future<LocationPermissionState> checkPermission() async => permission;

  @override
  Future<LocationPermissionState> requestPermission() async {
    return permission = requestResult ?? permission;
  }

  @override
  Future<bool> serviceEnabled() async => service;

  @override
  Stream<bool> serviceStatus() => _serviceController.stream;

  @override
  Future<TrackSample?> lastKnownPosition() async => lastKnown;

  @override
  Future<void> openAppSettings() async => appSettingsOpened++;

  @override
  Future<void> openLocationSettings() async => locationSettingsOpened++;

  @override
  Stream<TrackSample> positions({
    required String notificationTitle,
    required String notificationText,
    bool background = true,
    bool rawGps = false,
  }) {
    lastBackground = background;
    lastRawGps = rawGps;
    lastNotificationTitle = notificationTitle;
    lastNotificationText = notificationText;
    positionsCalls++;
    final c = StreamController<TrackSample>(sync: true);
    _controller = c;
    return c.stream;
  }
}
