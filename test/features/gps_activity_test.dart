import 'package:drift/drift.dart'
    show DatabaseConnection, Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:fitapp/app/router.dart';
import 'package:fitapp/app/theme/app_icons.dart';
import 'package:fitapp/app/theme/app_theme.dart';
import 'package:fitapp/app/theme/tokens.dart';
import 'package:fitapp/data/db/app_database.dart';
import 'package:fitapp/data/providers.dart';
import 'package:fitapp/data/repositories/activity_repository.dart';
import 'package:fitapp/domain/tracking/geo.dart';
import 'package:fitapp/features/activities/activity_detail_screen.dart';
import 'package:fitapp/features/activities/activity_icons.dart';
import 'package:fitapp/features/history/route_thumbnail.dart';
import 'package:fitapp/features/tracking/widgets/route_map.dart';
import 'package:fitapp/widgets/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  late AppDatabase db;
  late GoRouter router;
  final started = DateTime.utc(2026, 10, 10, 7);

  setUp(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    db = AppDatabase(DatabaseConnection(NativeDatabase.memory()));
  });
  tearDown(() => db.close());

  // About 2.2 km north.
  final route = encodePolyline([
    for (var i = 0; i <= 20; i++) (lat: 32.0 + i * 0.001, lon: 34.78),
  ]);

  Future<String> addGps({String type = 'running'}) async {
    final repo = ActivityRepository(db);
    final id = await repo.create(
      typeId: type,
      startedAt: started,
      durationMinutes: 12,
      distanceMeters: 2200,
      notes: 'Easy loop',
    );
    await (db.update(db.activities)..where((a) => a.id.equals(id))).write(
      ActivitiesCompanion(
        source: const Value('gps'),
        movingSeconds: const Value(700),
        elevationGainMeters: const Value(17),
        route: Value(route),
        splits: const Value('[330,300,360]'),
      ),
    );
    return id;
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump(const Duration(milliseconds: 300));
    }
  }

  Future<void> pumpApp(WidgetTester tester, {String? location}) async {
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
    router.go(location ?? Routes.history);
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

  group('decodeRouteOrNull', () {
    test('null, empty and short routes give null; decoded once', () {
      expect(decodeRouteOrNull(null), isNull);
      expect(decodeRouteOrNull(''), isNull);
      expect(decodeRouteOrNull(encodePolyline([(lat: 1.0, lon: 1.0)])), isNull);
      expect(decodeRouteOrNull('!'), isNull);
      final a = decodeRouteOrNull(route);
      expect(a, hasLength(21));
      expect(identical(a, decodeRouteOrNull(route)), isTrue);
    });
  });

  group('history rows', () {
    testWidgets('GPS and manual rows show their activity icon in accent', (
      tester,
    ) async {
      await tester.runAsync(() async {
        await addGps();
        await ActivityRepository(db).create(
          typeId: 'cycling',
          startedAt: started.add(const Duration(days: 1)),
        );
      });
      await pumpApp(tester);
      // Same icons and colour as the History calendar (feature 022).
      expect(find.byType(RouteThumbnail), findsNothing);
      expect(find.byIcon(AppIcons.cycling), findsOneWidget);
      expect(find.byIcon(AppIcons.running), findsOneWidget);
      for (final icon in [AppIcons.cycling, AppIcons.running]) {
        expect(tester.widget<Icon>(find.byIcon(icon)).color, AppColors.accent);
      }
      expect(find.byIcon(AppIcons.locationOn), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('GPS tracked')), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('the functional icon keeps its size inside the row badge', (
      tester,
    ) async {
      await tester.runAsync(
        () =>
            ActivityRepository(db)
                .create(typeId: 'functional', startedAt: started),
      );
      await pumpApp(tester);
      final icon = find.byType(FunctionalIcon);
      expect(icon, findsOneWidget);
      // 22 like the Material icons, not stretched to the badge tile (022).
      final paint = find.descendant(
        of: icon,
        matching: find.byType(CustomPaint),
      );
      expect(tester.getSize(paint), const Size.square(22));
      expect(
        (tester.widget<CustomPaint>(paint).painter! as LifterPainter).color,
        AppColors.accent,
      );
      await unmount(tester);
    });

    testWidgets('a GPS row with a broken route still shows its icon', (
      tester,
    ) async {
      await tester.runAsync(() async {
        final id = await addGps();
        await (db.update(db.activities)..where((a) => a.id.equals(id))).write(
          const ActivitiesCompanion(route: Value('!')),
        );
      });
      await pumpApp(tester);
      expect(find.byType(RouteThumbnail), findsNothing);
      expect(find.byIcon(AppIcons.running), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('tapping a GPS or a manual row opens the detail screen', (
      tester,
    ) async {
      await tester.runAsync(() async {
        await addGps();
        await ActivityRepository(db).create(
          typeId: 'pilates',
          startedAt: started.add(const Duration(days: 1)),
        );
      });
      await pumpApp(tester);
      await tester.tap(find.byIcon(AppIcons.running));
      await settle(tester);
      expect(find.text('Easy loop'), findsOneWidget);
      expect(find.text('Splits'), findsOneWidget);
      router.pop();
      await settle(tester);
      await tester.tap(find.byIcon(AppIcons.pilates));
      await settle(tester);
      expect(find.byType(ActivityDetailScreen), findsOneWidget);
      expect(find.byTooltip('Edit activity'), findsOneWidget);
      expect(find.text('Log a past session'), findsNothing);
      await unmount(tester);
    });
  });

  group('detail screen', () {
    testWidgets('manual activity: metrics and note, no map, Edit opens sheet', (
      tester,
    ) async {
      final id = (await tester.runAsync(
        () => ActivityRepository(db).create(
          typeId: 'running',
          startedAt: started,
          durationMinutes: 30,
          distanceMeters: 5000,
          notes: 'Felt good',
        ),
      ))!;
      await pumpApp(tester, location: Routes.activity(id));
      expect(find.byType(RouteMap), findsNothing);
      expect(find.text('Distance'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
      expect(find.text('Duration'), findsOneWidget);
      expect(find.text('Avg pace'), findsOneWidget);
      expect(find.text('Moving time'), findsNothing);
      expect(find.text('Climb'), findsNothing);
      expect(find.text('Splits'), findsNothing);
      expect(find.text('Note'), findsOneWidget);
      expect(find.text('Felt good'), findsOneWidget);
      expect(find.byTooltip('Delete activity'), findsOneWidget);
      await tester.tap(find.byTooltip('Edit activity'));
      await settle(tester);
      expect(find.text('Edit activity'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('a bare manual Pilates activity shows no empty tiles', (
      tester,
    ) async {
      final id = (await tester.runAsync(
        () =>
            ActivityRepository(db)
                .create(typeId: 'pilates', startedAt: started),
      ))!;
      await pumpApp(tester, location: Routes.activity(id));
      expect(find.text('Pilates'), findsOneWidget);
      expect(find.byType(RouteMap), findsNothing);
      expect(find.byType(MetricTile), findsNothing);
      expect(find.text('Note'), findsNothing);
      await unmount(tester);
    });

    testWidgets('shows metrics, splits and note', (tester) async {
      final id = (await tester.runAsync(addGps))!;
      await pumpApp(tester, location: Routes.activity(id));
      expect(find.byType(RouteMap), findsOneWidget);
      expect(find.text('Running'), findsOneWidget);
      expect(find.text('Distance'), findsOneWidget);
      expect(find.text('2.2'), findsOneWidget);
      expect(find.text('Moving time'), findsOneWidget);
      expect(find.text('11:40'), findsOneWidget);
      expect(find.text('Avg pace'), findsOneWidget);
      expect(find.text('Climb'), findsOneWidget);
      expect(find.text('km 1'), findsOneWidget);
      expect(find.text('5:30'), findsOneWidget);
      expect(find.text('5:00'), findsOneWidget);
      expect(find.text('6:00'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('fastest')), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('cycling shows average speed', (tester) async {
      final id = (await tester.runAsync(() => addGps(type: 'cycling')))!;
      await pumpApp(tester, location: Routes.activity(id));
      expect(find.text('Avg speed'), findsOneWidget);
      expect(find.text('Avg pace'), findsNothing);
      await unmount(tester);
    });

    testWidgets('Edit keeps GPS data and hides duration and distance', (
      tester,
    ) async {
      final id = (await tester.runAsync(addGps))!;
      await pumpApp(tester, location: Routes.activity(id));
      await tester.tap(find.byTooltip('Edit activity'));
      await settle(tester);
      expect(find.text('Edit activity'), findsOneWidget);
      expect(find.text('Set'), findsNothing);
      expect(find.byType(ChipSelector<bool>), findsNothing);
      expect(find.textContaining('come from the GPS'), findsOneWidget);
      expect(find.text('Pilates'), findsNothing);
      await tester.enterText(find.byType(TextField), 'Tempo');
      await tester.tap(find.text('Save'));
      await settle(tester);
      final a = (await tester.runAsync(
        () => ActivityRepository(db).activity(id),
      ))!;
      expect(a.notes, 'Tempo');
      expect(a.source, 'gps');
      expect(a.route, route);
      expect(a.splits, '[330,300,360]');
      expect(a.durationMinutes, 12);
      expect(a.distanceMeters, 2200);
      expect(find.text('Tempo'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('Delete confirms, deletes and pops', (tester) async {
      final id = (await tester.runAsync(addGps))!;
      await pumpApp(tester);
      await tester.tap(find.byIcon(AppIcons.running));
      await settle(tester);
      await tester.tap(find.byTooltip('Delete activity'));
      await settle(tester);
      expect(find.text('Delete activity?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await settle(tester);
      expect(
        await tester.runAsync(() => ActivityRepository(db).activity(id)),
        isNotNull,
      );
      await tester.tap(find.byTooltip('Delete activity'));
      await settle(tester);
      await tester.tap(find.text('Delete'));
      await settle(tester);
      expect(
        await tester.runAsync(() => ActivityRepository(db).activity(id)),
        isNull,
      );
      expect(find.byType(RouteMap), findsNothing);
      expect(find.text('Delete activity?'), findsNothing);
      await unmount(tester);
    });

    testWidgets('an unknown id shows an empty state', (tester) async {
      await pumpApp(tester, location: Routes.activity('nope'));
      expect(find.text('Activity not found'), findsOneWidget);
      await unmount(tester);
    });
  });
}
