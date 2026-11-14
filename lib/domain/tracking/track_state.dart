/// Immutable live-tracking metrics (feature 010). Pure Dart.
library;

import 'package:fitapp/domain/tracking/track_sample.dart';
import 'package:meta/meta.dart';

/// A point on the cumulative path, used for windowed speeds.
typedef PathMark = ({DateTime t, double d});

/// Metrics of a live track. Built by the functions in `track_reducer.dart`;
/// fields marked internal exist only so the reducer stays a pure function.
@immutable
class TrackState {
  const new({
    required this.startedAt,
    this.distanceMeters = 0,
    this.movingSeconds = 0,
    this.manualPaused = false,
    this.autoPaused = false,
    this.pausedAt,
    this.pausedTotal = Duration.zero,
    this.completedSplits = const [],
    this.elevationGainMeters = 0,
    this.currentSpeedMps = 0,
    this.lastAccepted,
    this.pathMeters = 0,
    this.window = const [],
    this.slowSince,
    this.slowMovingSeconds = 0,
    this.lastSplitMoving = 0,
    this.elevationRef,
  });

  final DateTime startedAt;

  /// Distance counted while moving (not paused), in metres.
  final double distanceMeters;

  /// Time spent moving (excludes manual and auto pauses), in seconds.
  final double movingSeconds;
  final bool manualPaused;
  final bool autoPaused;

  /// When the current manual pause began.
  final DateTime? pausedAt;

  /// Total completed manual pause time.
  final Duration pausedTotal;

  /// Moving seconds of each completed full kilometre.
  final List<int> completedSplits;

  /// Ascent in metres with 3 m hysteresis.
  final double elevationGainMeters;

  /// Speed over the last 30 s, in m/s (0 while paused).
  final double currentSpeedMps;

  /// The last accepted fix; the anchor for the next segment.
  final TrackSample? lastAccepted;

  /// Internal: raw path length including auto-paused movement.
  final double pathMeters;

  /// Internal: path marks of the last 30 s.
  final List<PathMark> window;

  /// Internal: when the current standing-still stretch began.
  final DateTime? slowSince;

  /// Internal: moving seconds accrued during the current standing stretch.
  final double slowMovingSeconds;

  /// Internal: moving seconds at the last split boundary.
  final double lastSplitMoving;

  /// Internal: altitude reference for the elevation hysteresis.
  final double? elevationRef;

  /// Average speed while moving, in m/s; null before any movement.
  double? get avgSpeedMps => movingSeconds > 0 && distanceMeters > 0
      ? distanceMeters / movingSeconds
      : null;

  /// Average pace while moving, in seconds per km; null before any movement.
  double? get avgPaceSecPerKm =>
      distanceMeters > 0 ? movingSeconds / (distanceMeters / 1000) : null;

  /// Current pace in seconds per km; null when practically standing.
  double? get currentPaceSecPerKm =>
      currentSpeedMps > 0.1 ? 1000 / currentSpeedMps : null;

  /// Seconds of the last completed kilometre, if any.
  int? get lastSplitSeconds =>
      completedSplits.isEmpty ? null : completedSplits.last;

  /// A copy with the given fields replaced. Use [clearPausedAt] and
  /// [clearSlowSince] to set those fields to null.
  TrackState copyWith({
    double? distanceMeters,
    double? movingSeconds,
    bool? manualPaused,
    bool? autoPaused,
    DateTime? pausedAt,
    bool clearPausedAt = false,
    Duration? pausedTotal,
    List<int>? completedSplits,
    double? elevationGainMeters,
    double? currentSpeedMps,
    TrackSample? lastAccepted,
    double? pathMeters,
    List<PathMark>? window,
    DateTime? slowSince,
    bool clearSlowSince = false,
    double? slowMovingSeconds,
    double? lastSplitMoving,
    double? elevationRef,
  }) => TrackState(
    startedAt: startedAt,
    distanceMeters: distanceMeters ?? this.distanceMeters,
    movingSeconds: movingSeconds ?? this.movingSeconds,
    manualPaused: manualPaused ?? this.manualPaused,
    autoPaused: autoPaused ?? this.autoPaused,
    pausedAt: clearPausedAt ? null : pausedAt ?? this.pausedAt,
    pausedTotal: pausedTotal ?? this.pausedTotal,
    completedSplits: completedSplits ?? this.completedSplits,
    elevationGainMeters: elevationGainMeters ?? this.elevationGainMeters,
    currentSpeedMps: currentSpeedMps ?? this.currentSpeedMps,
    lastAccepted: lastAccepted ?? this.lastAccepted,
    pathMeters: pathMeters ?? this.pathMeters,
    window: window ?? this.window,
    slowSince: clearSlowSince ? null : slowSince ?? this.slowSince,
    slowMovingSeconds: slowMovingSeconds ?? this.slowMovingSeconds,
    lastSplitMoving: lastSplitMoving ?? this.lastSplitMoving,
    elevationRef: elevationRef ?? this.elevationRef,
  );
}
