// Feature 019: the snow reducer on a simulated session over real Val Thorens
// geometry (OpenStreetMap lift lines and pistes, IGN elevations), through
// the same pipeline as the app: track reducer filter, then snow reducer.
import 'package:fitapp/domain/tracking/snow_reducer.dart';
import 'package:fitapp/domain/tracking/snow_state.dart';
import 'package:fitapp/domain/tracking/track_profile.dart';
import 'package:fitapp/domain/tracking/track_reducer.dart' as reducer;
import 'package:flutter_test/flutter_test.dart';

import 'track_fixtures.dart';

/// [actual] within 5% of [reference].
void within5(num actual, num reference, String what) =>
    expect(actual, closeTo(reference, reference.abs() * 0.05), reason: what);

String describe(SnowState s) => [
  for (final seg in [...s.segments, ?s.current])
    [
      seg.kind.name,
      '${seg.firstIndex}-${seg.lastIndex}',
      '${seg.seconds.round()}s',
      '${seg.verticalMeters.round()}m',
    ].join(' '),
].join('\n');

/// The legs of the session: `kind:from:to:name`, fix indices.
List<({SnowKind kind, int from, int to, String name})> legsOf(TrackFixture f) =>
    [
      for (final leg in f.meta['legs']!.split(','))
        if (leg.split(':') case [final k, final a, final b, final n])
          (
            kind: SnowKind.values.byName(k),
            from: int.parse(a),
            to: int.parse(b),
            name: n,
          ),
    ];

void main() {
  final f = valThorensSession();
  final accepted = reducer.acceptedSamples(
    f.samples.first.t,
    f.samples,
    TrackProfile.snowboarding,
  );
  final s = replaySnow(accepted);

  test('the fixture is complete and every fix is accepted', () {
    expect(f.samples, hasLength(legsOf(f).last.to + 1));
    expect(accepted, hasLength(f.samples.length));
    expect(f.number('reference_runs'), 2);
    // Real Val Thorens heights: Boismint base and Cime Caron summit.
    final alts = [for (final p in f.samples) p.alt!];
    expect(alts.reduce((a, b) => a < b ? a : b), closeTo(2075, 15));
    expect(alts.reduce((a, b) => a > b ? a : b), closeTo(3178, 15));
  });

  test('run count is exact', () {
    expect(snowRunCount(s), 2, reason: describe(s));
  });

  test('ride, lift and rest time match the reference within 5%', () {
    within5(s.rideSeconds, f.number('reference_ride_s'), 'ride seconds');
    within5(s.liftSeconds, f.number('reference_lift_s'), 'lift seconds');
    within5(s.restSeconds, f.number('reference_rest_s'), 'rest seconds');
  });

  test('ride distance, vertical drop and max speed within 5%', () {
    within5(s.rideMeters, f.number('reference_ride_m'), 'ride distance');
    within5(s.dropMeters, f.number('reference_drop_m'), 'vertical drop');
    within5(s.maxSpeedMps, f.number('reference_max_speed_mps'), 'max speed');
  });

  test('every leg is classified as what it is, near its boundaries', () {
    // Each fix more than 25 s from a leg boundary carries the leg's kind.
    final kinds = List<SnowKind?>.filled(f.samples.length, null);
    for (final seg in [...s.segments, ?s.current]) {
      for (var i = seg.firstIndex; i < seg.lastIndex; i++) {
        kinds[i] = seg.kind;
      }
    }
    for (final leg in legsOf(f)) {
      for (var i = leg.from + 25; i < leg.to - 25; i++) {
        expect(kinds[i], leg.kind, reason: '${leg.name} at fix $i');
      }
    }
  });

  test('three lifts with the real vertical of each', () {
    final lifts = [
      for (final seg in s.segments)
        if (seg.kind == SnowKind.lift) seg,
    ];
    expect(lifts, hasLength(3), reason: describe(s));
    within5(lifts[0].verticalMeters, 2664 - 2075, 'Boismint chairlift');
    within5(lifts[1].verticalMeters, 2316 - 2103, 'Caron gondola');
    within5(lifts[2].verticalMeters, 3178 - 2316, 'Cime Caron cable car');
  });

  test('replay equals incremental, also through a mid-session restart', () {
    var live = startSnow();
    for (final p in accepted) {
      live = accumulateSnow(live, p);
    }
    expect(live.segments.length, s.segments.length);
    expect(live.rideSeconds, s.rideSeconds);
    expect(live.dropMeters, s.dropMeters);
    // Recovery after a killed app rebuilds from the stored fixes.
    final half = replaySnow(accepted.take(1200));
    var resumed = half;
    for (final p in accepted.skip(1200)) {
      resumed = accumulateSnow(resumed, p);
    }
    expect(resumed.rideMeters, s.rideMeters);
    expect(snowRunCount(resumed), 2);
  });

  test('a run off a lift on a flat traverse shows within 40 s (021)', () {
    // Both pistes start with about 40 s of near-level riding. With
    // runConfirmDrop at 10 m the chip said "On lift" for 49 s and 63 s.
    final runs = [
      for (final l in legsOf(f))
        if (l.kind == SnowKind.run && !l.name.endsWith('(part_2)')) l,
    ];
    expect(runs, hasLength(2));
    var live = startSnow();
    final shownAt = <int, int>{};
    for (var i = 0; i < accepted.length; i++) {
      live = accumulateSnow(live, accepted[i]);
      for (final (n, r) in runs.indexed) {
        if (i >= r.from && i <= r.to && live.kind == SnowKind.run) {
          shownAt.putIfAbsent(n, () => i - r.from);
        }
      }
    }
    expect(shownAt[0], lessThanOrEqualTo(40), reason: 'Boismint');
    expect(shownAt[1], lessThanOrEqualTo(40), reason: "Col de l'Audzin");
  });

  test('known limit: the cable car start shows a run for under 10 s', () {
    // Leaving the mid station fast and nearly level, the cabin looks like
    // riding until the climb is confirmed; `falseRun` then folds it into
    // the lift, so the totals are right. A tuning that removes the flicker
    // (see plan.md "Findings") makes this test fail on purpose.
    final cable = legsOf(f).firstWhere((l) => l.name.startsWith('Cime_Caron'));
    var live = startSnow();
    var runFixes = 0;
    for (var i = 0; i < accepted.length; i++) {
      live = accumulateSnow(live, accepted[i]);
      if (i >= cable.from && i <= cable.to && live.kind == SnowKind.run) {
        runFixes++;
      }
    }
    expect(runFixes, inInclusiveRange(1, 9));
  });

  test('timestamps of the fixture are 1 Hz and in order', () {
    for (var i = 1; i < f.samples.length; i++) {
      final a = f.samples[i - 1];
      final b = f.samples[i];
      expect(b.t.difference(a.t), const Duration(seconds: 1));
    }
  });
}
