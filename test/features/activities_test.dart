import 'package:drift/drift.dart' show DatabaseConnection, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:fitapp/app/theme/app_theme.dart';
import 'package:fitapp/core/haptics.dart';
import 'package:fitapp/data/db/app_database.dart';
import 'package:fitapp/data/providers.dart';
import 'package:fitapp/data/repositories/activity_repository.dart';
import 'package:fitapp/data/repositories/workout_repository.dart';
import 'package:fitapp/features/activities/activity_icons.dart';
import 'package:fitapp/features/history/history_screen.dart';
import 'package:fitapp/features/train/train_screen.dart';
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

  Future<List<ActivityRow>> activities(WidgetTester tester) => tester
      .runAsync(() => ActivityRepository(db).list())
      .then((v) => v ?? const []);

  Future<void> openSheet(WidgetTester tester) async {
    await tester.tap(find.text('LOG ACTIVITY'));
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

  testWidgets('Train: log a running activity dated today', (tester) async {
    await pump(tester, const TrainScreen());
    await openSheet(tester);
    expect(find.text('Log activity'), findsOneWidget);
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
    expect(find.text('Log activity'), findsNothing);
    await unmount(tester);
  });

  testWidgets('Save is disabled until a type is chosen', (tester) async {
    await pump(tester, const TrainScreen());
    await openSheet(tester);
    expect(saveEnabled(tester), isFalse);
    await tester.tap(find.text('Cycling'));
    await tester.pump();
    expect(saveEnabled(tester), isTrue);
    await unmount(tester);
  });

  testWidgets('duration set via the stepper is stored', (tester) async {
    await pump(tester, const TrainScreen());
    await openSheet(tester);
    await tester.tap(find.text('Cycling'));
    await tester.tap(find.text('Set'));
    await tester.pump();
    expect(find.text('30 min'), findsOneWidget);
    final plus = find.descendant(
      of: find.byType(AppStepper),
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
    await pump(tester, const HistoryScreen());
    await tester.tap(find.text('Running · 45 min'));
    await tester.pumpAndSettle();
    expect(find.text('Edit activity'), findsOneWidget);
    await tester.tap(find.text('Cycling'));
    await tester.pump();
    await save(tester);

    final list = await activities(tester);
    expect(list.single.typeId, 'cycling');
    expect(list.single.durationMinutes, 45);
    expect(find.text('Cycling · 45 min'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('Delete asks to confirm', (tester) async {
    await seedHistory(tester);
    await pump(tester, const HistoryScreen());
    await tester.tap(find.text('Running · 45 min'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Delete activity?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(await activities(tester), hasLength(1));
    expect(find.text('Edit activity'), findsOneWidget);

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Delete'),
      ),
    );
    await settle(tester);
    expect(await activities(tester), isEmpty);
    expect(find.text('Edit activity'), findsNothing);
    await unmount(tester);
  });
}
