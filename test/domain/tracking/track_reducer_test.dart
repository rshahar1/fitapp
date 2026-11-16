import 'dart:math' as math;

import 'package:fitapp/domain/tracking/geo.dart';
import 'package:fitapp/domain/tracking/track_profile.dart';
import 'package:fitapp/domain/tracking/track_reducer.dart';
import 'package:fitapp/domain/tracking/track_sample.dart';
import 'package:fitapp/domain/tracking/track_state.dart';
import 'package:fitapp/domain/tracking/track_summary.dart';
import 'package:flutter_test/flutter_test.dart';

import 'track_fixtures.dart';

const _mPerDegLon = 111194.93; // at the equator, R = 6371008.8 m
final _t0 = DateTime.utc(2026, 1, 1, 8);

TrackSample at(
  int sec,
  double meters, {
  double acc = 5,
  double? alt,
  bool paused = false,
}) => TrackSample(
  t: _t0.add(Duration(seconds: sec)),
  lat: 0,
  lon: meters / _mPerDegLon,
  accuracy: acc,
  alt: alt,
  paused: paused,
);

/// Samples every second for [seconds] at [speed] m/s, starting at [from]
/// seconds / [startMeters] metres (first sample is at from + 1).
List<TrackSample> run(
  int from,
  int seconds,
  double speed, [
  double startMeters = 0,
]) => [
  for (var i = 1; i <= seconds; i++) at(from + i, startMeters + speed * i),
];

TrackState fold(TrackState s, Iterable<TrackSample> samples, TrackProfile p) {
  var st = s;
  for (final x in samples) {
    st = accumulate(st, x, p);
  }
  return st;
}

void expectSame(TrackState a, TrackState b) {
  expect(a.distanceMeters, closeTo(b.distanceMeters, 1e-9));
  expect(a.movingSeconds, closeTo(b.movingSeconds, 1e-9));
  expect(a.manualPaused, b.manualPaused);
  expect(a.autoPaused, b.autoPaused);
  expect(a.pausedAt, b.pausedAt);
  expect(a.pausedTotal, b.pausedTotal);
  expect(a.completedSplits, b.completedSplits);
  expect(a.elevationGainMeters, closeTo(b.elevationGainMeters, 1e-9));
  expect(a.currentSpeedMps, closeTo(b.currentSpeedMps, 1e-9));
  expect(a.lastAccepted, same(b.lastAccepted));
  expect(a.pathMeters, closeTo(b.pathMeters, 1e-9));
}

void main() {
  const run_ = TrackProfile.running;
  const ride = TrackProfile.cycling;

  group('TrackProfile', () {
    test('forType', () {
      final r = TrackProfile.forType('running');
      expect(r.maxSpeedMps, 12);
      expect(r.autoPauseSpeedMps, 0.8);
      expect(r.autoPauseDelay, const Duration(seconds: 10));
      final c = TrackProfile.forType('cycling');
      expect(c.maxSpeedMps, 30);
      expect(c.autoPauseSpeedMps, 1.5);
      expect(c.autoPauseDelay, const Duration(seconds: 5));
      expect(() => TrackProfile.forType('pilates'), throwsArgumentError);
    });
  });

  group('TrackSample', () {
    test('withPaused copies every field', () {
      final s = TrackSample(
        t: _t0,
        lat: 1,
        lon: 2,
        accuracy: 3,
        alt: 4,
        speed: 5,
      );
      final p = s.withPaused(paused: true);
      expect(p.paused, isTrue);
      expect(
        [p.t, p.lat, p.lon, p.accuracy, p.alt, p.speed],
        [_t0, 1, 2, 3, 4, 5],
      );
    });
  });

  group('accumulate', () {
    test('snowboarding profile never auto-pauses', () {
      final p = TrackProfile.forType('snowboarding');
      expect(p.maxSpeedMps, 45);
      var s = accumulate(start(_t0), at(0, 0), p);
      for (var i = 1; i <= 60; i++) {
        s = accumulate(s, at(i, 0), p);
        expect(s.autoPaused, isFalse);
      }
      expect(s.movingSeconds, greaterThan(0));
    });

    test('first fix becomes the anchor, no distance', () {
      final s = accumulate(start(_t0), at(0, 0), run_);
      expect(s.distanceMeters, 0);
      expect(s.lastAccepted, isNotNull);
      expect(s.avgPaceSecPerKm, isNull);
      expect(s.avgSpeedMps, isNull);
      expect(s.currentPaceSecPerKm, isNull);
      expect(s.lastSplitSeconds, isNull);
    });

    test('sums distance and moving time at a steady pace', () {
      final s = fold(start(_t0), [at(0, 0), ...run(0, 60, 3)], run_);
      expect(s.distanceMeters, closeTo(180, 0.5));
      expect(s.movingSeconds, closeTo(60, 1e-9));
      expect(s.currentSpeedMps, closeTo(3, 0.01));
      expect(s.avgSpeedMps, closeTo(3, 0.01));
      expect(s.avgPaceSecPerKm, closeTo(333.3, 0.5));
      expect(s.currentPaceSecPerKm, closeTo(333.3, 1));
    });

    test('rejects accuracy worse than 20 m, accepts exactly 20 m', () {
      var s = accumulate(start(_t0), at(0, 0), run_);
      s = accumulate(s, at(1, 3, acc: 20.1), run_);
      expect(s.distanceMeters, 0);
      expect(s.lastAccepted!.t, _t0);
      s = accumulate(s, at(2, 6, acc: 20), run_);
      expect(s.distanceMeters, closeTo(6, 0.1));
    });

    test('rejects a first fix with poor accuracy', () {
      final s = accumulate(start(_t0), at(0, 0, acc: 50), run_);
      expect(s.lastAccepted, isNull);
    });

    test('rejects a segment implying more than the profile max speed', () {
      var s = fold(start(_t0), [at(0, 0), at(1, 3)], run_);
      final before = s;
      s = accumulate(s, at(2, 303), run_); // 300 m in 1 s
      expect(s, same(before));
      s = accumulate(s, at(3, 9), run_);
      expect(s.distanceMeters, closeTo(9, 0.1));
      // 20 m/s is fine for a bike, too fast for a runner.
      final a = fold(start(_t0), [at(0, 0), at(1, 20)], ride);
      final b = fold(start(_t0), [at(0, 0), at(1, 20)], run_);
      expect(a.distanceMeters, closeTo(20, 0.1));
      expect(b.distanceMeters, 0);
    });

    test('rejects out-of-order and duplicate timestamps', () {
      var s = fold(start(_t0), [at(0, 0), at(5, 15)], run_);
      final before = s;
      s = accumulate(s, at(5, 16), run_);
      s = accumulate(s, at(4, 12), run_);
      expect(s, same(before));
    });

    test('splits: one per full km with moving seconds, interpolated', () {
      // 4 m/s: km at 250 s, 500 s; 2.2 km total.
      final s = fold(start(_t0), [at(0, 0), ...run(0, 550, 4, 0)], run_);
      expect(s.distanceMeters, closeTo(2200, 1));
      expect(s.completedSplits, [250, 250]);
      expect(s.lastSplitSeconds, 250);
    });

    test('split boundary falling inside a segment is interpolated', () {
      // 7 m/s sampled every 3 s: boundary mid-segment.
      var s = accumulate(start(_t0), at(0, 0), ride);
      for (var i = 1; i <= 50; i++) {
        s = accumulate(s, at(i * 3, 21.0 * i), ride);
      }
      // 1050 m, boundary at 142.857 s.
      expect(s.completedSplits, [143]);
    });

    test('several kilometres in a single segment', () {
      final s = fold(
        start(_t0),
        [at(0, 0), at(300, 2500, acc: 5)],
        const TrackProfile(
          maxSpeedMps: 100,
          autoPauseSpeedMps: 0.8,
          autoPauseDelay: Duration(seconds: 10),
        ),
      );
      expect(s.completedSplits, hasLength(2));
    });

    test('current speed uses only the last 30 s', () {
      final s = fold(start(_t0), [
        at(0, 0),
        ...run(0, 60, 2, 0),
        ...run(60, 60, 4, 120),
      ], run_);
      expect(s.currentSpeedMps, closeTo(4, 0.01));
    });

    test('elevation gain ignores climbs under 3 m, counts real climbs', () {
      TrackSample a(int i, double alt) => at(i, i * 3.0, alt: alt);
      var s = accumulate(start(_t0), a(0, 100), run_);
      // Noise within +-2.9 m: nothing.
      for (final (i, alt) in [(1, 102.9), (2, 100.0), (3, 97.2), (4, 100.0)]) {
        s = accumulate(s, a(i, alt), run_);
      }
      expect(s.elevationGainMeters, 0);
      // Steady climb 100 -> 110 in 1 m steps.
      for (var i = 0; i <= 10; i++) {
        s = accumulate(s, a(5 + i, 100.0 + i), run_);
      }
      expect(s.elevationGainMeters, closeTo(9, 1e-9)); // 3 steps of 3 m
      // Descent resets the reference without adding gain.
      s = accumulate(s, a(20, 104), run_);
      s = accumulate(s, a(21, 108), run_);
      expect(s.elevationGainMeters, closeTo(13, 1e-9));
    });

    test('fixes without altitude do not touch elevation', () {
      var s = accumulate(start(_t0), at(0, 0, alt: 10), run_);
      s = accumulate(s, at(1, 3), run_);
      s = accumulate(s, at(2, 6, alt: 20), run_);
      expect(s.elevationGainMeters, closeTo(10, 1e-9));
      // Reference set by the first altitude when the anchor had none.
      var t = accumulate(start(_t0), at(0, 0), run_);
      t = accumulate(t, at(1, 3, alt: 50), run_);
      t = accumulate(t, at(2, 6, alt: 55), run_);
      expect(t.elevationGainMeters, closeTo(5, 1e-9));
    });
  });

  group('manual pause', () {
    test('pause/resume are idempotent and elapsed excludes the pause', () {
      var s = start(_t0);
      expect(elapsedAt(s, _t0.add(const Duration(seconds: 30))).inSeconds, 30);
      s = pause(s, _t0.add(const Duration(seconds: 30)));
      expect(pause(s, _t0.add(const Duration(seconds: 40))), same(s));
      expect(elapsedAt(s, _t0.add(const Duration(seconds: 50))).inSeconds, 30);
      s = resume(s, _t0.add(const Duration(seconds: 60)));
      expect(resume(s, _t0.add(const Duration(seconds: 70))), same(s));
      expect(s.pausedTotal.inSeconds, 30);
      expect(elapsedAt(s, _t0.add(const Duration(seconds: 90))).inSeconds, 60);
      expect(
        elapsedAt(s, _t0.subtract(const Duration(seconds: 5))),
        Duration.zero,
      );
    });

    test('points while paused move the anchor but add no distance', () {
      var s = fold(start(_t0), [at(0, 0), ...run(0, 10, 3, 0)], run_);
      s = pause(s, at(10, 0).t);
      s = fold(s, [
        for (var i = 11; i <= 40; i++) at(i, 30.0 + 3 * (i - 10)),
      ], run_);
      expect(s.distanceMeters, closeTo(30, 0.1));
      expect(s.movingSeconds, closeTo(10, 1e-9));
      expect(s.currentSpeedMps, closeTo(3, 0.5));
      s = resume(s, at(40, 0).t);
      s = fold(s, run(40, 10, 3, 120), run_);
      // 10 s more at 3 m/s from the paused anchor: no teleport counted.
      expect(s.distanceMeters, closeTo(60, 0.3));
      expect(s.movingSeconds, closeTo(20, 1e-9));
      expect(s.manualPaused, isFalse);
    });

    test('resume before any fix leaves the window empty', () {
      var s = pause(start(_t0), _t0);
      s = resume(s, _t0.add(const Duration(seconds: 5)));
      expect(s.window, isEmpty);
      expect(s.manualPaused, isFalse);
    });
  });

  group('auto-pause', () {
    List<TrackSample> stopAndGo(double speed) => [
      at(0, 0),
      ...run(0, 60, speed, 0), // moving
      for (var i = 61; i <= 120; i++) at(i, speed * 60), // standing 60 s
      ...run(120, 60, speed, speed * 60),
    ];

    test('running: standing >= 10 s excludes the stop from moving time', () {
      final all = stopAndGo(3);
      var s = start(_t0);
      var sawAuto = false;
      for (final p in all) {
        s = accumulate(s, p, run_);
        sawAuto |= s.autoPaused;
      }
      expect(sawAuto, isTrue);
      expect(s.autoPaused, isFalse);
      expect(s.distanceMeters, closeTo(360, 5)); // restart lag loses ~1 s
      // 120 s of motion; the standing period (60 s) is excluded within
      // the detection lag (5 s window + 1 s restart).
      expect(s.movingSeconds, inInclusiveRange(118, 126));
      expect(s.currentSpeedMps, greaterThan(2));
    });

    test('state during the stop: auto-paused, speed 0, nothing added', () {
      var s = fold(start(_t0), stopAndGo(3).take(61 + 30), run_);
      expect(s.autoPaused, isTrue);
      expect(s.currentSpeedMps, 0);
      final d = s.distanceMeters;
      final m = s.movingSeconds;
      s = accumulate(s, at(92, 180), run_);
      expect(s.distanceMeters, d);
      expect(s.movingSeconds, m);
    });

    test('a short slow stretch below the delay still counts as moving', () {
      final s = fold(start(_t0), [
        at(0, 0),
        ...run(0, 30, 3, 0),
        for (var i = 31; i <= 36; i++) at(i, 90), // 6 s stop
        ...run(36, 30, 3, 90),
      ], run_);
      expect(s.autoPaused, isFalse);
      expect(s.movingSeconds, closeTo(66, 1e-9));
    });

    test('cycling profile pauses after 5 s below 1.5 m/s', () {
      final s = fold(start(_t0), [
        at(0, 0),
        ...run(0, 40, 7, 0),
        for (var i = 41; i <= 60; i++) at(i, 280),
      ], ride);
      expect(s.autoPaused, isTrue);
      expect(s.movingSeconds, closeTo(40, 3));
    });

    test('split during auto-pause tail never goes negative', () {
      final s = fold(start(_t0), [
        at(0, 0),
        ...run(0, 143, 7, 0), // 1001 m
        for (var i = 144; i <= 200; i++) at(i, 1001),
        ...run(200, 200, 7, 1001),
      ], ride);
      expect(s.completedSplits.every((x) => x >= 0), isTrue);
    });
  });

  group('replay', () {
    test('flags: replay equals incremental, with pause and resume', () {
      final raw = [at(0, 0), ...run(0, 100, 3, 0)];
      // Pause at sample 40, resume at sample 70.
      final flagged = [
        for (var i = 0; i < raw.length; i++)
          raw[i].withPaused(paused: i >= 40 && i < 70),
      ];
      var inc = start(_t0);
      for (var i = 0; i < flagged.length; i++) {
        if (i == 40) inc = pause(inc, flagged[i].t);
        if (i == 70) inc = resume(inc, flagged[i].t);
        inc = accumulate(inc, flagged[i], run_);
      }
      expectSame(replay(_t0, flagged, run_), inc);
    });

    test('explicit intervals reproduce pauses between fixes exactly', () {
      final raw = [at(0, 0), ...run(0, 100, 3, 0)];
      final pauseAt = _t0.add(const Duration(milliseconds: 39500));
      final resumeAt = _t0.add(const Duration(milliseconds: 69200));
      var inc = start(_t0);
      for (var i = 0; i < raw.length; i++) {
        if (i == 40) inc = pause(inc, pauseAt);
        if (i == 70) inc = resume(inc, resumeAt);
        inc = accumulate(inc, raw[i], run_);
      }
      final rep = replay(
        _t0,
        raw,
        run_,
        pauses: [PauseInterval(start: pauseAt, end: resumeAt)],
      );
      expectSame(rep, inc);
      expect(rep.pausedTotal, const Duration(milliseconds: 29700));
    });

    test('an open pause at the end leaves the state paused', () {
      final raw = [at(0, 0), ...run(0, 20, 3, 0)];
      final flagged = [
        for (var i = 0; i < raw.length; i++) raw[i].withPaused(paused: i >= 15),
      ];
      final s = replay(_t0, flagged, run_);
      expect(s.manualPaused, isTrue);
      expect(s.pausedAt, flagged[15].t);
    });

    test('pause without any later samples still applies', () {
      final s = replay(
        _t0,
        [at(0, 0)],
        run_,
        pauses: [
          PauseInterval(
            start: _t0.add(const Duration(seconds: 5)),
            end: _t0.add(const Duration(seconds: 9)),
          ),
        ],
      );
      expect(s.manualPaused, isFalse);
      expect(s.pausedTotal.inSeconds, 4);
    });

    test('no samples gives the start state', () {
      expect(replay(_t0, const [], run_).lastAccepted, isNull);
    });

    test('acceptedSamples drops rejected fixes and respects pauses', () {
      final samples = [
        at(0, 0),
        at(1, 3),
        at(2, 6, acc: 40),
        at(3, 400), // spike
        at(4, 12),
      ];
      final acc = acceptedSamples(_t0, samples, run_);
      expect(acc.map((s) => s.t.difference(_t0).inSeconds), [0, 1, 4]);
      final flagged = [
        at(0, 0),
        at(1, 3, paused: true),
        at(2, 6, paused: true),
        at(3, 9),
      ];
      expect(acceptedSamples(_t0, flagged, run_), hasLength(4));
    });
  });

  group('fixtures', () {
    test('5 km run: distance within 1%, pace and splits', () {
      final f = loadTrack('run_5k');
      final s = replay(
        fixtureStart,
        f.samples,
        TrackProfile.forType('running'),
      );
      expect(f.referenceMeters, closeTo(5000, 1));
      expect(
        s.distanceMeters,
        closeTo(f.referenceMeters, f.referenceMeters / 100),
      );
      expect(s.completedSplits, hasLength(5));
      for (final sp in s.completedSplits) {
        expect(sp, inInclusiveRange(300, 340)); // ~5:20/km
      }
      expect(s.avgPaceSecPerKm, closeTo(320, 5));
      expect(s.autoPaused, isFalse);
    });

    test('30 km ride: distance within 1%, 30 splits', () {
      final f = loadTrack('ride_30k');
      final s = replay(
        fixtureStart,
        f.samples,
        TrackProfile.forType('cycling'),
      );
      expect(
        s.distanceMeters,
        closeTo(f.referenceMeters, f.referenceMeters / 100),
      );
      expect(s.completedSplits, hasLength(30));
      expect(s.avgSpeedMps! * 3.6, closeTo(25, 0.5));
    });

    test('run with stop, spike and accuracy-40 fixes', () {
      final f = loadTrack('run_stop_spike');
      const p = TrackProfile.running;
      final s = replay(fixtureStart, f.samples, p);
      expect(
        s.distanceMeters,
        closeTo(f.referenceMeters, f.referenceMeters / 100),
      );
      final accepted = acceptedSamples(fixtureStart, f.samples, p);
      final rejected = f.samples.length - accepted.length;
      // 5 poor-accuracy fixes + 1 spike (the spike is a single fix).
      expect(rejected, 6);
      expect(accepted.every((x) => x.accuracy <= 20), isTrue);
      // The 60 s standing stop is excluded from moving time.
      final total = f.samples.last.t.difference(fixtureStart).inSeconds;
      expect(s.movingSeconds, closeTo(total - 60, 8));
      expect(s.movingSeconds, lessThan(total - 45));
    });
  });

  group('summarize', () {
    test('rounds, keeps splits and encodes a simplified route', () {
      final f = loadTrack('run_5k');
      const p = TrackProfile.running;
      final s = replay(fixtureStart, f.samples, p);
      final acc = acceptedSamples(fixtureStart, f.samples, p);
      final sum = summarize(s, acc);
      expect(sum.distanceMeters, s.distanceMeters.round());
      expect(sum.durationMinutes, 27); // 1600 s
      expect(sum.movingSeconds, s.movingSeconds.round());
      expect(sum.elevationGainMeters, s.elevationGainMeters.round());
      expect(sum.splits, s.completedSplits);
      final pts = decodePolyline(sum.route);
      expect(pts.length, lessThan(acc.length));
      expect(pts.first.lat, closeTo(acc.first.lat, 1e-5));
      expect(pts.last.lon, closeTo(acc.last.lon, 1e-5));
    });

    test('explicit end time and minimum of one minute', () {
      final s = replay(_t0, [at(0, 0), at(1, 3)], run_);
      expect(summarize(s, [at(0, 0), at(1, 3)]).durationMinutes, 1);
      final longer = summarize(s, [
        at(0, 0),
        at(1, 3),
      ], endedAt: _t0.add(const Duration(minutes: 20, seconds: 40)));
      expect(longer.durationMinutes, 21);
    });

    test('empty track', () {
      final sum = summarize(start(_t0), const []);
      expect(sum.durationMinutes, 1);
      expect(sum.route, '');
      expect(sum.distanceMeters, 0);
    });

    test('an hour of 1 Hz samples encodes to at most 50 KB', () {
      // Winding path: ~3.5 m/s with a weaving heading.
      final samples = <TrackSample>[];
      var lat = 32.0;
      var lon = 34.0;
      for (var i = 0; i < 3600; i++) {
        lat += 3.5 * math.cos(i / 50) / 111195 * 1.0;
        lon += 3.5 * math.sin(i / 31) / 94000;
        samples.add(
          TrackSample(
            t: _t0.add(Duration(seconds: i)),
            lat: lat,
            lon: lon,
            accuracy: 5,
          ),
        );
      }
      final s = replay(_t0, samples, run_);
      final sum = summarize(s, samples);
      expect(sum.route.length, lessThanOrEqualTo(50 * 1024));
      expect(sum.durationMinutes, 60);
    });
  });
}
