import 'dart:convert';

import 'package:fitapp/data/repositories/activity_repository.dart';
import 'package:fitapp/data/repositories/tracking_repository.dart';
import 'package:fitapp/domain/tracking/geo.dart';
import 'package:fitapp/domain/tracking/snow_state.dart';
import 'package:fitapp/domain/tracking/snow_summary.dart';
import 'package:fitapp/domain/tracking/track_sample.dart';
import 'package:flutter_test/flutter_test.dart';

import '../domain/tracking/snow_fixtures.dart';
import '../domain/tracking/track_fixtures.dart';
import 'helpers.dart';

TrackSample _s(int sec, {double lat = 32.08, bool paused = false}) =>
    TrackSample(
      t: fixtureStart.add(Duration(seconds: sec)),
      lat: lat,
      lon: 34.78,
      accuracy: 5,
      paused: paused,
    );

void main() {
  late Harness h;
  late TrackingRepository repo;

  setUp(() {
    h = Harness();
    repo = TrackingRepository(h.db);
  });
  tearDown(() => h.close());

  Future<String> startRun() =>
      repo.start(typeId: 'running', startedAt: fixtureStart);

  test('start creates one active session', () async {
    final id = await startRun();
    final row = await repo.session();
    expect(row!.id, id);
    expect(row.state, 'active');
    expect(row.typeId, 'running');
  });

  test('a second session is refused', () async {
    await startRun();
    expect(
      () => repo.start(typeId: 'cycling', startedAt: fixtureStart),
      throwsStateError,
    );
  });

  test('types without live tracking are refused', () {
    expect(
      () => repo.start(typeId: 'pilates', startedAt: fixtureStart),
      throwsArgumentError,
    );
    expect(
      () => repo.start(typeId: 'nope', startedAt: fixtureStart),
      throwsArgumentError,
    );
  });

  test('start is refused while a gym workout is active', () async {
    await h.workouts.startWorkout();
    expect(startRun, throwsStateError);
  });

  test('gym workout cannot start or resume while tracking', () async {
    final (w, _) = await h.session([(20, 10)]);
    await startRun();
    expect(h.workouts.startWorkout, throwsStateError);
    expect(await h.workouts.canResume(w), isFalse);
    await repo.discard((await repo.session())!.id);
    expect(await h.workouts.canResume(w), isTrue);
    await h.workouts.startWorkout();
  });

  test('appendPoints batches and continues the sequence', () async {
    final id = await startRun();
    await repo.appendPoints(id, [_s(0), _s(1), _s(2)]);
    await repo.appendPoints(id, [_s(3), _s(4)]);
    await repo.appendPoints(id, const []);
    final rows = await h.db.select(h.db.trackPoints).get();
    expect(rows.map((r) => r.seq).toList()..sort(), [0, 1, 2, 3, 4]);
    final points = await repo.loadPoints(id);
    expect(points.map((p) => p.t.second), [0, 1, 2, 3, 4]);
  });

  test('pause flags round-trip and setPaused updates the session', () async {
    final id = await startRun();
    await repo.appendPoints(id, [_s(0), _s(1, paused: true)]);
    expect((await repo.loadPoints(id)).map((p) => p.paused), [false, true]);

    final t0 = fixtureStart.add(const Duration(seconds: 10));
    await repo.setPaused(id, paused: true, at: t0);
    var row = (await repo.session())!;
    expect(row.state, 'paused');
    expect(row.pausedAt!.toUtc(), t0);

    await repo.setPaused(
      id,
      paused: false,
      at: t0.add(const Duration(seconds: 7)),
    );
    row = (await repo.session())!;
    expect(row.state, 'active');
    expect(row.pausedAt, isNull);
    expect(row.pausedMs, 7000);
  });

  test('unknown session ids throw', () async {
    expect(() => repo.appendPoints('x', [_s(0)]), throwsStateError);
    expect(
      () => repo.setPaused('x', paused: true, at: fixtureStart),
      throwsStateError,
    );
    expect(() => repo.finish('x', endedAt: fixtureStart), throwsStateError);
  });

  test('finish builds the activity from the 5k fixture', () async {
    final fx = loadTrack('run_5k');
    final id = await startRun();
    await repo.appendPoints(id, fx.samples);
    h.now = fx.samples.last.t.add(const Duration(minutes: 1));
    final aid = await repo.finish(
      id,
      endedAt: fx.samples.last.t,
      notes: ' easy ',
    );

    final a = (await h.db.select(h.db.activities).get()).single;
    expect(a.id, aid);
    expect(a.source, 'gps');
    expect(a.typeId, 'running');
    expect(a.startedAt.toUtc(), fixtureStart);
    expect(a.notes, 'easy');
    expect(
      a.distanceMeters,
      closeTo(fx.referenceMeters, fx.referenceMeters * 0.01),
    );
    expect(a.durationMinutes, greaterThan(10));
    expect(a.movingSeconds, greaterThan(0));
    expect(a.elevationGainMeters, isNotNull);
    expect(a.route, isNotEmpty);
    final splits = jsonDecode(a.splits!) as List<dynamic>;
    expect(splits.length, 5);

    expect(await repo.session(), isNull);
    expect(await h.db.select(h.db.trackPoints).get(), isEmpty);
  });

  test('finish without movement stores no distance', () async {
    final id = await startRun();
    await repo.appendPoints(id, [_s(0), _s(30)]);
    h.now = fixtureStart.add(const Duration(minutes: 5));
    await repo.finish(
      id,
      endedAt: fixtureStart.add(const Duration(minutes: 5)),
    );
    final a = (await h.db.select(h.db.activities).get()).single;
    expect(a.distanceMeters, isNull);
    expect(a.durationMinutes, 5);
  });

  test('finish excludes the paused time from the duration', () async {
    final id = await startRun();
    await repo.appendPoints(id, [
      _s(0),
      _s(60, lat: 32.0805),
      _s(120, lat: 32.0805, paused: true),
      _s(600, lat: 32.0805, paused: true),
      _s(660, lat: 32.081),
    ]);
    final end = fixtureStart.add(const Duration(seconds: 720));
    h.now = end;
    await repo.finish(id, endedAt: end);
    final a = (await h.db.select(h.db.activities).get()).single;
    // 12 min elapsed minus the 9 min pause (120 s..660 s) = 3 min.
    expect(a.durationMinutes, 3);
  });

  group('snowboarding', () {
    Future<String> saveDay(SnowFixture f) async {
      final id = await repo.start(typeId: 'snowboarding', startedAt: snowStart);
      await repo.appendPoints(id, f.samples);
      return await repo.finish(id, endedAt: f.samples.last.t, notes: 'powder');
    }

    test('finish stores the snowboarding metrics and segments', () async {
      final f = buildSnowDay(plainDay);
      final aid = await saveDay(f);
      final a = await (h.db.select(
        h.db.activities,
      )..where((x) => x.id.equals(aid))).getSingle();
      expect(a.typeId, 'snowboarding');
      expect(a.source, 'gps');
      expect(a.notes, 'powder');
      expect(a.runCount, 3);
      expect(a.verticalDropMeters, closeTo(f.dropMeters, f.dropMeters * 0.05));
      expect(a.distanceMeters, closeTo(f.rideMeters, f.rideMeters * 0.05));
      expect(a.movingSeconds, closeTo(f.rideSeconds, f.rideSeconds * 0.05));
      expect(a.liftSeconds, closeTo(f.liftSeconds, f.liftSeconds * 0.05));
      expect(a.restSeconds, closeTo(f.restSeconds, f.restSeconds * 0.05));
      expect(a.maxSpeedMps, closeTo(f.maxSpeedMps, f.maxSpeedMps * 0.05));
      expect(a.durationMinutes, ((f.samples.length - 1) / 60).round());
      expect(a.elevationGainMeters, isNull);
      expect(a.splits, isNull);
      final records = decodeSnowRecords(a.segments);
      expect(records.where((r) => r.kind == SnowKind.lift), hasLength(3));
      expect(
        decodePolyline(a.route!).length,
        records.fold<int>(0, (n, r) => n + r.pointCount),
      );
      expect(await h.db.select(h.db.trackPoints).get(), isEmpty);
      expect(await repo.session(), isNull);
    });

    test('fixes of a manual pause are left out of the day', () async {
      final f = buildSnowDay(const [
        SnowLeg.stand(60),
        ...snowCycle,
        SnowLeg.pause(600),
        ...snowCycle,
      ]);
      final aid = await saveDay(f);
      final a = await (h.db.select(
        h.db.activities,
      )..where((x) => x.id.equals(aid))).getSingle();
      expect(a.runCount, 2);
      final total = a.movingSeconds! + a.liftSeconds! + a.restSeconds!;
      expect(total, closeTo(60 + 820 + 820, 6));
    });

    test('a day without movement stores no distance and no runs', () async {
      final aid = await saveDay(buildSnowDay(const [SnowLeg.stand(120)]));
      final a = await (h.db.select(
        h.db.activities,
      )..where((x) => x.id.equals(aid))).getSingle();
      expect(a.distanceMeters, isNull);
      expect(a.runCount, 0);
      expect(a.verticalDropMeters, 0);
    });

    test('running keeps splits and climb and has no snow metrics', () async {
      final fx = loadTrack('run_5k');
      final id = await startRun();
      await repo.appendPoints(id, fx.samples);
      final aid = await repo.finish(id, endedAt: fx.samples.last.t);
      final a = await (h.db.select(
        h.db.activities,
      )..where((x) => x.id.equals(aid))).getSingle();
      expect(a.splits, isNotNull);
      expect(a.elevationGainMeters, isNotNull);
      expect(a.runCount, isNull);
      expect(a.verticalDropMeters, isNull);
      expect(a.maxSpeedMps, isNull);
      expect(a.liftSeconds, isNull);
      expect(a.restSeconds, isNull);
      expect(a.segments, isNull);
    });

    test('a tracked day cannot change to or from snowboarding', () async {
      final activities = ActivityRepository(h.db);
      final snowId = await saveDay(buildSnowDay(plainDay));
      expect(
        () =>
            activities.update(snowId, typeId: 'running', startedAt: snowStart),
        throwsArgumentError,
      );
      // Date and note can change; the metrics stay.
      await activities.update(
        snowId,
        typeId: 'snowboarding',
        startedAt: snowStart,
        durationMinutes: 42,
        distanceMeters: 8000,
        notes: 'edited',
      );
      final a = (await activities.activity(snowId))!;
      expect(a.notes, 'edited');
      expect(a.runCount, 3);
      expect(a.segments, isNotNull);

      final fx = loadTrack('run_5k');
      final id = await startRun();
      await repo.appendPoints(id, fx.samples);
      final runId = await repo.finish(id, endedAt: fx.samples.last.t);
      expect(
        () => activities.update(
          runId,
          typeId: 'snowboarding',
          startedAt: fixtureStart,
        ),
        throwsArgumentError,
      );
      await activities.update(
        runId,
        typeId: 'cycling',
        startedAt: fixtureStart,
      );
    });
  });

  test('discard deletes points and session', () async {
    final id = await startRun();
    await repo.appendPoints(id, [_s(0)]);
    await repo.discard(id);
    expect(await repo.session(), isNull);
    expect(await h.db.select(h.db.trackPoints).get(), isEmpty);
    expect(await h.db.select(h.db.activities).get(), isEmpty);
    await startRun();
  });

  test('does not queue local-only tracking rows on save or discard', () async {
    final fx = loadTrack('run_5k');
    final id = await startRun();
    await repo.appendPoints(id, fx.samples);
    await repo.finish(id, endedAt: fx.samples.last.t);
    final id2 = await startRun();
    await repo.discard(id2);
    expect(await h.db.select(h.db.pendingDeletes).get(), isEmpty);
  });
}
