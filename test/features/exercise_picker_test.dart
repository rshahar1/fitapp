import 'package:drift/drift.dart' show DatabaseConnection, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:fitapp/app/theme/app_theme.dart';
import 'package:fitapp/core/haptics.dart';
import 'package:fitapp/data/db/app_database.dart';
import 'package:fitapp/data/providers.dart';
import 'package:fitapp/features/exercises/exercise_picker_screen.dart';
import 'package:fitapp/widgets/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

class _FakeHaptics implements Haptics {
  int ticks = 0;
  @override
  void tick() => ticks++;
  @override
  void success() {}
  @override
  void warning() {}
}

void main() {
  late AppDatabase db;
  late ProviderContainer container;
  late _FakeHaptics haptics;
  late String workoutId;

  setUp(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    db = AppDatabase(DatabaseConnection(NativeDatabase.memory()));
    haptics = _FakeHaptics();
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  String? popped;

  Future<void> pump(WidgetTester tester, {bool select = false}) async {
    tester.view.physicalSize = const Size(800, 6000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        hapticsProvider.overrideWithValue(haptics),
      ],
    );
    await tester.runAsync(() async {
      workoutId =
          (await container.read(workoutRepositoryProvider).startWorkout()).id;
    });
    popped = null;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: buildAppTheme(),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  popped = await Navigator.of(context).push<String>(
                    MaterialPageRoute<String>(
                      fullscreenDialog: true,
                      builder: (_) => ExercisePickerScreen(
                        workoutId: select ? null : workoutId,
                      ),
                    ),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await settle(tester);
  }

  Future<List<String>> workoutNames(WidgetTester tester) async {
    final d = await tester.runAsync(
      () => container.read(workoutRepositoryProvider).workoutDetail(workoutId),
    );
    return [for (final e in d!.exercises) e.exercise.name];
  }

  testWidgets('lists 16 library exercises grouped', (tester) async {
    await pump(tester);
    expect(find.text('Chest'), findsOneWidget);
    expect(find.text('Arms'), findsOneWidget);
    expect(find.byType(GroupRow), findsNWidgets(16));
    expect(find.textContaining('per hand · +2.5 kg'), findsWidgets);
  });

  testWidgets('search filters and tapping adds to workout', (tester) async {
    await pump(tester);
    await tester.enterText(find.byType(TextField), 'row');
    await settle(tester);
    expect(find.text('Seated Cable Row'), findsOneWidget);
    expect(find.text('Dumbbell Row'), findsOneWidget);
    expect(find.byType(GroupRow), findsNWidgets(3)); // 2 + create row
    await tester.tap(find.text('Dumbbell Row'));
    await settle(tester);
    expect(haptics.ticks, 1);
    expect(find.text('Add exercise'), findsNothing);
    expect(await workoutNames(tester), ['Dumbbell Row']);
  });

  testWidgets('select mode pops with the exercise id', (tester) async {
    await pump(tester, select: true);
    expect(find.text('Choose exercise'), findsOneWidget);
    await tester.tap(find.text('Dumbbell Row'));
    await settle(tester);
    expect(find.text('Choose exercise'), findsNothing);
    final row = await tester.runAsync(
      () => container.read(exerciseRepositoryProvider).exercise(popped!),
    );
    expect(row!.name, 'Dumbbell Row');
    expect(await workoutNames(tester), isEmpty);
  });

  testWidgets('create custom exercise adds it to workout', (tester) async {
    await pump(tester);
    await tester.enterText(find.byType(TextField), 'Hack Squat');
    await settle(tester);
    await tester.tap(find.text('Create "Hack Squat"'));
    await settle(tester);
    await tester.tap(find.text('Create exercise'));
    await settle(tester);
    expect(find.text('Add exercise'), findsNothing);
    expect(await workoutNames(tester), ['Hack Squat']);
  });

  testWidgets('duplicate name shows inline error', (tester) async {
    await pump(tester);
    await tester.enterText(find.byType(TextField), 'barbell bench press');
    await settle(tester);
    expect(find.text('Create "barbell bench press"'), findsNothing);
    await tester.enterText(find.byType(TextField), 'barbell bench pres');
    await settle(tester);
    await tester.tap(find.text('Create "barbell bench pres"'));
    await settle(tester);
    await tester.enterText(find.byType(TextField).last, 'barbell bench press');
    await tester.tap(find.text('Create exercise'));
    await settle(tester);
    expect(find.textContaining('already exists'), findsOneWidget);
    expect(await workoutNames(tester), isEmpty);
  });
}

Future<void> settle(WidgetTester tester) async {
  await tester.runAsync(() => Future<void>.delayed(Duration.zero));
  await tester.pumpAndSettle();
  await tester.runAsync(() => Future<void>.delayed(Duration.zero));
  await tester.pumpAndSettle();
}
