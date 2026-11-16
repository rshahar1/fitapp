import 'package:drift/drift.dart' show DatabaseConnection, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:fitapp/app/router.dart';
import 'package:fitapp/app/theme/app_theme.dart';
import 'package:fitapp/data/db/app_database.dart';
import 'package:fitapp/data/providers.dart';
import 'package:fitapp/data/repositories/activity_repository.dart';
import 'package:fitapp/features/tracking/widgets/route_map.dart';
import 'package:fitapp/widgets/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'snow_test_data.dart';

void main() {
  late AppDatabase db;
  late GoRouter router;

  setUp(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    db = AppDatabase(DatabaseConnection(NativeDatabase.memory()));
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

  Future<void> open(WidgetTester tester, String location) async {
    tester.view
      ..physicalSize = const Size(800, 1600)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    router = buildRouter();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          mapTilesEnabledProvider.overrideWithValue(false),
          routerProvider.overrideWithValue(router),
        ],
        child: MaterialApp.router(theme: buildAppTheme(), routerConfig: router),
      ),
    );
    router.go(location);
    await settle(tester);
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 10));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
  }

  String tile(WidgetTester tester, String label) {
    final t = tester.widget<MetricTile>(
      find.byWidgetPredicate((w) => w is MetricTile && w.label == label),
    );
    return t.value;
  }

  int seconds(WidgetTester tester) {
    final parts = tile(tester, 'Time').split(':').map(int.parse).toList();
    return parts[0] * 60 + parts[1];
  }

  Future<void> run(WidgetTester tester, int secs) async {
    for (var i = 0; i < secs * 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  const id = '00000000-0000-4000-8000-0000000000a1';

  group('snow replay', () {
    testWidgets('shows the readout at the start with a Play button', (
      tester,
    ) async {
      await addSnowDay(db);
      await open(tester, '/activity/$id/replay/2');
      expect(find.text('Run 2 replay'), findsOneWidget);
      expect(find.byType(MetricTile), findsNWidgets(3));
      expect(tile(tester, 'Time'), '0:00');
      expect(find.byTooltip('Play'), findsOneWidget);
      expect(find.byType(Slider), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('plays at 4x, pauses and freezes', (tester) async {
      await addSnowDay(db);
      await open(tester, '/activity/$id/replay/2');
      await tester.tap(find.byTooltip('Play'));
      await tester.pump();
      await run(tester, 5);
      final t = seconds(tester);
      expect(t, inInclusiveRange(15, 25));
      expect(find.byTooltip('Pause'), findsOneWidget);
      await tester.tap(find.byTooltip('Pause'));
      await tester.pump();
      final frozen = tile(tester, 'Time');
      await run(tester, 3);
      expect(tile(tester, 'Time'), frozen);
      expect(find.byTooltip('Play'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('16x reaches the end, stops, and Play restarts', (
      tester,
    ) async {
      await addSnowDay(db);
      await open(tester, '/activity/$id/replay/2');
      await tester.tap(find.text('16×'));
      await tester.pump();
      await tester.tap(find.byTooltip('Play'));
      await tester.pump();
      await run(tester, 15);
      expect(find.byTooltip('Play'), findsOneWidget);
      final total = tester
          .widget<MetricTile>(
            find.byWidgetPredicate((w) => w is MetricTile && w.label == 'Time'),
          )
          .caption!
          .replaceFirst('of ', '');
      expect(tile(tester, 'Time'), total);
      await tester.tap(find.byTooltip('Play'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      expect(seconds(tester), lessThan(5));
      await tester.tap(find.byTooltip('Pause'));
      await tester.pump();
      await unmount(tester);
    });

    testWidgets('scrubbing sets the position and speed', (tester) async {
      await addSnowDay(db);
      await open(tester, '/activity/$id/replay/2');
      final slider = find.byType(Slider);
      final rect = tester.getRect(slider);
      await tester.tapAt(rect.center);
      await tester.pump();
      expect(seconds(tester), inInclusiveRange(40, 110));
      expect(int.parse(tile(tester, 'Speed')), greaterThan(0));
      await tester.tapAt(Offset(rect.right - 1, rect.center.dy));
      await tester.pump();
      final total = tester
          .widget<MetricTile>(
            find.byWidgetPredicate((w) => w is MetricTile && w.label == 'Time'),
          )
          .caption!
          .replaceFirst('of ', '');
      expect(tile(tester, 'Time'), total);
      await unmount(tester);
    });

    testWidgets('the map fits the run and shows the current point', (
      tester,
    ) async {
      await addSnowDay(db);
      await open(tester, '/activity/$id/replay/2');
      final map = tester.widget<RouteMap>(find.byType(RouteMap));
      expect(map.fitTo, isNotNull);
      expect(map.fitTo!.length, greaterThan(10));
      expect(map.route, map.fitTo);
      expect(map.current, isNotNull);
      await unmount(tester);
    });

    for (final (name, location) in [
      ('unknown activity', '/activity/nope/replay/1'),
      ('missing run', '/activity/$id/replay/9'),
    ]) {
      testWidgets('$name is not available', (tester) async {
        await addSnowDay(db);
        await open(tester, location);
        expect(find.text('Replay not available'), findsOneWidget);
        expect(find.byType(Slider), findsNothing);
        await unmount(tester);
      });
    }

    testWidgets('a manual activity is not available', (tester) async {
      final manual = await ActivityRepository(db).create(
        typeId: 'snowboarding',
        startedAt: DateTime.utc(2026, 2),
        durationMinutes: 60,
      );
      await open(tester, '/activity/$manual/replay/1');
      expect(find.text('Replay not available'), findsOneWidget);
      expect(find.byType(Slider), findsNothing);
      await unmount(tester);
    });
  });
}
