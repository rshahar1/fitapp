// Feature 019: the dev-only GPS simulation drives the real TrackingController
// with the Val Thorens session, on the simulation's virtual clock.

import 'package:fitapp/data/providers.dart';
import 'package:fitapp/data/tracking/sim/track_simulation.dart';
import 'package:fitapp/data/tracking/sim/val_thorens_session.dart';
import 'package:fitapp/data/tracking/track_csv.dart';
import 'package:fitapp/domain/tracking/snow_reducer.dart';
import 'package:fitapp/domain/tracking/snow_state.dart';
import 'package:fitapp/domain/tracking/track_reducer.dart' as reducer;
import 'package:fitapp/features/tracking/simulation_driver.dart';
import 'package:fitapp/features/tracking/tracking_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../data/helpers.dart';

void main() {
  final session = parseTrackCsv(
    valThorensSessionCsv,
    start: DateTime.utc(2026),
  );
  final meta = session;
  late Harness h;
  late DateTime real;
  late TrackSimulation sim;
  late ProviderContainer c;

  setUp(() {
    h = Harness();
    real = DateTime.utc(2026, 11, 17, 9);
    sim = TrackSimulation(session.samples, realClock: () => real);
    // The app hands the simulation's clock to the database too (main.dart).
    h.now = real;
    c = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(h.db),
        ...simulationOverrides(sim),
        trackingFlushIntervalProvider.overrideWithValue(
          const Duration(milliseconds: 20),
        ),
      ],
    );
    driveSimulation(c, sim);
  });
  tearDown(() async {
    c.dispose();
    sim.dispose();
    await h.close();
  });

  TrackingController ctl() => c.read(trackingControllerProvider.notifier);
  TrackingUiState ui() => c.read(trackingControllerProvider);

  /// Moves the real clock by [d] and lets the simulation send what is due.
  void advance(Duration d) {
    real = real.add(d);
    sim.poll();
  }

  /// Replays the whole session at [speed]. Returns what the live state
  /// showed, as (kind, from fix time) each time it changed.
  Future<List<({SnowKind kind, DateTime at})>> replay(int speed) async {
    final shown = <({SnowKind kind, DateTime at})>[];
    final sub = c.listen<TrackingUiState>(trackingControllerProvider, (_, s) {
      if (s is! TrackingLive) return;
      final kind = s.snow!.kind;
      final at = s.state.lastAccepted?.t;
      if (at != null && (shown.isEmpty || shown.last.kind != kind)) {
        shown.add((kind: kind, at: at));
      }
    });
    sim.setSpeed(speed);
    while (sim.phase == SimPhase.replaying) {
      advance(const Duration(milliseconds: 500));
    }
    sub.close();
    await Future<void>.delayed(const Duration(milliseconds: 60));
    return shown;
  }

  /// [shown] without states shown for less than 10 s, neighbours merged.
  List<SnowKind> lasting(List<({SnowKind kind, DateTime at})> shown) {
    final out = <SnowKind>[];
    for (var i = 0; i < shown.length; i++) {
      final end = i + 1 < shown.length ? shown[i + 1].at : null;
      if (end != null && end.difference(shown[i].at).inSeconds < 10) continue;
      if (out.isEmpty || out.last != shown[i].kind) out.add(shown[i].kind);
    }
    return out;
  }

  Future<void> goLive() async {
    await ctl().prepare('snowboarding');
    advance(const Duration(seconds: 2));
    final acquiring = ui() as TrackingAcquiring;
    expect(acquiring.hasGoodFix, isTrue, reason: 'parked fixes are good');
    expect(acquiring.position!.lat, session.samples.first.lat);
    await ctl().startSession();
    expect(sim.phase, SimPhase.replaying);
  }

  test('the replay at 30x shows lifts and runs and saves the day', () async {
    await goLive();
    final startedAt = (ui() as TrackingLive).state.startedAt;
    final shown = await replay(30);
    expect(sim.phase, SimPhase.holding);
    // The legs of the day, in order. The cable car's first seconds show a
    // run for 7 s (see plan.md "Findings"), dropped here as transient.
    expect(lasting(shown), const [
      SnowKind.rest,
      SnowKind.lift, // Boismint chairlift
      SnowKind.run, // Boismint
      SnowKind.rest, // break at the Caron base
      SnowKind.lift, // Caron gondola
      SnowKind.rest, // mid station
      SnowKind.lift, // Cime Caron cable car
      SnowKind.run, // Col de l'Audzin
      SnowKind.rest, // stop on the way
      SnowKind.run, // Gentiane
      SnowKind.rest, // Boismint base
    ]);

    final live = ui() as TrackingLive;
    final snow = live.snow!;
    expect(snowRunCount(snow), meta.number('reference_runs'));
    expect(live.liftSpans, hasLength(3));
    expect(live.points, isNotEmpty);
    // The clock and the fixes agree: the session lasted the track's length,
    // not the 84 real seconds it took to replay.
    final elapsed = reducer.elapsedAt(live.state, sim.now());
    expect(elapsed.inSeconds, greaterThanOrEqualTo(sim.duration.inSeconds));
    expect(
      live.state.lastAccepted!.t.difference(startedAt).inSeconds,
      closeTo(sim.duration.inSeconds, 2),
    );

    final preview = ctl().previewSnowSummary()!;
    await ctl().finish();
    expect(sim.phase, SimPhase.parked, reason: 'parked after saving');
    final a = (await h.db.select(h.db.activities).get()).single;
    expect(a.typeId, 'snowboarding');
    expect(a.runCount, 2);
    expect(a.runCount, preview.runCount);
    double near(String key) => meta.number(key) * 0.05;
    expect(
      a.verticalDropMeters,
      closeTo(meta.number('reference_drop_m'), near('reference_drop_m')),
    );
    expect(
      a.distanceMeters,
      closeTo(meta.number('reference_ride_m'), near('reference_ride_m')),
    );
    expect(
      a.liftSeconds,
      closeTo(meta.number('reference_lift_s'), near('reference_lift_s')),
    );
    expect(
      a.movingSeconds,
      closeTo(meta.number('reference_ride_s'), near('reference_ride_s')),
    );
  });

  test('1x, 5x and 10x give the same day as 30x', () async {
    final results = <int, SnowState>{};
    for (final speed in [1, 5, 10]) {
      await goLive();
      final shown = await replay(speed);
      expect(lasting(shown), hasLength(11));
      results[speed] = (ui() as TrackingLive).snow!;
      await ctl().discard();
      expect(sim.phase, SimPhase.parked, reason: 'parked after discarding');
    }
    final one = results[1]!;
    for (final s in results.values) {
      expect(snowRunCount(s), 2);
      expect(s.rideSeconds, one.rideSeconds);
      expect(s.liftSeconds, one.liftSeconds);
      expect(s.dropMeters, one.dropMeters);
      expect(s.rideMeters, one.rideMeters);
    }
  });

  test('changing speed mid-session keeps fixes 1 s apart', () async {
    await goLive();
    sim.setSpeed(30);
    for (var i = 0; i < 20; i++) {
      advance(const Duration(milliseconds: 500));
    }
    sim.setSpeed(1);
    advance(const Duration(seconds: 3));
    sim.setSpeed(10);
    advance(const Duration(seconds: 2));
    await Future<void>.delayed(const Duration(milliseconds: 60));
    final rows = await h.db.select(h.db.trackPoints).get();
    final times = [for (final r in rows) r.t]..sort();
    expect(times.length, greaterThan(300));
    for (var i = 1; i < times.length; i++) {
      expect(
        times[i].difference(times[i - 1]),
        const Duration(seconds: 1),
        reason: 'point $i',
      );
    }
  });
}
