import 'package:drift/drift.dart' show DatabaseConnection, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:fitapp/app/router.dart';
import 'package:fitapp/app/theme/app_theme.dart';
import 'package:fitapp/core/haptics.dart';
import 'package:fitapp/data/db/app_database.dart';
import 'package:fitapp/data/providers.dart';
import 'package:fitapp/data/repositories/activity_repository.dart';
import 'package:fitapp/data/repositories/workout_repository.dart';
import 'package:fitapp/features/activities/activity_icons.dart';
import 'package:fitapp/features/activities/activity_sheet.dart';
import 'package:fitapp/features/history/history_screen.dart';
import 'package:fitapp/widgets/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

const _inclineId = '00000000-0000-4000-8000-000000000002';

class _FakeHaptics implements Haptics {
  @override
  void tick() {}
  @override
  void success() {}
  @override
  void warning() {}
}

class _Host extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: AppButton(
        label: 'Open sheet',
        onPressed: () => showActivitySheet(context),
      ),
    ),
  );
}

void main() {
  late AppDatabase db;

  setUp(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    db = AppDatabase(DatabaseConnection(NativeDatabase.memory()));
  });
  tearDown(() => db.close());

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 10));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 10));
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  Future<void> pump(WidgetTester tester, Widget home) async {
    tester.view
      ..physicalSize = const Size(800, 1600)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          hapticsProvider.overrideWithValue(_FakeHaptics()),
        ],
        child: MaterialApp(theme: buildAppTheme(), home: home),
      ),
    );
    await settle(tester);
  }

  // History inside the real router, so rows can push the detail screen.
  Future<void> pumpHistory(WidgetTester tester) async {
    tester.view
      ..physicalSize = const Size(800, 1600)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final router = buildRouter();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          hapticsProvider.overrideWithValue(_FakeHaptics()),
          routerProvider.overrideWithValue(router),
        ],
        child: MaterialApp.router(theme: buildAppTheme(), routerConfig: router),
      ),
    );
    router.go(Routes.history);
    await settle(tester);
  }

  Future<void> openRowThenEdit(WidgetTester tester, String row) async {
    await tester.tap(find.text(row));
    await settle(tester);
    await tester.tap(find.byTooltip('Edit activity'));
    await settle(tester);
  }

  Future<List<ActivityRow>> activities(WidgetTester tester) => tester
      .runAsync(() => ActivityRepository(db).list())
      .then((v) => v ?? const []);

  Future<void> openSheet(WidgetTester tester) async {
    await tester.tap(find.text('OPEN SHEET'));
    await tester.pumpAndSettle();
  }

  Future<void> save(WidgetTester tester) async {
    await tester.tap(find.text('SAVE'));
    await settle(tester);
  }

  bool saveEnabled(WidgetTester tester) =>
      tester
          .widget<TextButton>(
            find.ancestor(
              of: find.text('SAVE'),
              matching: find.byType(TextButton),
            ),
          )
          .onPressed !=
      null;

  testWidgets('Sheet: log a running activity dated today', (tester) async {
    await pump(tester, const _Host());
    await openSheet(tester);
    expect(find.text('Log a past session'), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
    await tester.tap(find.text('Running'));
    await tester.pump();
    await save(tester);

    final list = await activities(tester);
    expect(list, hasLength(1));
    expect(list.single.typeId, 'running');
    final d = list.single.startedAt.toLocal();
    final n = DateTime.now();
    expect(DateTime(d.year, d.month, d.day), DateTime(n.year, n.month, n.day));
    expect(list.single.durationMinutes, isNull);
    expect(find.text('Log a past session'), findsNothing);
    await unmount(tester);
  });

  testWidgets('Save is disabled until a type is chosen', (tester) async {
    await pump(tester, const _Host());
    await openSheet(tester);
    expect(saveEnabled(tester), isFalse);
    await tester.tap(find.text('Cycling'));
    await tester.pump();
    expect(saveEnabled(tester), isTrue);
    await unmount(tester);
  });

  testWidgets('duration set via the stepper is stored', (tester) async {
    await pump(tester, const _Host());
    await openSheet(tester);
    await tester.tap(find.text('Cycling'));
    await tester.tap(find.text('Set'));
    await tester.pump();
    final value = find.descendant(
      of: find.byKey(const Key('duration-value')),
      matching: find.text('30 min'),
    );
    expect(value, findsOneWidget);
    final plus = find.descendant(
      of: find.byType(DurationPicker),
      matching: find.byIcon(Icons.add),
    );
    await tester.tap(plus);
    await tester.pump();
    await tester.tap(plus);
    await tester.pump();
    expect(find.text('40 min'), findsOneWidget);
    await save(tester);

    final list = await activities(tester);
    expect(list.single.typeId, 'cycling');
    expect(list.single.durationMinutes, 40);
    await unmount(tester);
  });

  testWidgets('4 h preset is stored as 240 minutes', (tester) async {
    await pump(tester, const _Host());
    await openSheet(tester);
    await tester.tap(find.text('Cycling'));
    await tester.tap(find.text('Set'));
    await tester.pump();
    await tester.tap(find.text('4 h'));
    await tester.pump();
    await save(tester);

    final list = await activities(tester);
    expect(list.single.durationMinutes, 240);
    await unmount(tester);
  });

  testWidgets('Pilates chip is offered and has no distance', (tester) async {
    await pump(tester, const _Host());
    await openSheet(tester);
    expect(find.text('Pilates'), findsOneWidget);
    await tester.tap(find.text('Pilates'));
    await tester.pump();
    expect(find.text('DISTANCE'), findsNothing);
    await save(tester);
    expect((await activities(tester)).single.typeId, 'pilates');
    await unmount(tester);
  });

  testWidgets('Distance section only for running and cycling', (tester) async {
    await pump(tester, const _Host());
    await openSheet(tester);
    expect(find.text('DISTANCE'), findsNothing);
    await tester.tap(find.text('Snowboarding'));
    await tester.pump();
    expect(find.text('DISTANCE'), findsNothing);
    await tester.tap(find.text('Running'));
    await tester.pump();
    expect(find.text('DISTANCE'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('distance typed in km is stored in metres', (tester) async {
    await pump(tester, const _Host());
    await openSheet(tester);
    await tester.tap(find.text('Running'));
    await tester.pump();
    // The second "Set" belongs to Distance (Duration is first).
    await tester.tap(find.text('Set').last);
    await tester.pump();
    await tester.enterText(find.byType(TextField).first, '5,2');
    await tester.pump();
    await save(tester);
    expect((await activities(tester)).single.distanceMeters, 5200);
    await unmount(tester);
  });

  testWidgets('invalid distance disables Save', (tester) async {
    await pump(tester, const _Host());
    await openSheet(tester);
    await tester.tap(find.text('Cycling'));
    await tester.pump();
    await tester.tap(find.text('Set').last);
    await tester.pump();
    expect(saveEnabled(tester), isFalse);
    await tester.enterText(find.byType(TextField).first, 'abc');
    await tester.pump();
    expect(saveEnabled(tester), isFalse);
    expect(find.text('Enter a distance up to 1000 km'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, '12.5');
    await tester.pump();
    expect(saveEnabled(tester), isTrue);
    await unmount(tester);
  });

  testWidgets('edit pre-fills distance; switching to Pilates drops it', (
    tester,
  ) async {
    await tester.runAsync(
      () => ActivityRepository(db).create(
        typeId: 'running',
        startedAt: DateTime.now(),
        durationMinutes: 28,
        distanceMeters: 5200,
      ),
    );
    await pumpHistory(tester);
    expect(find.text('Running · 5.2 km · 28 min · 5:23 /km'), findsOneWidget);
    await openRowThenEdit(tester, 'Running · 5.2 km · 28 min · 5:23 /km');
    expect(find.widgetWithText(TextField, '5.2'), findsOneWidget);
    await tester.tap(find.text('Pilates'));
    await tester.pump();
    await save(tester);
    final a = (await activities(tester)).single;
    expect(a.typeId, 'pilates');
    expect(a.distanceMeters, isNull);
    await unmount(tester);
  });

  testWidgets('History shows cycling speed', (tester) async {
    await tester.runAsync(
      () => ActivityRepository(db).create(
        typeId: 'cycling',
        startedAt: DateTime.now(),
        durationMinutes: 90,
        distanceMeters: 36750,
        notes: 'hills',
      ),
    );
    await pump(tester, const HistoryScreen());
    expect(
      find.text('Cycling · 36.75 km · 1 h 30 min · 24.5 km/h · hills'),
      findsOneWidget,
    );
    await unmount(tester);
  });

  Future<void> seedHistory(WidgetTester tester) => tester.runAsync(() async {
    final repo = WorkoutRepository(db);
    final w = await repo.startWorkout();
    final we = await repo.addExercise(w.id, _inclineId);
    await repo.logSet(we.id, setNo: 1, weight: 20, reps: 10);
    await repo.finishWorkout(w.id);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await ActivityRepository(
      db,
    ).create(typeId: 'running', startedAt: DateTime.now(), durationMinutes: 45);
  });

  testWidgets('History shows gym and running icons, newest first', (
    tester,
  ) async {
    await seedHistory(tester);
    await pump(tester, const HistoryScreen());
    expect(find.byIcon(gymWorkoutIcon), findsOneWidget);
    expect(find.byIcon(activityIcon('running')), findsOneWidget);
    expect(find.text('Running · 45 min'), findsOneWidget);
    expect(
      tester.getTopLeft(find.byIcon(activityIcon('running'))).dy,
      lessThan(tester.getTopLeft(find.byIcon(gymWorkoutIcon)).dy),
    );
    await unmount(tester);
  });

  testWidgets('History: edit an activity to Cycling', (tester) async {
    await seedHistory(tester);
    await pumpHistory(tester);
    await openRowThenEdit(tester, 'Running · 45 min');
    expect(find.text('Edit activity'), findsOneWidget);
    await tester.tap(find.text('Cycling'));
    await tester.pump();
    await save(tester);

    final list = await activities(tester);
    expect(list.single.typeId, 'cycling');
    expect(list.single.durationMinutes, 45);
    // The detail screen reflects the edit.
    expect(find.text('Cycling'), findsOneWidget);
    expect(find.text('45 min'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('Delete asks to confirm', (tester) async {
    await seedHistory(tester);
    await pumpHistory(tester);
    await tester.tap(find.text('Running · 45 min'));
    await settle(tester);

    await tester.tap(find.byTooltip('Delete activity'));
    await settle(tester);
    expect(find.text('Delete activity?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await settle(tester);
    expect(await activities(tester), hasLength(1));
    expect(find.byTooltip('Edit activity'), findsOneWidget);

    await tester.tap(find.byTooltip('Delete activity'));
    await settle(tester);
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Delete'),
      ),
    );
    await settle(tester);
    expect(await activities(tester), isEmpty);
    expect(find.byTooltip('Edit activity'), findsNothing);
    await unmount(tester);
  });
}
