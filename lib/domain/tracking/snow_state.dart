/// Immutable live snowboarding metrics (feature 017). Pure Dart.
library;

import 'package:fitapp/domain/tracking/track_sample.dart';
import 'package:meta/meta.dart';

/// What the rider is doing.
enum SnowKind { run, lift, rest }

/// A timestamped value in one of the reducer's trailing windows.
typedef SnowMark = ({DateTime t, double v});

/// A stretch of one [SnowKind]. Fix indices count the fixes fed to the snow
/// reducer; neighbouring segments share their boundary fix.
@immutable
class SnowSegment {
  const new({
    required this.kind,
    required this.firstIndex,
    required this.lastIndex,
    required this.start,
    required this.end,
    this.distanceMeters = 0,
    this.ascentMeters = 0,
    this.descentMeters = 0,
    this.maxSpeedMps = 0,
    this.startAlt,
    this.endAlt,
    this.altRef,
  });

  /// A zero-length segment at fix [index].
  const new at(this.kind, int index, DateTime t, double? alt)
    : firstIndex = index,
      lastIndex = index,
      start = t,
      end = t,
      distanceMeters = 0,
      ascentMeters = 0,
      descentMeters = 0,
      maxSpeedMps = 0,
      startAlt = alt,
      endAlt = alt,
      altRef = alt;

  final SnowKind kind;
  final int firstIndex;
  final int lastIndex;
  final DateTime start;
  final DateTime end;

  /// Path length between the segment's fixes, in metres.
  final double distanceMeters;

  /// Climb and drop of the smoothed altitude, with hysteresis, in metres.
  final double ascentMeters;
  final double descentMeters;

  /// Highest spike-filtered speed, in m/s.
  final double maxSpeedMps;

  /// Smoothed altitude at the first and last fix, if known.
  final double? startAlt;
  final double? endAlt;

  /// Internal: altitude reference of the hysteresis.
  final double? altRef;

  double get seconds => end.difference(start).inMicroseconds / 1e6;

  /// Drop of a run, gain of a lift, 0 for a rest.
  double get verticalMeters => switch (kind) {
    SnowKind.run => descentMeters,
    SnowKind.lift => ascentMeters,
    SnowKind.rest => 0,
  };

  /// Start altitude minus end altitude (positive downhill); 0 when unknown.
  double get netDropMeters =>
      startAlt == null || endAlt == null ? 0 : startAlt! - endAlt!;

  /// This segment extended to fix [index] at [t], [meters] further on.
  SnowSegment step({
    required int index,
    required DateTime t,
    required double meters,
    required double? alt,
    required double speed,
    required double hysteresis,
  }) {
    var up = ascentMeters;
    var down = descentMeters;
    var ref = altRef;
    if (alt != null) {
      if (ref == null) {
        ref = alt;
      } else if (alt - ref >= hysteresis) {
        up += alt - ref;
        ref = alt;
      } else if (ref - alt >= hysteresis) {
        down += ref - alt;
        ref = alt;
      }
    }
    return SnowSegment(
      kind: kind,
      firstIndex: firstIndex,
      lastIndex: index,
      start: start,
      end: t,
      distanceMeters: distanceMeters + meters,
      ascentMeters: up,
      descentMeters: down,
      maxSpeedMps: speed > maxSpeedMps ? speed : maxSpeedMps,
      startAlt: startAlt ?? alt,
      endAlt: alt ?? endAlt,
      altRef: ref,
    );
  }

  /// This segment with the altitude change still below the hysteresis added,
  /// as stored once the segment is over.
  SnowSegment sealed() {
    final ref = altRef;
    final last = endAlt;
    if (ref == null || last == null || ref == last) return this;
    return copyWith(
      ascentMeters: last > ref ? ascentMeters + (last - ref) : ascentMeters,
      descentMeters: ref > last ? descentMeters + (ref - last) : descentMeters,
      altRef: last,
    );
  }

  /// This segment ending at altitude [alt] instead: the smoothed altitude
  /// lags, so the height where a run stopped is only known a little later.
  SnowSegment settledAt(double alt) {
    final ref = altRef ?? alt;
    return SnowSegment(
      kind: kind,
      firstIndex: firstIndex,
      lastIndex: lastIndex,
      start: start,
      end: end,
      distanceMeters: distanceMeters,
      ascentMeters: alt > ref ? ascentMeters + (alt - ref) : ascentMeters,
      descentMeters: ref > alt ? descentMeters + (ref - alt) : descentMeters,
      maxSpeedMps: maxSpeedMps,
      startAlt: startAlt ?? alt,
      endAlt: alt,
      altRef: alt,
    );
  }

  SnowSegment copyWith({
    SnowKind? kind,
    int? firstIndex,
    DateTime? start,
    double? distanceMeters,
    double? ascentMeters,
    double? descentMeters,
    double? maxSpeedMps,
    double? startAlt,
    double? altRef,
  }) => SnowSegment(
    kind: kind ?? this.kind,
    firstIndex: firstIndex ?? this.firstIndex,
    lastIndex: lastIndex,
    start: start ?? this.start,
    end: end,
    distanceMeters: distanceMeters ?? this.distanceMeters,
    ascentMeters: ascentMeters ?? this.ascentMeters,
    descentMeters: descentMeters ?? this.descentMeters,
    maxSpeedMps: maxSpeedMps ?? this.maxSpeedMps,
    startAlt: startAlt ?? this.startAlt,
    endAlt: endAlt,
    altRef: altRef ?? this.altRef,
  );
}

/// Snowboarding metrics of a live track. Built by the functions in
/// `snow_reducer.dart`; fields marked internal exist only so the reducer
/// stays a pure function.
@immutable
class SnowState {
  const new({
    this.segments = const [],
    this.current,
    this.candidate,
    this.beforeCandidate,
    this.liftMark,
    this.moveMark,
    this.count = 0,
    this.last,
    this.pathMeters = 0,
    this.speedWindow = const [],
    this.altWindow = const [],
    this.smoothWindow = const [],
    this.recentSpeeds = const [],
    this.speedMps = 0,
    this.closedRideSeconds = 0,
    this.closedLiftSeconds = 0,
    this.closedRestSeconds = 0,
    this.closedRideMeters = 0,
    this.closedDropMeters = 0,
    this.closedMaxSpeedMps = 0,
    this.closedRuns = 0,
    this.descentDropMeters = 0,
  });

  /// Finished segments, in time order.
  final List<SnowSegment> segments;

  /// The segment in progress; null before the first fix and while paused.
  final SnowSegment? current;

  /// Internal: a possible next segment, not confirmed yet.
  final SnowSegment? candidate;

  /// Internal: [current] as it was when [candidate] opened.
  final SnowSegment? beforeCandidate;

  /// Internal: the current lift as of its last climbing fix.
  final SnowSegment? liftMark;

  /// Internal: the current rest as of the fix where movement began.
  final SnowSegment? moveMark;

  /// Number of fixes fed so far.
  final int count;

  /// Internal: the last fix fed; null right after a pause.
  final TrackSample? last;

  /// Internal: cumulative path length, for windowed speed.
  final double pathMeters;

  /// Internal: path marks of the speed window.
  final List<SnowMark> speedWindow;

  /// Internal: raw altitudes of the smoothing window.
  final List<SnowMark> altWindow;

  /// Internal: smoothed altitudes of the vertical-rate window.
  final List<SnowMark> smoothWindow;

  /// Internal: the last speeds, for the spike filter.
  final List<double> recentSpeeds;

  /// Internal: speed at the last fix, in m/s.
  final double speedMps;

  /// Internal: totals of [segments].
  final double closedRideSeconds;
  final double closedLiftSeconds;
  final double closedRestSeconds;
  final double closedRideMeters;
  final double closedDropMeters;
  final double closedMaxSpeedMps;

  /// Internal: runs counted before the current descent.
  final int closedRuns;

  /// Internal: drop of the finished run segments since the last lift.
  final double descentDropMeters;

  /// The confirmed activity right now; rest before the first fix.
  SnowKind get kind => current?.kind ?? SnowKind.rest;

  double _open(SnowKind k, double Function(SnowSegment s) f) {
    final c = current;
    return c != null && c.kind == k ? f(c) : 0;
  }

  /// Time riding down, in seconds.
  double get rideSeconds =>
      closedRideSeconds + _open(SnowKind.run, (s) => s.seconds);

  /// Time on lifts, in seconds.
  double get liftSeconds =>
      closedLiftSeconds + _open(SnowKind.lift, (s) => s.seconds);

  /// Time standing or queueing, in seconds.
  double get restSeconds =>
      closedRestSeconds + _open(SnowKind.rest, (s) => s.seconds);

  /// Distance covered riding down, in metres.
  double get rideMeters =>
      closedRideMeters + _open(SnowKind.run, (s) => s.distanceMeters);

  /// Vertical drop of all runs, in metres.
  double get dropMeters =>
      closedDropMeters + _open(SnowKind.run, (s) => s.sealed().descentMeters);

  /// Highest spike-filtered speed while riding, in m/s.
  double get maxSpeedMps {
    final open = _open(SnowKind.run, (s) => s.maxSpeedMps);
    return open > closedMaxSpeedMps ? open : closedMaxSpeedMps;
  }

  /// Average speed while riding, in m/s; null before any riding.
  double? get avgSpeedMps =>
      rideSeconds > 0 && rideMeters > 0 ? rideMeters / rideSeconds : null;

  /// Speed right now, in m/s; 0 when practically standing.
  double get currentSpeedMps => speedMps < 1 ? 0 : speedMps;

  /// Drop of the descent in progress (since the last lift), in metres.
  double get currentDescentDropMeters =>
      descentDropMeters + _open(SnowKind.run, (s) => s.sealed().descentMeters);
}
