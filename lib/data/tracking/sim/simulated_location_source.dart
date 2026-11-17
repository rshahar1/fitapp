import 'dart:async';

import 'package:fitapp/data/tracking/location_source.dart';
import 'package:fitapp/data/tracking/sim/track_simulation.dart';
import 'package:fitapp/domain/tracking/track_sample.dart';

/// Dev-only [LocationSource] (feature 019): positions come from a
/// [TrackSimulation] instead of the GPS. Permission is granted and the
/// service is on; the system settings are never opened.
class SimulatedLocationSource implements LocationSource {
  new(this.simulation);

  final TrackSimulation simulation;
  final _service = StreamController<bool>.broadcast();

  @override
  Future<LocationPermissionState> checkPermission() async =>
      LocationPermissionState.granted;

  @override
  Future<LocationPermissionState> requestPermission() async =>
      LocationPermissionState.granted;

  @override
  Future<bool> serviceEnabled() async => true;

  @override
  Stream<bool> serviceStatus() => _service.stream;

  @override
  Future<TrackSample?> lastKnownPosition() async => simulation.firstFix;

  @override
  Future<void> openAppSettings() async {}

  @override
  Future<void> openLocationSettings() async {}

  @override
  Stream<TrackSample> positions({
    required String notificationTitle,
    required String notificationText,
    bool background = true,
    bool rawGps = false,
  }) => simulation.fixes;
}
