import 'package:fitapp/data/tracking/location_source.dart';
import 'package:fitapp/domain/tracking/track_sample.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:geolocator/geolocator.dart';

/// Production [LocationSource] backed by geolocator.
class GeolocatorLocationSource implements LocationSource {
  new();

  static LocationPermissionState _map(LocationPermission p) => switch (p) {
    LocationPermission.always ||
    LocationPermission.whileInUse => LocationPermissionState.granted,
    LocationPermission.deniedForever => LocationPermissionState.deniedForever,
    LocationPermission.denied ||
    LocationPermission.unableToDetermine => LocationPermissionState.denied,
  };

  @override
  Future<LocationPermissionState> checkPermission() async =>
      _map(await Geolocator.checkPermission());

  @override
  Future<LocationPermissionState> requestPermission() async =>
      _map(await Geolocator.requestPermission());

  @override
  Future<bool> serviceEnabled() => Geolocator.isLocationServiceEnabled();

  @override
  Stream<bool> serviceStatus() => Geolocator.getServiceStatusStream().map(
    (status) => status == ServiceStatus.enabled,
  );

  @override
  Future<TrackSample?> lastKnownPosition() async {
    try {
      final p = await Geolocator.getLastKnownPosition();
      return p == null ? null : _toSample(p);
    } on Object {
      return null;
    }
  }

  @override
  Future<void> openAppSettings() => Geolocator.openAppSettings();

  @override
  Future<void> openLocationSettings() => Geolocator.openLocationSettings();

  @override
  Stream<TrackSample> positions({
    required String notificationTitle,
    required String notificationText,
  }) {
    final LocationSettings settings;
    if (defaultTargetPlatform == TargetPlatform.android) {
      settings = AndroidSettings(
        accuracy: LocationAccuracy.high,
        intervalDuration: const Duration(seconds: 1),
        foregroundNotificationConfig: ForegroundNotificationConfig(
          notificationTitle: notificationTitle,
          notificationText: notificationText,
          enableWakeLock: true,
          setOngoing: true,
        ),
      );
    } else {
      settings = AppleSettings(
        accuracy: LocationAccuracy.high,
        activityType: ActivityType.fitness,
        showBackgroundLocationIndicator: true,
      );
    }
    return Geolocator.getPositionStream(locationSettings: settings)
        .map(_toSample);
  }

  static TrackSample _toSample(Position p) => TrackSample(
    t: p.timestamp.toUtc(),
    lat: p.latitude,
    lon: p.longitude,
    alt: p.altitude,
    accuracy: p.accuracy,
    speed: p.speed >= 0 ? p.speed : null,
  );
}
