import 'dart:convert';

import 'package:fitapp/data/repositories/tracking_repository.dart';
import 'package:fitapp/domain/tracking/track_sample.dart';
import 'package:flutter_test/flutter_test.dart';

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

  test('discard deletes points and session', () async {
    final id = await startRun();
    await repo.appendPoints(id, [_s(0)]);
    await repo.discard(id);
    expect(await repo.session(), isNull);
    expect(await h.db.select(h.db.trackPoints).get(), isEmpty);
    expect(await h.db.select(h.db.activities).get(), isEmpty);
    await startRun();
  });
}
