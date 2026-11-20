import 'package:drift/drift.dart' show DatabaseConnection, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:fitapp/app/theme/app_theme.dart';
import 'package:fitapp/core/haptics.dart';
import 'package:fitapp/core/rest_alerts.dart';
import 'package:fitapp/data/db/app_database.dart';
import 'package:fitapp/data/models.dart';
import 'package:fitapp/data/providers.dart';
import 'package:fitapp/data/repositories/exercise_repository.dart';
import 'package:fitapp/data/repositories/template_repository.dart';
import 'package:fitapp/data/repositories/workout_repository.dart';
import 'package:fitapp/features/workout/workout_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

const _incline = '00000000-0000-4000-8000-000000000002';

class _NoHaptics implements Haptics {
  @override
  void success() {}
  @override
  void tick() {}
  @override
  void warning() {}
}

void main() {
  late AppDatabase db;
  late TemplateRepository templates;
  late ExerciseRepository exercises;

  setUp(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    db = AppDatabase(DatabaseConnection(NativeDatabase.memory()));
    templates = TemplateRepository(db);
    exercises = ExerciseRepository(db);
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump(const Duration(milliseconds: 300));
    }
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 10));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 10));
    await tester.runAsync(db.close);
  }

  testWidgets('template plan drives the card and Edit plan edits it', (
    tester,
  ) async {
    final ids = await tester.runAsync(() async {
      await exercises.savePlan(
        _incline,
        baseWeight: 20,
        targetReps: 10,
        targetSets: 3,
        increment: 2.5,
      );
      final tid = await templates.create(
        name: 'Push',
        exerciseIds: [_incline],
        plans: {
          _incline: const StoredPlan(
            baseWeight: 22.5,
            targetReps: 10,
            targetSets: 3,
            increment: 2.5,
          ),
        },
      );
      final wid = await templates.startWorkout(tid);
      final weId = (await db.select(db.workoutExercises).getSingle()).id;
      return (tid, wid, weId);
    });
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          hapticsProvider.overrideWithValue(_NoHaptics()),
          restAlertsProvider.overrideWithValue(const NoopRestAlerts()),
        ],
        child: MaterialApp(
          theme: buildAppTheme(),
          home: WorkoutScreen(workoutId: ids!.$2),
        ),
      ),
    );
    await settle(tester);
    expect(find.textContaining('22.5 kg'), findsWidgets);
    expect(find.textContaining('template plan'), findsOneWidget);

    expect(find.text('Add Set'), findsNothing);
    expect(find.byKey(ValueKey('set-${ids.$3}-3')), findsOneWidget);
    expect(find.byKey(ValueKey('set-${ids.$3}-4')), findsNothing);

    await tester.tap(
      find.byTooltip('Exercise options for Incline Dumbbell Bench Press'),
    );
    await settle(tester);
    await tester.tap(find.text('Edit plan'));
    await settle(tester);
    expect(
      find.text('Edit template plan · Incline Dumbbell Bench Press'),
      findsOneWidget,
    );
    await tester.tap(find.bySemanticsLabel('Increase Sets'));
    await tester.pump();
    await tester.tap(find.text('SAVE PLAN'));
    await settle(tester);

    final t = await tester.runAsync(() => templates.template(ids.$1));
    expect(t!.plans[_incline]!.targetSets, 4);
    expect(t.plans[_incline]!.baseWeight, 22.5);
    final own = await tester.runAsync(() => exercises.plan(_incline));
    expect(find.byKey(ValueKey('set-${ids.$3}-4')), findsOneWidget);
    expect(own!.targetReps, 10);
    expect(own.baseWeight, 20);
    await unmount(tester);
  });

  Future<void> pumpWorkout(WidgetTester tester, String workoutId) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          hapticsProvider.overrideWithValue(_NoHaptics()),
          restAlertsProvider.overrideWithValue(const NoopRestAlerts()),
        ],
        child: MaterialApp(
          theme: buildAppTheme(),
          home: WorkoutScreen(workoutId: workoutId),
        ),
      ),
    );
    await settle(tester);
  }

  const plan = StoredPlan(
    baseWeight: 22.5,
    targetReps: 10,
    targetSets: 3,
    increment: 2.5,
  );

  testWidgets('ad-hoc exercise keeps Add Set', (tester) async {
    final wid = await tester.runAsync(() async {
      await exercises.savePlan(
        _incline,
        baseWeight: 20,
        targetReps: 10,
        targetSets: 3,
        increment: 2.5,
      );
      final workouts = WorkoutRepository(db);
      final w = await workouts.startWorkout();
      await workouts.addExercise(w.id, _incline);
      return w.id;
    });
    await pumpWorkout(tester, wid!);
    expect(find.text('Add Set'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('template deleted mid-session keeps Add Set', (tester) async {
    final wid = await tester.runAsync(() async {
      await exercises.savePlan(
        _incline,
        baseWeight: 20,
        targetReps: 10,
        targetSets: 3,
        increment: 2.5,
      );
      final tid = await templates.create(
        name: 'Push',
        exerciseIds: [_incline],
        plans: {_incline: plan},
      );
      final w = await templates.startWorkout(tid);
      await templates.delete(tid);
      return w;
    });
    await pumpWorkout(tester, wid!);
    expect(find.text('Add Set'), findsOneWidget);
    await unmount(tester);
  });
}
