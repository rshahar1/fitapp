import 'package:drift/drift.dart' show DatabaseConnection, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:fitapp/app/router.dart';
import 'package:fitapp/app/theme/app_theme.dart';
import 'package:fitapp/app/theme/tokens.dart';
import 'package:fitapp/core/haptics.dart';
import 'package:fitapp/data/db/app_database.dart';
import 'package:fitapp/data/providers.dart';
import 'package:fitapp/data/repositories/template_repository.dart';
import 'package:fitapp/data/repositories/tracking_repository.dart';
import 'package:fitapp/data/repositories/workout_repository.dart';
import 'package:fitapp/domain/activity_types.dart';
import 'package:fitapp/features/activities/activity_icons.dart';
import 'package:fitapp/features/start/start_hub_sheet.dart';
import 'package:fitapp/features/tracking/widgets/route_map.dart';
import 'package:fitapp/widgets/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../data/fake_location_source.dart';

const _inclineId = '00000000-0000-4000-8000-000000000002';
const _plus = 'Start or log a session';

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

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 10));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 10));
  }

  /// Current location, including routes pushed on top of the shell.
  String location() {
    final config = router.routerDelegate.currentConfiguration;
    final last = config.last;
    if (last is ImperativeRouteMatch) return last.matches.uri.toString();
    return config.uri.toString();
  }

  /// A bottom-bar tab (the only semantics nodes with a selected state).
  Finder tab(String label) => find.byWidgetPredicate(
    (w) =>
        w is Semantics &&
        w.properties.label == label &&
        w.properties.selected != null,
  );

  Future<void> pumpApp(WidgetTester tester, {String? at}) async {
    tester.view
      ..physicalSize = const Size(800, 1600)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    router = buildRouter();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          hapticsProvider.overrideWithValue(_Haptics()),
          locationSourceProvider.overrideWithValue(FakeLocationSource()),
          mapTilesEnabledProvider.overrideWithValue(false),
          routerProvider.overrideWithValue(router),
        ],
        child: MaterialApp.router(theme: buildAppTheme(), routerConfig: router),
      ),
    );
    if (at != null) router.go(at);
    await settle(tester);
  }

  Future<void> openHub(WidgetTester tester) async {
    await tester.tap(find.byTooltip(_plus));
    await settle(tester);
  }

  Future<void> startTracking() =>
      TrackingRepository(db)
          .start(typeId: 'running', startedAt: DateTime.now().toUtc());

  Future<WorkoutRow?> activeWorkout() => WorkoutRepository(db).activeWorkout();

  group('bottom bar', () {
    testWidgets('five slots; + is labelled and at least 48 dp', (tester) async {
      await pumpApp(tester);
      for (final label in ['Train', 'History', 'Progress', 'You']) {
        expect(tab(label), findsOneWidget);
      }
      final plus = tester.getSize(find.byTooltip(_plus));
      expect(plus.width, greaterThanOrEqualTo(48));
      expect(plus.height, greaterThanOrEqualTo(48));
      expect(find.bySemanticsLabel(_plus), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('hub opens from every tab and keeps the tab', (tester) async {
      await pumpApp(tester);
      for (final at in [
        Routes.train,
        Routes.history,
        Routes.progress,
        Routes.you,
      ]) {
        router.go(at);
        await settle(tester);
        await openHub(tester);
        expect(find.text('Start or log'), findsOneWidget, reason: at);
        expect(find.text('Log a past session'), findsOneWidget, reason: at);
        expect(location(), at);
        Navigator.of(tester.element(find.text('Start or log'))).pop();
        await settle(tester);
        expect(find.text('Start or log'), findsNothing);
        expect(location(), at);
      }
      await unmount(tester);
    });

    testWidgets('You tab opens Settings and the Gym Exercise Library', (
      tester,
    ) async {
      await pumpApp(tester);
      await tester.tap(tab('You'));
      await settle(tester);
      expect(location(), Routes.you);
      await tester.tap(find.text('Settings'));
      await settle(tester);
      expect(location(), Routes.settings);
      router.pop();
      await settle(tester);
      await tester.tap(find.text('Gym Exercise Library'));
      await settle(tester);
      expect(location(), Routes.exercises);
      await unmount(tester);
    });
  });

  group('Train', () {
    testWidgets('no empty gym start, header icons or Log activity', (
      tester,
    ) async {
      await pumpApp(tester);
      expect(find.text('START GYM WORKOUT'), findsNothing);
      expect(find.byTooltip('Settings'), findsNothing);
      expect(find.byTooltip('Exercises'), findsNothing);
      expect(find.text('LOG ACTIVITY'), findsNothing);
      await unmount(tester);
    });

    testWidgets('template starts in one tap', (tester) async {
      await tester.runAsync(
        () =>
            TemplateRepository(db)
                .create(name: 'Push', exerciseIds: [_inclineId]),
      );
      await pumpApp(tester);
      await tester.tap(find.bySemanticsLabel('Start Push template'));
      await settle(tester);
      expect(location(), Routes.workout);
      expect(await tester.runAsync(activeWorkout), isNotNull);
      await unmount(tester);
    });

    testWidgets('GPS session shows in the hero; template START is blocked', (
      tester,
    ) async {
      await tester.runAsync(() async {
        await TemplateRepository(db)
            .create(name: 'Push', exerciseIds: [_inclineId]);
        await startTracking();
      });
      await pumpApp(tester);
      expect(find.text('Running in progress'), findsOneWidget);
      expect(find.text('CONTINUE RUNNING'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Start Push template'));
      await settle(tester);
      expect(
        find.text('Running in progress. Finish it first.'),
        findsOneWidget,
      );
      expect(find.text('Open'), findsOneWidget);
      expect(await tester.runAsync(activeWorkout), isNull);
      expect(location(), Routes.train);
      await unmount(tester);
    });
  });

  group('hub starts', () {
    testWidgets('Running routes to the GPS setup', (tester) async {
      await pumpApp(tester, at: Routes.history);
      await openHub(tester);
      await tester.tap(find.text('Running'));
      await settle(tester);
      expect(location(), '/track/new?type=running');
      await unmount(tester);
    });

    testWidgets('Snowboarding is listed with the live-tracking sports', (
      tester,
    ) async {
      await pumpApp(tester, at: Routes.history);
      await openHub(tester);
      for (final sport in ['Running', 'Cycling', 'Snowboarding']) {
        expect(
          find.descendant(
            of: find.widgetWithText(GroupRow, sport),
            matching: find.text('Live GPS'),
          ),
          findsOneWidget,
          reason: sport,
        );
      }
      expect(find.text('More sports'), findsNothing);
      await unmount(tester);
    });

    testWidgets('while running: Continue first, then the sports', (
      tester,
    ) async {
      await tester.runAsync(startTracking);
      await pumpApp(tester, at: Routes.history);
      await openHub(tester);
      final cont = tester.getTopLeft(find.text('Continue running'));
      final sport = tester.getTopLeft(find.text('Cycling'));
      expect(cont.dy, lessThan(sport.dy));
      await unmount(tester);
    });

    testWidgets('has no Gym workout, template rows or More sports', (
      tester,
    ) async {
      await tester.runAsync(
        () =>
            TemplateRepository(db)
                .create(name: 'Legs', exerciseIds: [_inclineId]),
      );
      await pumpApp(tester, at: Routes.you);
      await openHub(tester);
      expect(find.text('Gym workout'), findsNothing);
      expect(find.text('Legs'), findsNothing);
      expect(find.text('More sports'), findsNothing);
      await unmount(tester);
    });

    testWidgets('lists every activity type without expanding', (tester) async {
      await pumpApp(tester);
      await openHub(tester);
      for (final t in activityTypes) {
        final row = find.text(t.label);
        await tester.scrollUntilVisible(
          row,
          100,
          scrollable: find.descendant(
            of: find.byType(StartHubSheet),
            matching: find.byType(Scrollable),
          ),
        );
        expect(row, findsOneWidget, reason: t.label);
      }
      await unmount(tester);
    });

    testWidgets('Functional training shows the weightlifter icon', (
      tester,
    ) async {
      await pumpApp(tester);
      await openHub(tester);
      await tester.scrollUntilVisible(
        find.byType(FunctionalIcon),
        100,
        scrollable: find.descendant(
          of: find.byType(StartHubSheet),
          matching: find.byType(Scrollable),
        ),
      );
      expect(find.byType(FunctionalIcon), findsOneWidget);
      expect(find.byIcon(Icons.sports_gymnastics), findsNothing);
      // Drawn in the row's icon colour, like the other activities (022).
      final paint = tester.widget<CustomPaint>(
        find.descendant(
          of: find.byType(FunctionalIcon),
          matching: find.byType(CustomPaint),
        ),
      );
      expect((paint.painter! as LifterPainter).color, AppColors.textSecondary);
      await unmount(tester);
    });

    testWidgets('while a workout is active: Running blocked, Open goes to it', (
      tester,
    ) async {
      await tester.runAsync(() => WorkoutRepository(db).startWorkout());
      await pumpApp(tester, at: Routes.history);
      await openHub(tester);
      expect(find.text('Continue workout'), findsOneWidget);
      await tester.tap(find.text('Running'));
      await settle(tester);
      expect(
        find.text('Workout in progress. Finish it first.'),
        findsOneWidget,
      );
      expect(location(), Routes.history);
      expect(
        await tester.runAsync(() => TrackingRepository(db).session()),
        isNull,
      );
      await tester.tap(find.text('Open'));
      await settle(tester);
      expect(location(), Routes.workout);
      await unmount(tester);
    });

    testWidgets('Continue workout opens the workout', (tester) async {
      await tester.runAsync(() => WorkoutRepository(db).startWorkout());
      await pumpApp(tester, at: Routes.progress);
      await openHub(tester);
      await tester.tap(find.text('Continue workout'));
      await settle(tester);
      expect(location(), Routes.workout);
      await unmount(tester);
    });
  });

  group('logging the past', () {
    testWidgets('Log a past session has no Start live, even while running', (
      tester,
    ) async {
      await tester.runAsync(startTracking);
      await pumpApp(tester);
      await openHub(tester);
      await tester.tap(find.text('Log a past session'));
      await settle(tester);
      expect(find.text('Log a past session'), findsOneWidget); // form title
      await tester.tap(find.text('Running'));
      await settle(tester);
      expect(find.text('START LIVE'), findsNothing);
      expect(find.text('Start live'), findsNothing);
      expect(find.text('or log it manually below'), findsNothing);
      expect(find.text('DISTANCE'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('Pilates opens the form for today', (tester) async {
      await pumpApp(tester);
      await openHub(tester);
      await tester.tap(find.text('Pilates'));
      await settle(tester);
      expect(find.text('Today'), findsOneWidget);
      await tester.tap(find.text('SAVE'));
      await settle(tester);
      final rows = await tester.runAsync(() => db.select(db.activities).get());
      expect(rows!.single.typeId, 'pilates');
      await unmount(tester);
    });
  });
}
