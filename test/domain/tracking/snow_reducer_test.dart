import 'package:fitapp/domain/tracking/snow_reducer.dart';
import 'package:fitapp/domain/tracking/snow_state.dart';
import 'package:fitapp/domain/tracking/track_sample.dart';
import 'package:flutter_test/flutter_test.dart';

import 'snow_fixtures.dart';

SnowState fold(Iterable<TrackSample> samples) => replaySnow(samples);

/// [actual] within 5% of [reference].
void within5(num actual, num reference, String what) => expect(
  actual,
  closeTo(reference, reference.abs() * 0.05),
  reason: '$what: $actual vs reference $reference',
);

void expectTotals(SnowState s, SnowFixture f, {required int runs}) {
  expect(snowRunCount(s), runs, reason: 'run count');
  within5(s.rideSeconds, f.rideSeconds, 'ride seconds');
  within5(s.liftSeconds, f.liftSeconds, 'lift seconds');
  within5(s.restSeconds, f.restSeconds, 'rest seconds');
  within5(s.dropMeters, f.dropMeters, 'drop');
  within5(s.maxSpeedMps, f.maxSpeedMps, 'max speed');
  within5(s.rideMeters, f.rideMeters, 'ride distance');
}

List<SnowKind> kinds(SnowState s) => [
  for (final seg in pauseSnow(s).segments) seg.kind,
];

String describe(SnowState s) =>
    [for (final seg in pauseSnow(s).segments) _line(seg)].join(' | ');

String _line(SnowSegment seg) =>
    '${seg.kind.name} ${seg.start.difference(snowStart).inSeconds}'
    '+${seg.seconds.round()}s v${seg.verticalMeters.round()}';

TrackSample fix(int sec, {double meters = 0, double? alt, double? speed}) =>
    TrackSample(
      t: snowStart.add(Duration(seconds: sec)),
      lat: 46 + meters / 111194.93,
      lon: 7,
      alt: alt,
      accuracy: 5,
      speed: speed,
    );

void main() {
  group('empty and first fix', () {
    test('a fresh state rests with zero totals', () {
      final s = startSnow();
      expect(s.kind, SnowKind.rest);
      expect(s.rideSeconds, 0);
      expect(s.liftSeconds, 0);
      expect(s.restSeconds, 0);
      expect(s.dropMeters, 0);
      expect(s.maxSpeedMps, 0);
      expect(s.avgSpeedMps, isNull);
      expect(s.currentSpeedMps, 0);
      expect(snowRunCount(s), 0);
      expect(pauseSnow(s), same(s));
    });

    test('the first fix opens a rest', () {
      final s = accumulateSnow(startSnow(), fix(0, alt: 1500, speed: 0));
      expect(s.kind, SnowKind.rest);
      expect(s.count, 1);
      expect(s.current!.firstIndex, 0);
    });

    test('a fix not after the previous one is ignored', () {
      final a = accumulateSnow(startSnow(), fix(5, alt: 1500, speed: 0));
      expect(accumulateSnow(a, fix(5, alt: 1500, speed: 0)), same(a));
      expect(accumulateSnow(a, fix(4, alt: 1500, speed: 0)), same(a));
    });
  });

  group('plain day', () {
    final f = buildSnowDay(plainDay);
    final s = fold(f.samples);

    test('totals match the reference', () {
      expectTotals(s, f, runs: 3);
      expect(s.avgSpeedMps, closeTo(f.rideMeters / f.rideSeconds, 0.6));
    });

    test('segments alternate lift, rest, run, rest', () {
      expect(kinds(s), [
        SnowKind.rest,
        for (var i = 0; i < 3; i++) ...[
          SnowKind.lift,
          SnowKind.rest,
          SnowKind.run,
          SnowKind.rest,
        ],
      ], reason: describe(s));
    });

    test('segments tile the day and share their boundary fixes', () {
      final segs = pauseSnow(s).segments;
      for (var i = 1; i < segs.length; i++) {
        expect(segs[i].firstIndex, segs[i - 1].lastIndex);
        expect(segs[i].start, segs[i - 1].end);
      }
      expect(segs.first.firstIndex, 0);
      expect(segs.last.lastIndex, f.samples.length - 1);
    });

    test('a lift is shown within 60 s and a run within 15 s (SC-002)', () {
      var st = startSnow();
      int? liftAt;
      int? runAt;
      for (final p in f.samples) {
        st = accumulateSnow(st, p);
        final sec = p.t.difference(snowStart).inSeconds;
        if (st.kind == SnowKind.lift) liftAt ??= sec;
        if (st.kind == SnowKind.run) runAt ??= sec;
      }
      expect(liftAt! - 60, lessThanOrEqualTo(60));
      expect(runAt! - (60 + 420 + 40), lessThanOrEqualTo(15));
    });

    test('lift gain is close to the climb', () {
      final lifts = pauseSnow(s).segments.where((x) => x.kind == SnowKind.lift);
      for (final l in lifts) {
        within5(l.verticalMeters, 420, 'lift gain');
      }
    });

    test('works without device speed', () {
      final g = buildSnowDay(plainDay, doppler: false);
      final t = fold(g.samples);
      expect(snowRunCount(t), 3, reason: describe(t));
      within5(t.rideSeconds, g.rideSeconds, 'ride seconds');
      within5(t.liftSeconds, g.liftSeconds, 'lift seconds');
      within5(t.dropMeters, g.dropMeters, 'drop');
      expect(t.maxSpeedMps, closeTo(g.maxSpeedMps, g.maxSpeedMps * 0.1));
    });

    test('holds for other noise seeds', () {
      for (final seed in [2, 3, 4, 5]) {
        final g = buildSnowDay(plainDay, seed: seed);
        final t = fold(g.samples);
        expectTotals(t, g, runs: 3);
      }
    });
  });

  group('edge cases', () {
    test('a chairlift stopping for 90 s stays one lift', () {
      final f = buildSnowDay(const [
        SnowLeg.stand(60),
        SnowLeg.lift(510, stopAt: 200, stopFor: 90),
        SnowLeg.stand(40),
        SnowLeg.run(240),
        SnowLeg.stand(60),
      ]);
      final s = fold(f.samples);
      expect(
        kinds(s).where((k) => k == SnowKind.lift).length,
        1,
        reason: describe(s),
      );
      expectTotals(s, f, runs: 1);
    });

    test('the first seconds of a fast gondola are not a run', () {
      final f = buildSnowDay(const [
        SnowLeg.stand(60),
        // A flat stretch out of the station, then the climb.
        SnowLeg.lift(30, speed: 8, vertical: 0),
        SnowLeg.lift(420, speed: 8),
        SnowLeg.stand(40),
        SnowLeg.run(240),
        SnowLeg.stand(60),
      ]);
      // The start of the ride does look like riding on the flat...
      var st = startSnow();
      final seen = <SnowKind>{};
      for (final p in f.samples.take(120)) {
        st = accumulateSnow(st, p);
        seen.add(st.kind);
      }
      expect(seen, contains(SnowKind.run));
      // ...but it ends up as part of the lift.
      final s = fold(f.samples);
      expect(kinds(s), [
        SnowKind.rest,
        SnowKind.lift,
        SnowKind.rest,
        SnowKind.run,
        SnowKind.rest,
      ], reason: describe(s));
      expectTotals(s, f, runs: 1);
      final lift = pauseSnow(s).segments[1];
      within5(lift.verticalMeters, 420, 'lift gain');
    });

    test('standing at the top for long ends the lift at the top', () {
      final f = buildSnowDay(const [
        SnowLeg.stand(60),
        SnowLeg.lift(420),
        SnowLeg.stand(300),
        SnowLeg.run(240),
        SnowLeg.stand(60),
      ]);
      final s = fold(f.samples);
      expect(kinds(s), [
        SnowKind.rest,
        SnowKind.lift,
        SnowKind.rest,
        SnowKind.run,
        SnowKind.rest,
      ], reason: describe(s));
      expectTotals(s, f, runs: 1);
    });

    test('riding off the lift without stopping', () {
      final f = buildSnowDay(const [
        SnowLeg.stand(60),
        SnowLeg.lift(420),
        SnowLeg.run(240),
        SnowLeg.stand(60),
      ]);
      final s = fold(f.samples);
      expect(snowRunCount(s), 1, reason: describe(s));
      within5(s.liftSeconds, f.liftSeconds, 'lift seconds');
      within5(s.dropMeters, f.dropMeters, 'drop');
    });

    test('a stop on the way down is rest, not a second run', () {
      final f = buildSnowDay(const [
        SnowLeg.stand(60),
        SnowLeg.lift(420),
        SnowLeg.stand(40),
        SnowLeg.run(120),
        SnowLeg.stand(60),
        SnowLeg.run(120),
        SnowLeg.stand(60),
      ]);
      final s = fold(f.samples);
      expect(
        kinds(s).where((k) => k == SnowKind.run).length,
        2,
        reason: describe(s),
      );
      expectTotals(s, f, runs: 1);
    });

    test('a short traverse is riding but not a run', () {
      final f = buildSnowDay(const [
        SnowLeg.stand(60),
        ...snowCycle,
        SnowLeg.lift(420),
        SnowLeg.stand(40),
        SnowLeg.run(40, speed: 5, vertical: 0.4),
        SnowLeg.stand(60),
        SnowLeg.lift(420),
        SnowLeg.stand(60),
      ]);
      final s = fold(f.samples);
      expect(snowRunCount(s), 1, reason: describe(s));
      expect(
        kinds(s).where((k) => k == SnowKind.run).length,
        2,
        reason: describe(s),
      );
      within5(s.rideSeconds, f.rideSeconds, 'ride seconds');
    });

    test('a gondola losing GPS for 3 minutes stays one lift', () {
      final f = buildSnowDay(const [
        SnowLeg.stand(60),
        SnowLeg.lift(420, silentAt: 120, silentFor: 180),
        SnowLeg.stand(40),
        SnowLeg.run(240),
        SnowLeg.stand(60),
      ]);
      final s = fold(f.samples);
      expect(
        kinds(s).where((k) => k == SnowKind.lift).length,
        1,
        reason: describe(s),
      );
      expectTotals(s, f, runs: 1);
    });

    test('a GPS gap on the slope counts as rest', () {
      final f = buildSnowDay(const [
        SnowLeg.stand(60),
        SnowLeg.lift(420),
        SnowLeg.stand(40),
        SnowLeg.run(240),
        SnowLeg.stand(30),
      ]);
      // Drop the fixes of a minute in the middle of the run.
      final cut = [
        for (final p in f.samples)
          if (p.t.difference(snowStart).inSeconds < 620 ||
              p.t.difference(snowStart).inSeconds > 680)
            p,
      ];
      final s = fold(cut);
      expect(snowRunCount(s), 1, reason: describe(s));
      expect(s.rideSeconds, closeTo(180, 12), reason: describe(s));
    });

    test('without altitude everything moving is riding, no lifts', () {
      final f = buildSnowDay(plainDay, altitude: false);
      final s = fold(f.samples);
      expect(kinds(s), isNot(contains(SnowKind.lift)));
      expect(s.dropMeters, 0);
      expect(snowRunCount(s), 0);
      expect(s.rideSeconds, greaterThan(f.rideSeconds));
    });

    test('a single speed spike does not set the max speed', () {
      final f = buildSnowDay(plainDay);
      final spiked = [
        for (final p in f.samples)
          if (p.t.difference(snowStart).inSeconds == 600)
            TrackSample(
              t: p.t,
              lat: p.lat,
              lon: p.lon,
              alt: p.alt,
              accuracy: p.accuracy,
              speed: 40,
            )
          else
            p,
      ];
      within5(fold(spiked).maxSpeedMps, f.maxSpeedMps, 'max speed');
    });
  });

  group('pause', () {
    const legs = [
      SnowLeg.stand(60),
      ...snowCycle,
      SnowLeg.pause(600),
      ...snowCycle,
    ];

    test('nothing is measured or classified across a manual pause', () {
      final f = buildSnowDay(legs);
      final s = fold(f.samples);
      expectTotals(s, f, runs: 2);
      final segs = pauseSnow(s).segments;
      final total = segs.fold<double>(0, (a, x) => a + x.seconds);
      expect(total, closeTo(60 + 820 + 820, 3));
    });

    test('pausing ends the segment; the next fix starts a rest', () {
      final f = buildSnowDay(const [SnowLeg.stand(30)]);
      final paused = pauseSnow(fold(f.samples));
      expect(paused.current, isNull);
      expect(paused.segments, hasLength(1));
      expect(paused.kind, SnowKind.rest);
      final resumed = accumulateSnow(paused, fix(500, alt: 1500, speed: 0));
      expect(resumed.current!.firstIndex, paused.count);
      expect(resumed.current!.seconds, 0);
    });
  });

  group('replay', () {
    test('replay equals incremental with the same pauses (SC-003)', () {
      final f = buildSnowDay(const [
        SnowLeg.stand(60),
        ...snowCycle,
        SnowLeg.pause(300),
        SnowLeg.lift(510, stopAt: 200, stopFor: 90),
        SnowLeg.stand(40),
        SnowLeg.run(240),
      ]);
      var live = startSnow();
      var wasPaused = false;
      for (final p in f.samples) {
        if (p.paused) {
          if (!wasPaused) live = pauseSnow(live);
        } else {
          live = accumulateSnow(live, p);
        }
        wasPaused = p.paused;
      }
      final again = replaySnow(f.samples);
      expect(describe(again), describe(live));
      expect(again.count, live.count);
      expect(again.rideSeconds, live.rideSeconds);
      expect(again.liftSeconds, live.liftSeconds);
      expect(again.restSeconds, live.restSeconds);
      expect(again.rideMeters, live.rideMeters);
      expect(again.dropMeters, live.dropMeters);
      expect(again.maxSpeedMps, live.maxSpeedMps);
      expect(snowRunCount(again), snowRunCount(live));
    });
  });

  group('SnowSegment', () {
    test('vertical by kind and net drop', () {
      SnowSegment seg(SnowKind k) => SnowSegment(
        kind: k,
        firstIndex: 0,
        lastIndex: 1,
        start: snowStart,
        end: snowStart.add(const Duration(seconds: 10)),
        ascentMeters: 7,
        descentMeters: 9,
        startAlt: 100,
        endAlt: 98,
      );
      expect(seg(SnowKind.run).verticalMeters, 9);
      expect(seg(SnowKind.lift).verticalMeters, 7);
      expect(seg(SnowKind.rest).verticalMeters, 0);
      expect(seg(SnowKind.run).netDropMeters, 2);
      expect(seg(SnowKind.run).seconds, 10);
      expect(SnowSegment.at(SnowKind.run, 0, snowStart, null).netDropMeters, 0);
    });

    test('sealing adds the change still below the hysteresis', () {
      var seg = SnowSegment.at(SnowKind.run, 0, snowStart, 100);
      seg = seg.step(
        index: 1,
        t: snowStart.add(const Duration(seconds: 1)),
        meters: 10,
        alt: 97,
        speed: 10,
        hysteresis: 5,
      );
      expect(seg.descentMeters, 0);
      expect(seg.sealed().descentMeters, 3);
      final up = SnowSegment.at(SnowKind.lift, 0, snowStart, 100).step(
        index: 1,
        t: snowStart.add(const Duration(seconds: 1)),
        meters: 4,
        alt: 102,
        speed: 4,
        hysteresis: 5,
      );
      expect(up.sealed().ascentMeters, 2);
      expect(up.sealed().sealed().ascentMeters, 2);
    });
  });
}
