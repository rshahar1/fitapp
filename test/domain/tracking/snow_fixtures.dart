import 'dart:math' as math;

import 'package:fitapp/domain/tracking/track_sample.dart';

/// Start of every synthetic ski day.
final snowStart = DateTime.utc(2026, 1, 10, 8);

enum LegKind { stand, lift, run, pause }

/// One scripted stretch of a synthetic ski day.
class SnowLeg {
  /// Standing or queueing for [seconds].
  const new stand(this.seconds)
    : kind = LegKind.stand,
      speed = 0,
      vertical = 0,
      stopAt = null,
      stopFor = 0,
      silentAt = null,
      silentFor = 0;

  /// Standing with tracking manually paused.
  const new pause(this.seconds)
    : kind = LegKind.pause,
      speed = 0,
      vertical = 0,
      stopAt = null,
      stopFor = 0,
      silentAt = null,
      silentFor = 0;

  /// A lift ride: [speed] m/s along the ground, climbing [vertical] m/s.
  /// It stands still for [stopFor] seconds from [stopAt]; no fixes arrive
  /// for [silentFor] seconds from [silentAt].
  const new lift(
    this.seconds, {
    this.speed = 4,
    this.vertical = 1,
    this.stopAt,
    this.stopFor = 0,
    this.silentAt,
    this.silentFor = 0,
  }) : kind = LegKind.lift;

  /// Riding down at about [speed] m/s, dropping [vertical] m/s.
  const new run(this.seconds, {this.speed = 12, this.vertical = 1.75})
    : kind = LegKind.run,
      stopAt = null,
      stopFor = 0,
      silentAt = null,
      silentFor = 0;

  final LegKind kind;
  final int seconds;
  final double speed;
  final double vertical;
  final int? stopAt;
  final int stopFor;
  final int? silentAt;
  final int silentFor;
}

/// A synthetic day with its true totals.
class SnowFixture {
  new({
    required this.samples,
    required this.rideSeconds,
    required this.liftSeconds,
    required this.restSeconds,
    required this.dropMeters,
    required this.rideMeters,
    required this.maxSpeedMps,
  });

  final List<TrackSample> samples;
  final double rideSeconds;
  final double liftSeconds;
  final double restSeconds;
  final double dropMeters;
  final double rideMeters;
  final double maxSpeedMps;
}

const _mPerDeg = 111194.93;
const _lat0 = 46.0;
const _lon0 = 7.0;

/// Slowly drifting noise, like real GPS error: standard deviation [sigma],
/// correlated from one second to the next.
class _Drift {
  new(this._rnd, this.sigma);

  static const _rho = 0.99;
  final math.Random _rnd;
  final double sigma;
  double _v = 0;

  double next() {
    return _v = _rho * _v + math.sqrt(1 - _rho * _rho) * sigma * _gauss(_rnd);
  }
}

double _gauss(math.Random r) {
  final u = 1 - r.nextDouble();
  final v = r.nextDouble();
  return math.sqrt(-2 * math.log(u)) * math.cos(2 * math.pi * v);
}

/// Builds one fix per second for [legs]. [doppler] false leaves the device
/// speed out; [altitude] false leaves the altitude out.
SnowFixture buildSnowDay(
  List<SnowLeg> legs, {
  int seed = 1,
  bool doppler = true,
  bool altitude = true,
}) {
  final rnd = math.Random(seed);
  final nx = _Drift(rnd, 3);
  final ny = _Drift(rnd, 3);
  final na = _Drift(rnd, 4);
  final samples = <TrackSample>[];
  var x = 0.0;
  var y = 0.0;
  var alt = 1500.0;
  var sec = 0;
  var ride = 0.0;
  var lift = 0.0;
  var rest = 0.0;
  var drop = 0.0;
  var rideMeters = 0.0;
  var maxSpeed = 0.0;

  void emit(double speed, {bool paused = false, bool silent = false}) {
    final ex = nx.next();
    final ey = ny.next();
    final ea = na.next();
    final shown = math.max(0, speed + 0.2 * _gauss(rnd)).toDouble();
    if (silent) return;
    final lat = _lat0 + (y + ey) / _mPerDeg;
    samples.add(
      TrackSample(
        t: snowStart.add(Duration(seconds: sec)),
        lat: lat,
        lon: _lon0 + (x + ex) / (_mPerDeg * math.cos(_lat0 * math.pi / 180)),
        alt: altitude ? alt + ea : null,
        accuracy: 6,
        speed: doppler ? shown : null,
        paused: paused,
      ),
    );
  }

  emit(0);
  for (final leg in legs) {
    for (var i = 0; i < leg.seconds; i++) {
      sec++;
      switch (leg.kind) {
        case LegKind.stand:
          rest++;
          emit(0);
        case LegKind.pause:
          emit(0, paused: true);
        case LegKind.lift:
          lift++;
          final stopped =
              leg.stopAt != null &&
              i >= leg.stopAt! &&
              i < leg.stopAt! + leg.stopFor;
          final silent =
              leg.silentAt != null &&
              i >= leg.silentAt! &&
              i < leg.silentAt! + leg.silentFor;
          if (!stopped) {
            y += leg.speed;
            alt += leg.vertical;
          }
          emit(stopped ? 0 : leg.speed, silent: silent);
        case LegKind.run:
          ride++;
          final ramp = math.min(1, (i + 1) / 5);
          final v =
              leg.speed * ramp * (1 + 0.2 * math.sin(2 * math.pi * i / 20));
          final heading = 0.5 * math.sin(2 * math.pi * i / 8);
          x += v * math.sin(heading);
          y -= v * math.cos(heading);
          alt -= leg.vertical;
          drop += leg.vertical;
          rideMeters += v;
          if (v > maxSpeed) maxSpeed = v;
          emit(v);
      }
    }
  }
  return SnowFixture(
    samples: samples,
    rideSeconds: ride,
    liftSeconds: lift,
    restSeconds: rest,
    dropMeters: drop,
    rideMeters: rideMeters,
    maxSpeedMps: maxSpeed,
  );
}

/// Lift, short stand at the top, run, queue.
const snowCycle = [
  SnowLeg.lift(420),
  SnowLeg.stand(40),
  SnowLeg.run(240),
  SnowLeg.stand(120),
];

/// Three lifts and three runs.
const plainDay = [SnowLeg.stand(60), ...snowCycle, ...snowCycle, ...snowCycle];

/// A day of [hours] hours of [snowCycle].
List<SnowLeg> longDay(int hours) => [
  const SnowLeg.stand(60),
  for (var i = 0; i < hours * 3600 ~/ 820; i++) ...snowCycle,
];
