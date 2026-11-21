import 'dart:async';

import 'package:drift/drift.dart' show DatabaseConnection, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:fitapp/app/router.dart';
import 'package:fitapp/app/theme/app_theme.dart';
import 'package:fitapp/core/haptics.dart';
import 'package:fitapp/data/db/app_database.dart';
import 'package:fitapp/data/providers.dart';
import 'package:fitapp/data/repositories/activity_repository.dart';
import 'package:fitapp/features/tracking/tracking_controller.dart';
import 'package:fitapp/features/tracking/widgets/route_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/fake_location_source.dart';
import '../../domain/tracking/snow_fixtures.dart';

class _Haptics implements Haptics {
  @override
  void tick() {}
  @override
  void success() {}
  @override
  void warning() {}
}

void main() {
  late AppDatabase db;
  late FakeLocationSource source;
  late DateTime now;
  late GoRouter router;
  final day = buildSnowDay(plainDay).samples;

  setUp(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    db = AppDatabase(DatabaseConnection(NativeDatabase.memory()));
    source = FakeLocationSource();
    now = snowStart;
  });
  tearDown(() => db.close());

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

  Future<void> goLive(
    WidgetTester tester, {
    String type = 'snowboarding',
    Size size = const Size(800, 1600),
  }) async {
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    router = buildRouter();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          hapticsProvider.overrideWithValue(_Haptics()),
          locationSourceProvider.overrideWithValue(source),
          clockProvider.overrideWithValue(() => now),
          mapTilesEnabledProvider.overrideWithValue(false),
          routerProvider.overrideWithValue(router),
          trackingFlushCountProvider.overrideWithValue(1000000),
          trackingFlushIntervalProvider.overrideWithValue(
            const Duration(hours: 1),
          ),
        ],
        child: MaterialApp.router(theme: buildAppTheme(), routerConfig: router),
      ),
    );
    await settle(tester);
    unawaited(router.push(Routes.newTrack(type)));
    await settle(tester);
    source.emit(day.first);
    await tester.pump();
    await tester.tap(find.text('Start'));
    await settle(tester);
  }

  /// Replays fixes [from]..[to] of the ski day, then pumps once.
  Future<void> replay(WidgetTester tester, int from, int to) async {
    for (var i = from; i <= to && i < day.length; i++) {
      now = day[i].t;
      source.emit(day[i]);
    }
    await tester.pump(const Duration(seconds: 1));
  }

  Future<void> hold(WidgetTester tester, Finder f, [int ms = 1100]) async {
    final g = await tester.startGesture(tester.getCenter(f));
    await tester.pump();
    await tester.pump(Duration(milliseconds: ms));
    await g.up();
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> toSheet(WidgetTester tester, {Size? size}) async {
    await goLive(tester, size: size ?? const Size(800, 1600));
    await replay(tester, 1, day.length);
    await hold(tester, find.text('Finish'));
    await settle(tester);
  }

  group('snowboarding live screen', () {
    testWidgets('shows the snow tiles after a full day', (tester) async {
      final semantics = tester.ensureSemantics();
      await goLive(tester);
      await replay(tester, 1, day.length);
      expect(find.text('km/h'), findsWidgets);
      expect(find.text('Runs'), findsOneWidget);
      expect(
        find.descendant(
          of: find.bySemanticsLabel('Runs: 3'),
          matching: find.text('3'),
        ),
        findsOneWidget,
      );
      expect(find.text('Vertical'), findsOneWidget);
      expect(find.text('Max speed'), findsOneWidget);
      expect(find.text('Avg speed'), findsOneWidget);
      expect(find.text('Distance'), findsOneWidget);
      expect(find.text('Elapsed'), findsOneWidget);
      expect(find.text('Resting'), findsOneWidget);
      expect(find.bySemanticsLabel('Status: Resting'), findsOneWidget);
      expect(find.text('Avg pace'), findsNothing);
      expect(find.text('Last km'), findsNothing);
      semantics.dispose();
      await unmount(tester);
    });

    testWidgets('status chip follows the lift and the run', (tester) async {
      await goLive(tester);
      await replay(tester, 1, 300);
      expect(find.text('On lift'), findsOneWidget);
      await replay(tester, 301, 650);
      expect(find.text('Riding'), findsOneWidget);
      expect(find.text('On lift'), findsNothing);
      await unmount(tester);
    });

    testWidgets('pause shows Paused and Resume works', (tester) async {
      await goLive(tester);
      await replay(tester, 1, 300);
      await tester.tap(find.text('Pause'));
      await settle(tester);
      expect(find.text('Paused'), findsOneWidget);
      expect(find.text('On lift'), findsNothing);
      await tester.tap(find.text('Resume'));
      await settle(tester);
      expect(find.text('Paused'), findsNothing);
      expect(find.text('Pause'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('does not overflow at 360 x 640', (tester) async {
      await goLive(tester, size: const Size(360, 640));
      await replay(tester, 1, day.length);
      expect(tester.takeException(), isNull);
      expect(find.text('Runs'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('running keeps its own tiles', (tester) async {
      await goLive(tester, type: 'running');
      expect(find.text('Avg pace'), findsOneWidget);
      expect(find.text('Last km'), findsOneWidget);
      expect(find.text('Runs'), findsNothing);
      await unmount(tester);
    });
  });

  group('snowboarding finish sheet', () {
    testWidgets('shows the snow summary and saves it', (tester) async {
      await toSheet(tester);
      expect(find.text('Snowboarding summary'), findsOneWidget);
      expect(find.text('Runs'), findsWidgets);
      expect(find.text('Vertical'), findsWidgets);
      expect(find.text('Max speed'), findsWidgets);
      expect(find.text('Time'), findsWidgets);
      expect(find.text('Climb'), findsNothing);
      expect(find.textContaining('Ride'), findsWidgets);
      expect(find.textContaining('Lift'), findsWidgets);
      expect(find.textContaining('Rest'), findsWidgets);
      await tester.tap(find.text('Save'));
      await settle(tester);
      final rows = (await tester.runAsync(
        () => ActivityRepository(db).list(),
      ))!;
      expect(rows, hasLength(1));
      expect(rows.single.typeId, 'snowboarding');
      expect(rows.single.runCount, 3);
      await unmount(tester);
    });

    testWidgets('does not overflow at 360 x 640', (tester) async {
      await toSheet(tester, size: const Size(360, 640));
      expect(tester.takeException(), isNull);
      expect(find.text('Runs'), findsWidgets);
      await unmount(tester);
    });
  });
}
