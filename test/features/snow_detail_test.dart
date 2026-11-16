import 'package:drift/drift.dart' show DatabaseConnection, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:fitapp/app/router.dart';
import 'package:fitapp/app/theme/app_theme.dart';
import 'package:fitapp/data/db/app_database.dart';
import 'package:fitapp/data/providers.dart';
import 'package:fitapp/data/repositories/activity_repository.dart';
import 'package:fitapp/data/repositories/settings_repository.dart';
import 'package:fitapp/features/tracking/map_style.dart';
import 'package:fitapp/features/tracking/widgets/route_map.dart';
import 'package:fitapp/widgets/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../domain/tracking/snow_fixtures.dart';
import 'snow_test_data.dart';

void main() {
  late AppDatabase db;
  late GoRouter router;
  late ProviderContainer container;
  final summary = snowSummaryOf(threeRunDay);
  const oneRunDay = [
    SnowLeg.stand(60),
    SnowLeg.lift(420),
    SnowLeg.stand(40),
    SnowLeg.run(240),
    SnowLeg.stand(60),
  ];

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

  Future<void> pumpApp(WidgetTester tester, {required String location}) async {
    tester.view
      ..physicalSize = const Size(800, 3200)
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
    router.go(location);
    await settle(tester);
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 10));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 10));
  }

  Future<String> addDay({List<SnowLeg> legs = threeRunDay}) =>
      addSnowDay(db, legs: legs);

  Future<String> addManual() => ActivityRepository(db).create(
    typeId: 'snowboarding',
    startedAt: snowStart,
    durationMinutes: 90,
    distanceMeters: 12000,
    notes: 'Powder',
  );

  String metersGrouped(int m) {
    final s = m.toString();
    return s.length > 3
        ? '${s.substring(0, s.length - 3)},${s.substring(s.length - 3)}'
        : s;
  }

  /// Run rows of the timeline in vertical order.
  Finder inTimeline(Finder f) =>
      find.descendant(of: find.byType(Group).last, matching: f);

  group('history row', () {
    testWidgets('tracked day shows runs and vertical, not distance', (
      tester,
    ) async {
      await tester.runAsync(addDay);
      await pumpApp(tester, location: Routes.history);
      expect(
        find.textContaining(
          '3 runs · ${metersGrouped(summary.dropMeters)} m ↓',
        ),
        findsOneWidget,
      );
      expect(find.textContaining(' km'), findsNothing);
      await unmount(tester);
    });

    testWidgets('manual entry keeps distance and duration', (tester) async {
      await tester.runAsync(addManual);
      await pumpApp(tester, location: Routes.history);
      expect(
        find.text('Snowboarding · 12 km · 1 h 30 min · Powder'),
        findsOneWidget,
      );
      await unmount(tester);
    });
  });

  group('detail screen', () {
    testWidgets('shows totals, legends, timeline and badges', (tester) async {
      final id = (await tester.runAsync(addDay))!;
      await pumpApp(tester, location: Routes.activity(id));
      expect(find.byType(RouteMap), findsOneWidget);
      for (final label in [
        'RUNS',
        'VERTICAL',
        'DISTANCE',
        'MAX SPEED',
        'AVG SPEED',
        'DURATION',
      ]) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      expect(find.text('3'), findsOneWidget);
      expect(find.text(metersGrouped(summary.dropMeters)), findsOneWidget);
      expect(
        find.text((summary.maxSpeedMps * 3.6).toStringAsFixed(1)),
        findsOneWidget,
      );
      expect(
        find.text(
          (summary.rideMeters / summary.rideSeconds * 3.6).toStringAsFixed(1),
        ),
        findsOneWidget,
      );
      expect(find.textContaining('Ride '), findsOneWidget);
      expect(find.textContaining('Lift '), findsOneWidget);
      expect(find.bySemanticsLabel('Speed legend'), findsOneWidget);
      expect(find.text('SPLITS'), findsNothing);
      expect(find.text('MOVING TIME'), findsNothing);
      for (final n in [1, 2, 3]) {
        expect(inTimeline(find.text('Run $n')), findsOneWidget);
      }
      expect(inTimeline(find.text('Lift')), findsNWidgets(3));
      expect(find.text('Compare runs'), findsOneWidget);

      Finder badgeOn(String badge, int run) => find.descendant(
        of: find.ancestor(
          of: inTimeline(find.text('Run $run')),
          matching: find.byType(InkWell),
        ),
        matching: find.text(badge),
      );
      expect(badgeOn('Most vertical', 1), findsOneWidget);
      expect(badgeOn('Fastest', 2), findsOneWidget);
      expect(badgeOn('Longest', 3), findsOneWidget);
      expect(badgeOn('Fastest', 1), findsNothing);
      await unmount(tester);
    });

    testWidgets('the map gets speed spans', (tester) async {
      final id = (await tester.runAsync(addDay))!;
      await pumpApp(tester, location: Routes.activity(id));
      final map = tester.widget<RouteMap>(find.byType(RouteMap));
      expect(map.spans, isNotEmpty);
      expect(map.markers.any((m) => m.kind == RouteMarkerKind.km), isFalse);
      await unmount(tester);
    });

    testWidgets('compare: sort by metric and by time', (tester) async {
      final id = (await tester.runAsync(addDay))!;
      await pumpApp(tester, location: Routes.activity(id));
      double top(int run) => tester
          .getTopLeft(
            find
                .descendant(
                  of: find.byType(Group).first,
                  matching: find.text('Run $run'),
                )
                .first,
          )
          .dy;
      await tester.tap(find.text('Distance'));
      await tester.pump();
      expect(top(3), lessThan(top(1)));
      expect(top(3), lessThan(top(2)));
      await tester.tap(find.text('By time'));
      await tester.pump();
      expect(top(1), lessThan(top(2)));
      expect(top(2), lessThan(top(3)));
      await unmount(tester);
    });

    testWidgets('a one-run day has no comparison and no badges', (
      tester,
    ) async {
      final id = (await tester.runAsync(() => addDay(legs: oneRunDay)))!;
      await pumpApp(tester, location: Routes.activity(id));
      expect(find.text('Compare runs'), findsNothing);
      expect(find.text('Run 1'), findsOneWidget);
      expect(find.text('Fastest'), findsNothing);
      expect(find.text('Longest'), findsNothing);
      expect(find.text('Most vertical'), findsNothing);
      await unmount(tester);
    });

    testWidgets('choosing Winter updates and stores the map style', (
      tester,
    ) async {
      final id = (await tester.runAsync(addDay))!;
      await pumpApp(tester, location: Routes.activity(id));
      await tester.tap(find.byTooltip('Map style'));
      await settle(tester);
      expect(find.text('Dark'), findsOneWidget);
      expect(find.text('Satellite'), findsOneWidget);
      await tester.tap(find.text('Winter'));
      await settle(tester);
      expect(container.read(mapStyleProvider), MapStyle.winter);
      expect(
        tester.widget<RouteMap>(find.byType(RouteMap)).style,
        MapStyle.winter,
      );
      final flag = await tester.runAsync(
        () => SettingsRepository(db).readFlag('map_style'),
      );
      expect(flag, 'winter');
      await unmount(tester);
    });

    testWidgets('a manual snowboarding entry shows no snow section', (
      tester,
    ) async {
      final id = (await tester.runAsync(addManual))!;
      await pumpApp(tester, location: Routes.activity(id));
      expect(find.byType(RouteMap), findsNothing);
      expect(find.text('RUNS'), findsNothing);
      expect(find.text('Compare runs'), findsNothing);
      expect(find.text('TIMELINE'), findsNothing);
      expect(find.text('DISTANCE'), findsOneWidget);
      expect(find.text('Powder'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('editing a tracked day offers only Snowboarding', (
      tester,
    ) async {
      final id = (await tester.runAsync(addDay))!;
      await pumpApp(tester, location: Routes.activity(id));
      await tester.tap(find.byTooltip('Edit activity'));
      await settle(tester);
      expect(find.text('Edit activity'), findsOneWidget);
      expect(find.text('Snowboarding'), findsWidgets);
      expect(find.text('Running'), findsNothing);
      expect(find.text('Cycling'), findsNothing);
      await unmount(tester);
    });

    testWidgets('tapping a run opens its replay', (tester) async {
      final id = (await tester.runAsync(addDay))!;
      await pumpApp(tester, location: Routes.activity(id));
      await tester.tap(inTimeline(find.text('Run 2')));
      await settle(tester);
      final last = router.routerDelegate.currentConfiguration.last;
      final location = last is ImperativeRouteMatch
          ? last.matches.uri.toString()
          : router.routerDelegate.currentConfiguration.uri.toString();
      expect(location, '/activity/$id/replay/2');
      await unmount(tester);
    });
  });
}
