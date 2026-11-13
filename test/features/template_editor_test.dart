import 'package:drift/drift.dart' show DatabaseConnection, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:fitapp/app/router.dart';
import 'package:fitapp/app/theme/app_theme.dart';
import 'package:fitapp/core/haptics.dart';
import 'package:fitapp/data/db/app_database.dart';
import 'package:fitapp/data/models.dart';
import 'package:fitapp/data/providers.dart';
import 'package:fitapp/data/repositories/template_repository.dart';
import 'package:fitapp/features/exercises/exercise_picker_screen.dart';
import 'package:fitapp/features/templates/template_editor_screen.dart';
import 'package:fitapp/features/workout/widgets/exercise_card.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

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
  late ProviderContainer container;

  setUp(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    db = AppDatabase(DatabaseConnection(NativeDatabase.memory()));
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<void> pump(WidgetTester tester, String start) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        hapticsProvider.overrideWithValue(_FakeHaptics()),
      ],
    );
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(
          path: '/home',
          builder: (context, _) => Scaffold(
            body: TextButton(
              onPressed: () => context.push<void>(start),
              child: const Text('open'),
            ),
          ),
        ),
        GoRoute(
          path: Routes.newTemplate,
          builder: (_, _) => const TemplateEditorScreen(),
        ),
        GoRoute(
          path: '/template/:id',
          builder: (_, s) =>
              TemplateEditorScreen(templateId: s.pathParameters['id']),
        ),
        GoRoute(
          path: Routes.pickExercise,
          pageBuilder: (_, _) => const MaterialPage(
            fullscreenDialog: true,
            child: ExercisePickerScreen(),
          ),
        ),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(theme: buildAppTheme(), routerConfig: router),
      ),
    );
    await tester.tap(find.text('open'));
    await settle(tester);
  }

  Future<void> finish(WidgetTester tester) =>
      tester.pumpWidget(const SizedBox());

  Future<void> addExercise(WidgetTester tester, String name) async {
    await tester.tap(find.text('ADD EXERCISE'));
    await settle(tester);
    await tester.tap(find.text(name));
    await settle(tester);
  }

  Future<List<String>> savedNames(WidgetTester tester, String template) async {
    final list = await run(
      tester,
      () => container.read(templateRepositoryProvider).list(),
    );
    final t = list!.firstWhere((t) => t.name == template);
    return [for (final e in t.exercises) e.name];
  }

  testWidgets('creates a template with two exercises via the picker', (
    tester,
  ) async {
    await pump(tester, Routes.newTemplate);
    expect(find.text('New template'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Push day');
    await addExercise(tester, 'Dumbbell Row');
    await addExercise(tester, 'Seated Cable Row');
    expect(find.text('Remove Dumbbell Row'), findsNothing); // tooltip only
    expect(find.byTooltip('Remove Dumbbell Row'), findsOneWidget);
    await tester.tap(find.text('Save'));
    await settle(tester);
    expect(find.text('Template saved'), findsOneWidget);
    expect(find.text('New template'), findsNothing);
    expect(await savedNames(tester, 'Push day'), [
      'Dumbbell Row',
      'Seated Cable Row',
    ]);
    await finish(tester);
  });

  testWidgets('duplicate exercise is ignored with a message', (tester) async {
    await pump(tester, Routes.newTemplate);
    await addExercise(tester, 'Dumbbell Row');
    await addExercise(tester, 'Dumbbell Row');
    expect(find.text('Already in this template'), findsOneWidget);
    expect(find.byTooltip('Remove Dumbbell Row'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('validation: empty name, no exercises, duplicate name', (
    tester,
  ) async {
    await run(
      tester,
      () => container0(db).create(name: 'Legs', exerciseIds: [_firstId]),
    );
    await pump(tester, Routes.newTemplate);
    await tester.tap(find.text('Save'));
    await settle(tester);
    expect(find.text('Name is required'), findsWidgets);
    expect(find.text('New template'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Pull');
    await tester.tap(find.text('Save'));
    await settle(tester);
    expect(find.text('Add at least one exercise'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'legs');
    await addExercise(tester, 'Dumbbell Row');
    await tester.tap(find.text('Save'));
    await settle(tester);
    expect(find.text('Name already used'), findsWidgets);
    expect(find.text('New template'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('edit mode loads, renames and removes an exercise', (
    tester,
  ) async {
    final id = await run(tester, () async {
      final exs = await db.select(db.exercises).get();
      return await container0(db)
          .create(name: 'Old', exerciseIds: [exs[0].id, exs[1].id]);
    });
    await pump(tester, Routes.template(id!));
    expect(find.text('Edit template'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Old'), findsOneWidget);
    final first = (await run(
      tester,
      () => container0(db).template(id),
    ))!.exercises.first.name;
    await tester.tap(find.byTooltip('Remove $first'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'New');
    await tester.tap(find.text('Save'));
    await settle(tester);
    final t = await run(tester, () => container0(db).template(id));
    expect(t!.name, 'New');
    expect(t.exercises.length, 1);
    await finish(tester);
  });

  testWidgets('back with changes asks to discard', (tester) async {
    await pump(tester, Routes.newTemplate);
    await tester.enterText(find.byType(TextField), 'X');
    await tester.pump();
    await tester.binding.handlePopRoute();
    await settle(tester);
    expect(find.text('Discard changes?'), findsOneWidget);
    await tester.tap(find.text('Keep editing'));
    await settle(tester);
    expect(find.text('New template'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await settle(tester);
    await tester.tap(find.text('Discard'));
    await settle(tester);
    expect(find.text('New template'), findsNothing);
    await finish(tester);
  });

  testWidgets('delete asks for confirmation then removes', (tester) async {
    final id = await run(tester, () async {
      final exs = await db.select(db.exercises).get();
      return await container0(db)
          .create(name: 'Gone', exerciseIds: [exs[0].id]);
    });
    await pump(tester, Routes.template(id!));
    await tester.tap(find.byType(PopupMenuButton<String>));
    await settle(tester);
    await tester.tap(find.text('Delete template'));
    await settle(tester);
    expect(find.text('Delete template?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await settle(tester);
    expect(await run(tester, () => container0(db).template(id)), isNotNull);
    await tester.tap(find.byType(PopupMenuButton<String>));
    await settle(tester);
    await tester.tap(find.text('Delete template'));
    await settle(tester);
    await tester.tap(find.text('Delete'));
    await settle(tester);
    expect(await run(tester, () => container0(db).template(id)), isNull);
    expect(find.text('Edit template'), findsNothing);
    await finish(tester);
  });

  const planA = StoredPlan(
    baseWeight: 30,
    targetReps: 8,
    targetSets: 3,
    increment: 2.5,
  );

  Future<String> seedPlanTemplate(WidgetTester tester) async {
    final id = await run(tester, () async {
      final exs = await db.select(db.exercises).get();
      return await container0(db).create(
        name: 'Planned',
        exerciseIds: [exs[0].id, exs[1].id],
        plans: {exs[0].id: planA},
      );
    });
    return id!;
  }

  Future<TemplateSummary> loadTemplate(WidgetTester tester, String id) async =>
      (await run(tester, () => container0(db).template(id)))!;

  testWidgets('editor shows plan summaries and No plan yet', (tester) async {
    final id = await seedPlanTemplate(tester);
    await pump(tester, Routes.template(id));
    final t = await loadTemplate(tester, id);
    final withPlan = t.exercises.firstWhere((e) => t.plans[e.id] != null);
    expect(
      find.text(planSummary(planA.toPlan(), perHand: withPlan.isPerHand)),
      findsOneWidget,
    );
    expect(find.text('No plan yet'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('editing a plan and saving stores it', (tester) async {
    final id = await seedPlanTemplate(tester);
    await pump(tester, Routes.template(id));
    final t = await loadTemplate(tester, id);
    final e = t.exercises.firstWhere((e) => t.plans[e.id] != null);
    await tester.tap(find.byTooltip('Edit plan for ${e.name}'));
    await settle(tester);
    expect(find.text('Template plan · ${e.name}'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Increase Target reps'));
    await tester.pump();
    await tester.tap(find.text('DONE'));
    await settle(tester);
    expect(find.text('Template plan · ${e.name}'), findsNothing);
    await tester.tap(find.text('Save'));
    await settle(tester);
    final saved = await loadTemplate(tester, id);
    expect(saved.plans[e.id]!.targetReps, 9);
    await finish(tester);
  });

  testWidgets('discarding after a plan edit does not store it', (tester) async {
    final id = await seedPlanTemplate(tester);
    await pump(tester, Routes.template(id));
    final t = await loadTemplate(tester, id);
    final e = t.exercises.firstWhere((e) => t.plans[e.id] != null);
    await tester.tap(find.byTooltip('Edit plan for ${e.name}'));
    await settle(tester);
    await tester.tap(find.bySemanticsLabel('Increase Target reps'));
    await tester.pump();
    await tester.tap(find.text('DONE'));
    await settle(tester);
    await tester.binding.handlePopRoute();
    await settle(tester);
    expect(find.text('Discard changes?'), findsOneWidget);
    await tester.tap(find.text('Discard'));
    await settle(tester);
    final saved = await loadTemplate(tester, id);
    expect(saved.plans[e.id], planA);
    await finish(tester);
  });
}

const _firstId = '00000000-0000-4000-8000-000000000002';

TemplateRepository container0(AppDatabase db) => TemplateRepository(db);

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pumpAndSettle();
  }
}

Future<T?> run<T>(WidgetTester tester, Future<T> Function() f) =>
    tester.runAsync<T>(f);
