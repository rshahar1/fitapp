import 'dart:async';

import 'package:drift/drift.dart' show DatabaseConnection, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:fitapp/app/app.dart';
import 'package:fitapp/app/router.dart';
import 'package:fitapp/app/theme/app_theme.dart';
import 'package:fitapp/core/haptics.dart';
import 'package:fitapp/data/db/app_database.dart';
import 'package:fitapp/data/providers.dart';
import 'package:fitapp/data/repositories/activity_repository.dart';
import 'package:fitapp/data/repositories/tracking_repository.dart';
import 'package:fitapp/data/repositories/workout_repository.dart';
import 'package:fitapp/data/tracking/location_source.dart';
import 'package:fitapp/domain/tracking/track_sample.dart';
import 'package:fitapp/features/activities/activity_sheet.dart';
import 'package:fitapp/features/tracking/launch_recovery.dart';
import 'package:fitapp/features/tracking/tracking_controller.dart';
import 'package:fitapp/features/tracking/widgets/route_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/fake_location_source.dart';
import '../../domain/tracking/track_fixtures.dart';

class _Haptics implements Haptics {
  int successes = 0;
  @override
  void tick() {}
  @override
  void success() => successes++;
  @override
  void warning() {}
}

void main() {
  late AppDatabase db;
  late FakeLocationSource source;
  late _Haptics haptics;
  late DateTime now;
  late GoRouter router;
  late ProviderContainer container;

  setUp(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    db = AppDatabase(DatabaseConnection(NativeDatabase.memory()));
    source = FakeLocationSource();
    haptics = _Haptics();
    now = fixtureStart;
  });
  tearDown(() => db.close());

  TrackSample fix(int sec, {double accuracy = 5, double? alt}) => TrackSample(
    t: fixtureStart.add(Duration(seconds: sec)),
    lat: 32.08 + sec * 0.00003,
    lon: 34.78,
    accuracy: accuracy,
    alt: alt,
  );

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump(const Duration(milliseconds: 300));
    }
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 10));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 10));
  }

  Future<void> pumpApp(WidgetTester tester) async {
    tester.view
      ..physicalSize = const Size(800, 1600)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    router = buildRouter();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          hapticsProvider.overrideWithValue(haptics),
          locationSourceProvider.overrideWithValue(source),
          clockProvider.overrideWithValue(() => now),
          mapTilesEnabledProvider.overrideWithValue(false),
          routerProvider.overrideWithValue(router),
          trackingFlushIntervalProvider.overrideWithValue(
            const Duration(hours: 1),
          ),
        ],
        child: Consumer(
          builder: (context, ref, _) {
            container = ProviderScope.containerOf(context);
            return MaterialApp.router(
              theme: buildAppTheme(),
              routerConfig: router,
            );
          },
        ),
      ),
    );
    await settle(tester);
  }

  /// Opens the live screen: setup, good fix, Start.
  Future<void> goLive(WidgetTester tester, {String type = 'running'}) async {
    await pumpApp(tester);
    unawaited(router.push(Routes.newTrack(type)));
    await settle(tester);
    source.emit(fix(0));
    await tester.pump();
    await tester.tap(find.text('START'));
    await settle(tester);
  }

  Future<void> emit(WidgetTester tester, int from, int to) async {
    for (var i = from; i <= to; i++) {
      now = fixtureStart.add(Duration(seconds: i));
      source.emit(fix(i));
    }
    await tester.pump(const Duration(seconds: 1));
  }

  Future<void> hold(WidgetTester tester, Finder f, [int ms = 1100]) async {
    final g = await tester.startGesture(tester.getCenter(f));
    await tester.pump(); // the ticker starts on the first frame
    await tester.pump(Duration(milliseconds: ms));
    await g.up();
    await tester.pump(const Duration(milliseconds: 300));
  }

  group('activity sheet', () {
    testWidgets('Start live only for running and cycling new entries', (
      tester,
    ) async {
      await pumpApp(tester);
      await tester.tap(find.text('LOG ACTIVITY'));
      await settle(tester);
      expect(find.text('START LIVE'), findsNothing);
      await tester.tap(find.text('Pilates'));
      await tester.pump();
      expect(find.text('START LIVE'), findsNothing);
      await tester.tap(find.text('Running'));
      await tester.pump();
      expect(find.text('START LIVE'), findsOneWidget);
      expect(find.text('or log it manually below'), findsOneWidget);
      await tester.tap(find.text('Cycling'));
      await tester.pump();
      expect(find.text('START LIVE'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('not offered when editing', (tester) async {
      await pumpApp(tester);
      final id = (await tester.runAsync(
        () =>
            ActivityRepository(db)
                .create(typeId: 'running', startedAt: now, durationMinutes: 30),
      ))!;
      final row = (await tester.runAsync(() => ActivityRepository(db).list()))!
          .firstWhere((a) => a.id == id);
      unawaited(
        showActivitySheet(
          tester.element(find.byType(Scaffold).first),
          existing: row,
        ),
      );
      await settle(tester);
      expect(find.text('Edit activity'), findsOneWidget);
      expect(find.text('START LIVE'), findsNothing);
      await unmount(tester);
    });

    testWidgets('Start live opens the setup screen', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.text('LOG ACTIVITY'));
      await settle(tester);
      await tester.tap(find.text('Running'));
      await tester.pump();
      await tester.tap(find.text('START LIVE'));
      await settle(tester);
      expect(find.text('Searching for GPS'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('a workout in progress shows a message with Open', (
      tester,
    ) async {
      await tester.runAsync(() => WorkoutRepository(db).startWorkout());
      await pumpApp(tester);
      await tester.tap(find.text('LOG ACTIVITY'));
      await settle(tester);
      await tester.tap(find.text('Running'));
      await tester.pump();
      await tester.tap(find.text('START LIVE'));
      await settle(tester);
      expect(find.textContaining('Workout in progress.'), findsOneWidget);
      expect(find.text('Open'), findsOneWidget);
      expect(find.text('Searching for GPS'), findsNothing);
      await unmount(tester);
    });
  });

  group('setup screen', () {
    testWidgets('rationale, then Continue requests permission', (tester) async {
      source
        ..permission = LocationPermissionState.denied
        ..requestResult = LocationPermissionState.granted;
      await pumpApp(tester);
      unawaited(router.push(Routes.newTrack('running')));
      await settle(tester);
      expect(find.text('Location is needed'), findsOneWidget);
      expect(find.textContaining('stays on this device'), findsOneWidget);
      await tester.tap(find.text('CONTINUE'));
      await settle(tester);
      expect(find.text('Searching for GPS'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('denied: Open settings and Log manually', (tester) async {
      source.permission = LocationPermissionState.deniedForever;
      await pumpApp(tester);
      unawaited(router.push(Routes.newTrack('running')));
      await settle(tester);
      expect(find.text('Location permission denied'), findsOneWidget);
      await tester.tap(find.text('OPEN SETTINGS'));
      await tester.pump();
      expect(source.appSettingsOpened, 1);
      await tester.tap(find.text('LOG MANUALLY INSTEAD'));
      await settle(tester);
      expect(find.text('Log activity'), findsOneWidget);
      expect(find.text('START LIVE'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('location service off', (tester) async {
      source.service = false;
      await pumpApp(tester);
      unawaited(router.push(Routes.newTrack('cycling')));
      await settle(tester);
      expect(find.text('Location is turned off'), findsOneWidget);
      expect(find.byType(RouteMap), findsOneWidget);
      await tester.tap(find.text('TURN ON LOCATION'));
      await tester.pump();
      expect(source.locationSettingsOpened, 1);
      await unmount(tester);
    });

    testWidgets('searching, weak, ready; Start anyway', (tester) async {
      await pumpApp(tester);
      unawaited(router.push(Routes.newTrack('running')));
      await settle(tester);
      expect(find.text('Searching for GPS'), findsOneWidget);
      await tester.tap(find.text('START'));
      await settle(tester);
      expect(
        container.read(trackingControllerProvider),
        isA<TrackingAcquiring>(),
      );

      source.emit(fix(0, accuracy: 35));
      await tester.pump();
      expect(find.text('Weak GPS (±35 m)'), findsOneWidget);

      source.emit(fix(1, accuracy: 6));
      await tester.pump();
      expect(find.text('GPS ready (±6 m)'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('shows the map and Finding your location without a fix', (
      tester,
    ) async {
      await pumpApp(tester);
      unawaited(router.push(Routes.newTrack('running')));
      await settle(tester);
      expect(find.bySemanticsLabel('Route map'), findsOneWidget);
      expect(find.text('Finding your location…'), findsOneWidget);
      source.emit(fix(0, accuracy: 30));
      await tester.pump();
      expect(find.text('Finding your location…'), findsNothing);
      await unmount(tester);
    });

    testWidgets('last known position hides Finding your location', (
      tester,
    ) async {
      source.lastKnown = fix(0, accuracy: 500);
      await pumpApp(tester);
      unawaited(router.push(Routes.newTrack('running')));
      await settle(tester);
      expect(find.bySemanticsLabel('Route map'), findsOneWidget);
      expect(find.text('Finding your location…'), findsNothing);
      expect(find.text('Searching for GPS'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('after 20 s without a good fix the hint changes', (
      tester,
    ) async {
      await pumpApp(tester);
      unawaited(router.push(Routes.newTrack('running')));
      await settle(tester);
      expect(find.textContaining('GPS accuracy is low'), findsNothing);
      expect(find.text('Start anyway'), findsOneWidget);
      now = now.add(const Duration(seconds: 21));
      await tester.pump(const Duration(seconds: 2));
      expect(find.textContaining('GPS accuracy is low here'), findsOneWidget);
      expect(find.text('START ANYWAY'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('Start anyway goes live without a good fix', (tester) async {
      await pumpApp(tester);
      unawaited(router.push(Routes.newTrack('running')));
      await settle(tester);
      await tester.tap(find.text('Start anyway'));
      await settle(tester);
      expect(container.read(trackingControllerProvider), isA<TrackingLive>());
      expect(find.text('TIME'), findsOneWidget);
      expect(haptics.successes, 1);
      await unmount(tester);
    });
  });

  group('live screen', () {
    testWidgets('running metrics', (tester) async {
      await goLive(tester);
      expect(find.text('TIME'), findsOneWidget);
      expect(find.text('DISTANCE'), findsOneWidget);
      expect(find.text('PACE'), findsOneWidget);
      expect(find.text('AVG PACE'), findsOneWidget);
      expect(find.text('LAST KM'), findsOneWidget);
      await emit(tester, 1, 40);
      final live = container.read(trackingControllerProvider) as TrackingLive;
      expect(live.state.distanceMeters, greaterThan(100));
      expect(find.text('0.00'), findsNothing);
      expect(find.textContaining('0:4'), findsWidgets);
      await unmount(tester);
    });

    testWidgets('cycling metrics', (tester) async {
      await goLive(tester, type: 'cycling');
      expect(find.text('SPEED'), findsOneWidget);
      expect(find.text('AVG SPEED'), findsOneWidget);
      expect(find.text('ELAPSED'), findsOneWidget);
      expect(find.text('CLIMB'), findsOneWidget);
      expect(find.text('LAST KM'), findsNothing);
      await emit(tester, 1, 30);
      expect(find.text('km/h'), findsWidgets);
      await unmount(tester);
    });

    testWidgets('pause and resume', (tester) async {
      await goLive(tester);
      await emit(tester, 1, 5);
      await tester.tap(find.text('PAUSE'));
      await settle(tester);
      expect(find.text('Paused'), findsOneWidget);
      expect(find.text('RESUME'), findsOneWidget);
      await tester.tap(find.text('RESUME'));
      await settle(tester);
      expect(find.text('Paused'), findsNothing);
      expect(find.text('PAUSE'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('lock blocks taps; hold unlocks', (tester) async {
      await goLive(tester);
      await tester.tap(find.byTooltip('Back').hitTestable());
      // Back leaves the screen without ending the session: go forward again.
      await settle(tester);
      expect(container.read(trackingControllerProvider), isA<TrackingLive>());
      unawaited(router.push(Routes.trackLive));
      await settle(tester);

      await tester.tap(find.bySemanticsLabel('Lock'));
      await tester.pump();
      await tester.tap(find.text('PAUSE'));
      await settle(tester);
      expect(find.text('RESUME'), findsNothing);
      expect(
        (container.read(
          trackingControllerProvider,
        ) as TrackingLive).state.manualPaused,
        isFalse,
      );
      await hold(tester, find.text('FINISH'));
      expect(find.text('Save'), findsNothing);

      await tester.tap(find.bySemanticsLabel('Unlock'));
      await tester.pump();
      expect(find.text('Hold to unlock'), findsOneWidget);
      await hold(tester, find.bySemanticsLabel('Unlock'));
      await tester.tap(find.text('PAUSE'));
      await settle(tester);
      expect(find.text('RESUME'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('finish needs a hold; a tap only hints', (tester) async {
      await goLive(tester);
      await tester.tap(find.text('FINISH'));
      await tester.pump();
      expect(find.text('Hold to finish'), findsOneWidget);
      expect(find.text('SAVE'), findsNothing);
      await hold(tester, find.text('FINISH'), 400);
      expect(find.text('SAVE'), findsNothing);
      await hold(tester, find.text('FINISH'));
      await settle(tester);
      expect(find.text('Running summary'), findsOneWidget);
      await unmount(tester);
    });
  });

  group('finish sheet', () {
    Future<void> toSheet(WidgetTester tester, {int seconds = 90}) async {
      await goLive(tester);
      await emit(tester, 1, seconds);
      now = fixtureStart.add(Duration(seconds: seconds));
      await hold(tester, find.text('FINISH'));
      await settle(tester);
    }

    testWidgets('Save creates the activity and opens History', (tester) async {
      await toSheet(tester);
      expect(find.text('Running summary'), findsOneWidget);
      expect(find.text('AVG PACE'), findsWidgets);
      await tester.enterText(find.byType(TextField), 'Easy loop');
      await tester.tap(find.text('SAVE'));
      await settle(tester);
      final rows = (await tester.runAsync(
        () => ActivityRepository(db).list(),
      ))!;
      expect(rows, hasLength(1));
      expect(rows.single.source, 'gps');
      expect(rows.single.notes, 'Easy loop');
      expect(
        await tester.runAsync(() => TrackingRepository(db).session()),
        isNull,
      );
      expect(haptics.successes, greaterThanOrEqualTo(2));
      expect(find.text('History'), findsWidgets);
      await unmount(tester);
    });

    testWidgets('a short activity asks before saving', (tester) async {
      await toSheet(tester, seconds: 20);
      await tester.tap(find.text('SAVE'));
      await settle(tester);
      expect(find.text('Save this short activity?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await settle(tester);
      expect(
        await tester.runAsync(() => ActivityRepository(db).list()),
        isEmpty,
      );
      await tester.tap(find.text('SAVE'));
      await settle(tester);
      await tester.tap(find.text('Save'));
      await settle(tester);
      expect(
        await tester.runAsync(() => ActivityRepository(db).list()),
        hasLength(1),
      );
      await unmount(tester);
    });

    testWidgets('Discard confirms, then deletes the session', (tester) async {
      await toSheet(tester);
      await tester.tap(find.text('DISCARD'));
      await settle(tester);
      expect(find.text('Discard activity?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await settle(tester);
      expect(
        await tester.runAsync(() => TrackingRepository(db).session()),
        isNotNull,
      );
      await tester.tap(find.text('DISCARD'));
      await settle(tester);
      await tester.tap(find.text('Discard'));
      await settle(tester);
      expect(
        await tester.runAsync(() => TrackingRepository(db).session()),
        isNull,
      );
      expect(
        await tester.runAsync(() => ActivityRepository(db).list()),
        isEmpty,
      );
      expect(container.read(trackingControllerProvider), isA<TrackingIdle>());
      await unmount(tester);
    });
  });

  group('Train and recovery', () {
    testWidgets('banner shows the session in progress and opens it', (
      tester,
    ) async {
      await goLive(tester);
      await emit(tester, 1, 30);
      await tester.tap(find.byTooltip('Back'));
      await settle(tester);
      expect(
        find.textContaining('Running in progress · 0:30 · 0.'),
        findsOneWidget,
      );
      await tester.tap(find.textContaining('Running in progress'));
      await settle(tester);
      expect(find.text('TIME'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('no banner without a session', (tester) async {
      await pumpApp(tester);
      expect(find.textContaining('in progress'), findsNothing);
      await unmount(tester);
    });

    testWidgets('launch recovery reopens the live screen', (tester) async {
      await tester.runAsync(
        () => TrackingRepository(db).start(typeId: 'running', startedAt: now),
      );
      await pumpApp(tester);
      await tester.runAsync(() => recoverTrackingOnLaunch(container));
      await settle(tester);
      expect(container.read(trackingControllerProvider), isA<TrackingLive>());
      expect(find.text('TIME'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('the app shell recovers on launch', (tester) async {
      await tester.runAsync(
        () => TrackingRepository(db).start(typeId: 'cycling', startedAt: now),
      );
      tester.view
        ..physicalSize = const Size(800, 1600)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            hapticsProvider.overrideWithValue(haptics),
            locationSourceProvider.overrideWithValue(source),
            clockProvider.overrideWithValue(() => now),
            mapTilesEnabledProvider.overrideWithValue(false),
          ],
          child: const FitApp(),
        ),
      );
      await settle(tester);
      expect(find.text('SPEED'), findsOneWidget);
      await unmount(tester);
    });
  });
}
