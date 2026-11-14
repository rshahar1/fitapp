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
  String? lastNotificationTitle;
  String? lastNotificationText;

  StreamController<TrackSample>? _controller;

  /// Whether someone is currently listening to [positions].
  bool get listening => _controller?.hasListener ?? false;

  /// Adds one fix to the stream (no-op when nobody listens).
  void emit(TrackSample sample) {
    final c = _controller;
    if (c != null && c.hasListener) c.add(sample);
  }

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
  Future<void> openAppSettings() async => appSettingsOpened++;

  @override
  Future<void> openLocationSettings() async => locationSettingsOpened++;

  @override
  Stream<TrackSample> positions({
    required String notificationTitle,
    required String notificationText,
  }) {
    lastNotificationTitle = notificationTitle;
    lastNotificationText = notificationText;
    final c = StreamController<TrackSample>(sync: true);
    _controller = c;
    return c.stream;
  }
}
