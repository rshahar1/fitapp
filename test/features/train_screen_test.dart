import 'package:drift/drift.dart' show DatabaseConnection, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:fitapp/app/theme/app_theme.dart';
import 'package:fitapp/core/haptics.dart';
import 'package:fitapp/data/db/app_database.dart';
import 'package:fitapp/data/providers.dart';
import 'package:fitapp/data/repositories/workout_repository.dart';
import 'package:fitapp/features/train/train_screen.dart';
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

  testWidgets('empty state offers to start a workout', (tester) async {
    await pump(tester);
    expect(find.text('Train'), findsOneWidget);
    expect(find.text('Ready to train?'), findsOneWidget);
    expect(find.text('START WORKOUT'), findsOneWidget);
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
    expect(find.text('CONTINUE WORKOUT'), findsOneWidget);
    await unmount(tester);
  });
}
