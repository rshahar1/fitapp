/// Per-activity tracking limits (feature 010).
library;

import 'package:meta/meta.dart';

/// Limits that depend on the activity type.
@immutable
class TrackProfile {
  const new({
    required this.maxSpeedMps,
    required this.autoPauseSpeedMps,
    required this.autoPauseDelay,
  });

  /// The profile for the live-tracking activity [typeId] ('running',
  /// 'cycling' or 'snowboarding'). Throws [ArgumentError] for any other type.
  factory forType(String typeId) => switch (typeId) {
    'running' => running,
    'cycling' => cycling,
    'snowboarding' => snowboarding,
    _ => throw ArgumentError.value(typeId, 'typeId', 'no live tracking'),
  };

  static const running = TrackProfile(
    maxSpeedMps: 12,
    autoPauseSpeedMps: 0.8,
    autoPauseDelay: Duration(seconds: 10),
  );

  static const cycling = TrackProfile(
    maxSpeedMps: 30,
    autoPauseSpeedMps: 1.5,
    autoPauseDelay: Duration(seconds: 5),
  );

  /// Snowboarding: auto-pause never triggers (speed is never below 0) because
  /// standing still is classified as rest by the snow reducer.
  static const snowboarding = TrackProfile(
    maxSpeedMps: 45,
    autoPauseSpeedMps: 0,
    autoPauseDelay: Duration(days: 1),
  );

  /// A segment implying a faster speed is rejected as a GPS glitch.
  final double maxSpeedMps;

  /// Below this speed the user counts as standing still.
  final double autoPauseSpeedMps;

  /// How long the user must stand still before auto-pause kicks in.
  final Duration autoPauseDelay;
}
