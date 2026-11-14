/// One GPS fix (feature 010). Pure Dart (constitution principle II).
library;

import 'package:meta/meta.dart';

/// A GPS fix. [t] must be UTC. [paused] marks a fix received while the user
/// had manually paused; the data layer persists it so the state can be
/// replayed exactly.
@immutable
class TrackSample {
  const new({
    required this.t,
    required this.lat,
    required this.lon,
    required this.accuracy,
    this.alt,
    this.speed,
    this.paused = false,
  });

  final DateTime t;
  final double lat;
  final double lon;

  /// Altitude in metres, if known.
  final double? alt;

  /// Horizontal accuracy in metres (smaller is better).
  final double accuracy;

  /// Device-reported speed in m/s, if known.
  final double? speed;

  /// Whether the fix arrived while manually paused.
  final bool paused;

  /// A copy with [paused] replaced.
  TrackSample withPaused({required bool paused}) => TrackSample(
    t: t,
    lat: lat,
    lon: lon,
    accuracy: accuracy,
    alt: alt,
    speed: speed,
    paused: paused,
  );
}
