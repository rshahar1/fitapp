import 'package:fitapp/domain/tracking/track_sample.dart';

/// Location permission as seen by the tracking feature.
enum LocationPermissionState { granted, denied, deniedForever }

/// Platform boundary for GPS fixes (feature 010).
abstract interface class LocationSource {
  Future<LocationPermissionState> checkPermission();

  /// Shows the system permission prompt where the OS allows it.
  Future<LocationPermissionState> requestPermission();

  /// Whether the device's location service is switched on.
  Future<bool> serviceEnabled();

  Future<void> openAppSettings();

  Future<void> openLocationSettings();

  /// A stream of fixes (UTC timestamps). Cancelling the subscription stops
  /// location updates and the foreground notification. The notification text
  /// is shown while tracking runs in the background.
  Stream<TrackSample> positions({
    required String notificationTitle,
    required String notificationText,
  });
}
