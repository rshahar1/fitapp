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

  /// The profile for the live-tracking activity [typeId] ('running' or
  /// 'cycling'). Throws [ArgumentError] for any other type.
  factory forType(String typeId) => switch (typeId) {
    'running' => running,
    'cycling' => cycling,
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

  /// A segment implying a faster speed is rejected as a GPS glitch.
  final double maxSpeedMps;

  /// Below this speed the user counts as standing still.
  final double autoPauseSpeedMps;

  /// How long the user must stand still before auto-pause kicks in.
  final Duration autoPauseDelay;
}
