import 'package:fitapp/data/db/app_database.dart';
import 'package:fitapp/data/providers.dart';
import 'package:fitapp/data/tracking/location_source.dart';
import 'package:fitapp/domain/tracking/track_reducer.dart' as reducer;
import 'package:fitapp/domain/tracking/track_sample.dart';
import 'package:fitapp/features/tracking/tracking_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../data/fake_location_source.dart';
import '../../data/helpers.dart';
import '../../domain/tracking/track_fixtures.dart';

TrackSample _fix(int sec, {double accuracy = 5, double? lat}) => TrackSample(
  t: fixtureStart.add(Duration(seconds: sec)),
  lat: lat ?? 32.08 + sec * 0.00003,
  lon: 34.78,
  accuracy: accuracy,
);

void main() {
  late Harness h;
  late FakeLocationSource source;
  late DateTime now;
  late ProviderContainer c;

  ProviderContainer makeContainer({
    Duration flush = const Duration(milliseconds: 40),
    int count = 20,
  }) {
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(h.db),
        locationSourceProvider.overrideWithValue(source),
        clockProvider.overrideWithValue(() => now),
        trackingFlushIntervalProvider.overrideWithValue(flush),
        trackingFlushCountProvider.overrideWithValue(count),
      ],
    );
    return container..listen(trackingControllerProvider, (_, _) {});
  }

  setUp(() {
    h = Harness();
    source = FakeLocationSource();
    now = fixtureStart;
    c = makeContainer();
  });
  tearDown(() async {
    c.dispose();
    await h.close();
  });

  TrackingController ctl() => c.read(trackingControllerProvider.notifier);
  TrackingUiState ui() => c.read(trackingControllerProvider);
  Future<List<TrackPointRow>> stored() => h.db.select(h.db.trackPoints).get();
  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 120));

  Future<void> goLive() async {
    await ctl().prepare('running');
    source.emit(_fix(0));
    await ctl().startSession();
  }

  test(
    'prepare checks permission and reports accuracy without persisting',
    () async {
      expect(ui(), isA<TrackingIdle>());
      await ctl().prepare('running');
      var s = ui() as TrackingAcquiring;
      expect(s.permission, LocationPermissionState.granted);
      expect(s.accuracy, isNull);
      expect(source.lastNotificationText, isNotEmpty);

      source.emit(_fix(0, accuracy: 35));
      s = ui() as TrackingAcquiring;
      expect(s.accuracy, 35);
      expect(s.hasGoodFix, isFalse);
      source.emit(_fix(1, accuracy: 6));
      expect((ui() as TrackingAcquiring).hasGoodFix, isTrue);

      expect(await stored(), isEmpty);
      expect(await h.db.select(h.db.trackingSessions).get(), isEmpty);
    },
  );

  test(
    'denied permission is requested; denied forever is not listened to',
    () async {
      source
        ..permission = LocationPermissionState.denied
        ..requestResult = LocationPermissionState.deniedForever;
      await ctl().prepare('running');
      final s = ui() as TrackingAcquiring;
      expect(s.permission, LocationPermissionState.deniedForever);
      expect(source.listening, isFalse);

      source
        ..permission = LocationPermissionState.granted
        ..service = false;
      await ctl().prepare('running');
      expect((ui() as TrackingAcquiring).serviceEnabled, isFalse);
      expect(source.listening, isFalse);
    },
  );

  test('startSession needs a good fix unless anyway', () async {
    await ctl().prepare('running');
    expect(() => ctl().startSession(), throwsStateError);
    source.emit(_fix(0, accuracy: 50));
    expect(() => ctl().startSession(), throwsStateError);
    await ctl().startSession(anyway: true);
    expect(ui(), isA<TrackingLive>());
  });

  test('acquiring becomes live and fixes accumulate', () async {
    await goLive();
    final live = ui() as TrackingLive;
    expect(live.typeId, 'running');
    for (var i = 1; i <= 10; i++) {
      now = fixtureStart.add(Duration(seconds: i));
      source.emit(_fix(i));
    }
    final s = (ui() as TrackingLive).state;
    expect(s.distanceMeters, greaterThan(20));
    expect(await h.db.select(h.db.trackingSessions).get(), hasLength(1));
  });

  test('flushes by interval and by point count', () async {
    await goLive();
    source.emit(_fix(1));
    expect(await stored(), isEmpty);
    await settle();
    expect(await stored(), hasLength(1));

    c.dispose();
    c = makeContainer(flush: const Duration(hours: 1), count: 3);
    await ctl().recover();
    source
      ..emit(_fix(2))
      ..emit(_fix(3));
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(await stored(), hasLength(1));
    source.emit(_fix(4));
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(await stored(), hasLength(4));
  });

  test('pause flags fixes, flushes first, resume continues', () async {
    await goLive();
    source.emit(_fix(1));
    now = fixtureStart.add(const Duration(seconds: 2));
    await ctl().pause();
    expect((ui() as TrackingLive).state.manualPaused, isTrue);
    expect(await stored(), hasLength(1));
    expect(
      (await h.db.select(h.db.trackingSessions).get()).single.state,
      'paused',
    );

    final before = (ui() as TrackingLive).state.distanceMeters;
    source.emit(_fix(3));
    expect((ui() as TrackingLive).state.distanceMeters, before);

    now = fixtureStart.add(const Duration(seconds: 12));
    await ctl().resume();
    expect((ui() as TrackingLive).state.manualPaused, isFalse);
    source.emit(_fix(13));
    await settle();
    final rows = await stored();
    expect(rows.map((r) => r.paused), [false, true, false]);
    final session = (await h.db.select(h.db.trackingSessions).get()).single;
    expect(session.state, 'active');
    expect(session.pausedMs, 10000);
  });

  test('finish saves the activity, stops listening, ends finished', () async {
    await goLive();
    for (var i = 1; i <= 60; i++) {
      source.emit(_fix(i));
    }
    now = fixtureStart.add(const Duration(minutes: 5));
    final id = await ctl().finish(notes: 'ok');
    expect(ui(), isA<TrackingFinished>());
    expect((ui() as TrackingFinished).activityId, id);
    expect(source.listening, isFalse);
    final a = (await h.db.select(h.db.activities).get()).single;
    expect(a.id, id);
    expect(a.source, 'gps');
    expect(a.distanceMeters, greaterThan(100));
    expect(await stored(), isEmpty);
    expect(await h.db.select(h.db.trackingSessions).get(), isEmpty);
  });

  test('discard removes everything and goes idle', () async {
    await goLive();
    source.emit(_fix(1));
    await ctl().discard();
    expect(ui(), isA<TrackingIdle>());
    expect(source.listening, isFalse);
    expect(await stored(), isEmpty);
    expect(await h.db.select(h.db.trackingSessions).get(), isEmpty);
    expect(await h.db.select(h.db.activities).get(), isEmpty);
  });

  test('recover rebuilds distance and elapsed in a new container', () async {
    await goLive();
    for (var i = 1; i <= 40; i++) {
      now = fixtureStart.add(Duration(seconds: i));
      source.emit(_fix(i));
    }
    now = fixtureStart.add(const Duration(seconds: 41));
    await ctl().pause();
    final before = (ui() as TrackingLive).state;
    final elapsed = reducer.elapsedAt(before, now);
    c.dispose();

    c = makeContainer();
    expect(ui(), isA<TrackingIdle>());
    await ctl().recover();
    final live = ui() as TrackingLive;
    expect(live.state.distanceMeters, closeTo(before.distanceMeters, 1e-6));
    expect(live.state.manualPaused, isTrue);
    expect(reducer.elapsedAt(live.state, now), elapsed);
    expect(source.listening, isTrue);

    source.emit(_fix(42));
    await ctl().resume();
    expect((ui() as TrackingLive).state.manualPaused, isFalse);
  });

  test('recover without a session does nothing', () async {
    await ctl().recover();
    expect(ui(), isA<TrackingIdle>());
  });
}
