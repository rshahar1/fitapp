import 'package:drift/drift.dart' show DatabaseConnection, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:fitapp/app/theme/app_icons.dart';
import 'package:fitapp/app/theme/app_theme.dart';
import 'package:fitapp/core/haptics.dart';
import 'package:fitapp/core/step_source.dart';
import 'package:fitapp/data/db/app_database.dart';
import 'package:fitapp/data/providers.dart';
import 'package:fitapp/data/repositories/activity_repository.dart';
import 'package:fitapp/data/repositories/workout_repository.dart';
import 'package:fitapp/features/train/train_screen.dart';
import 'package:fitapp/widgets/app_button.dart';
import 'package:fitapp/widgets/rec_dot.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'fake_step_source.dart';

const _inclineId = '00000000-0000-4000-8000-000000000002';

class _FakeHaptics implements Haptics {
  @override
  void tick() {}
  @override
  void success() {}
  @override
  void warning() {}
}

void main() {
  late AppDatabase db;

  setUp(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    db = AppDatabase(DatabaseConnection(NativeDatabase.memory()));
  });
  tearDown(() => db.close());

  /// Unmounts the tree and lets drift's stream-cleanup timers fire.
  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 10));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 10));
  }

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          hapticsProvider.overrideWithValue(_FakeHaptics()),
        ],
        child: MaterialApp(theme: buildAppTheme(), home: const TrainScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('steps card sits above the metrics', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          hapticsProvider.overrideWithValue(_FakeHaptics()),
          stepSourceProvider.overrideWithValue(FakeStepSource()),
        ],
        child: MaterialApp(theme: buildAppTheme(), home: const TrainScreen()),
      ),
    );
    await tester.pumpAndSettle();
    final steps = tester.getTopLeft(find.text('Steps today')).dy;
    final metrics = tester.getTopLeft(find.text('This week')).dy;
    expect(steps, lessThan(metrics));
    await unmount(tester);
  });

  testWidgets('empty state has no empty gym start', (tester) async {
    await pump(tester);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Ready to train?'), findsNothing);
    expect(find.text('Start gym workout'), findsNothing);
    expect(find.text('No workouts yet'), findsOneWidget);
    expect(find.text('0'), findsNWidgets(3));
    await unmount(tester);
  });

  testWidgets('finished workout appears in Recent', (tester) async {
    await tester.runAsync(() async {
      final repo = WorkoutRepository(db);
      final w = await repo.startWorkout();
      final we = await repo.addExercise(w.id, _inclineId);
      await repo.logSet(we.id, setNo: 1, weight: 20, reps: 10);
      await repo.finishWorkout(w.id);
    });
    await pump(tester);
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
    expect(find.text('No workouts yet'), findsNothing);
    expect(find.text('Incline Dumbbell Bench Press'), findsOneWidget);
    expect(find.textContaining(' kg'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('active workout shows continue', (tester) async {
    await tester.runAsync(() => WorkoutRepository(db).startWorkout());
    await pump(tester);
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
    expect(find.text('Workout in progress'), findsOneWidget);
    expect(find.text('Continue workout'), findsOneWidget);
    expect(find.text('LIVE'), findsOneWidget);
    expect(find.byType(RecDot), findsOneWidget);
    final button = tester.widget<AppButton>(find.byType(AppButton));
    expect(button.variant, AppButtonVariant.live);
    expect(button.icon, AppIcons.play);
    await unmount(tester);
  });

  testWidgets('no session: no hero, no LIVE pill', (tester) async {
    await pump(tester);
    expect(find.byType(AppButton), findsNothing);
    expect(find.textContaining('LIVE'), findsNothing);
    await unmount(tester);
  });

  testWidgets('empty db: ALL TIME tile, no BY TYPE section', (tester) async {
    await pump(tester);
    expect(find.text('All time'), findsOneWidget);
    expect(find.text('Total workouts'), findsNothing);
    expect(find.text('By type'), findsNothing);
    await unmount(tester);
  });

  testWidgets('BY TYPE lists gym and activity rows with counts', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final repo = WorkoutRepository(db);
      final w = await repo.startWorkout();
      final we = await repo.addExercise(w.id, _inclineId);
      await repo.logSet(we.id, setNo: 1, weight: 20, reps: 10);
      await repo.finishWorkout(w.id);
      await ActivityRepository(db)
          .create(typeId: 'cycling', startedAt: DateTime.now());
    });
    await pump(tester);
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
    expect(find.text('By type'), findsOneWidget);
    expect(find.text('Gym'), findsOneWidget);
    // By type row plus the activity's Recent row (feature 028).
    expect(find.text('Cycling'), findsNWidgets(2));
    expect(find.text('1 this week'), findsNWidgets(2));
    expect(find.text('1 all time'), findsNWidgets(2));
    // THIS WEEK, THIS MONTH and ALL TIME tiles; no streak tile.
    expect(find.text('2'), findsNWidgets(3));
    expect(
      find.textContaining(RegExp('streak', caseSensitive: false)),
      findsNothing,
    );
    await unmount(tester);
  });

  testWidgets('BY TYPE hides types with no session this week', (tester) async {
    await tester.runAsync(() async {
      await ActivityRepository(db).create(
        typeId: 'cycling',
        startedAt: DateTime.now().subtract(const Duration(days: 30)),
      );
    });
    await pump(tester);
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
    expect(find.text('By type'), findsNothing);
    expect(find.text('0 this week'), findsNothing);
    await unmount(tester);
  });
}
