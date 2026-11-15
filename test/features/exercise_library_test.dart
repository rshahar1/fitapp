import 'package:fitapp/app/router.dart';
import 'package:fitapp/app/theme/app_theme.dart';
import 'package:fitapp/core/haptics.dart';
import 'package:fitapp/data/providers.dart';
import 'package:fitapp/data/repositories/template_repository.dart';
import 'package:fitapp/features/exercises/exercise_library_screen.dart';
import 'package:fitapp/features/progress/exercise_detail_screen.dart';
import 'package:fitapp/features/progress/progress_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../data/helpers.dart';

class _FakeHaptics implements Haptics {
  @override
  void success() {}
  @override
  void tick() {}
  @override
  void warning() {}
}

void main() {
  late Harness h;

  setUp(() => h = Harness());

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();
    }
  }

  Future<void> pump(WidgetTester tester, {String start = '/exercises'}) async {
    tester.view.physicalSize = const Size(800, 6000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      initialLocation: start,
      routes: [
        GoRoute(
          path: Routes.progress,
          builder: (_, _) => const ProgressScreen(),
        ),
        GoRoute(
          path: Routes.exercises,
          builder: (_, _) => const ExerciseLibraryScreen(),
        ),
        GoRoute(
          path: '/exercise/:id',
          builder: (_, s) =>
              ExerciseDetailScreen(exerciseId: s.pathParameters['id']!),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(h.db),
          hapticsProvider.overrideWithValue(_FakeHaptics()),
          clockProvider.overrideWithValue(() => h.now),
        ],
        child: MaterialApp.router(theme: buildAppTheme(), routerConfig: router),
      ),
    );
    await settle(tester);
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 10));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 10));
    await tester.runAsync(h.close);
  }

  Future<void> createExercise(
    WidgetTester tester,
    String name, {
    String? category,
  }) async {
    await tester.tap(find.byTooltip('New exercise'));
    await settle(tester);
    await tester.enterText(find.byType(TextField).last, name);
    if (category != null) await tester.tap(find.text(category));
    await tester.tap(find.text('CREATE EXERCISE'));
    await settle(tester);
  }

  testWidgets('lists categories with seeded exercises', (tester) async {
    await pump(tester);
    expect(find.text('Gym Exercise Library'), findsOneWidget);
    for (final g in ['CHEST', 'BACK', 'LEGS', 'SHOULDERS', 'ARMS']) {
      expect(find.text(g), findsOneWidget);
    }
    expect(find.text('CUSTOM'), findsNothing);
    await unmount(tester);
  });

  testWidgets('search filters and offers create row', (tester) async {
    await pump(tester);
    await tester.enterText(find.byType(TextField), 'row');
    await settle(tester);
    expect(find.text('Dumbbell Row'), findsOneWidget);
    expect(find.text('Barbell Bench Press'), findsNothing);
    expect(find.text('Create "row"'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('create with category lists it under that category', (
    tester,
  ) async {
    await pump(tester);
    await createExercise(tester, 'Hip Thrust', category: 'Legs');
    expect(find.text('Hip Thrust'), findsOneWidget);
    expect(find.text('CUSTOM'), findsNothing);
    final legsY = tester.getTopLeft(find.text('LEGS')).dy;
    final shouldersY = tester.getTopLeft(find.text('SHOULDERS')).dy;
    final y = tester.getTopLeft(find.text('Hip Thrust')).dy;
    expect(y, greaterThan(legsY));
    expect(y, lessThan(shouldersY));
    await unmount(tester);
  });

  testWidgets('edit renames and recategorizes a custom exercise', (
    tester,
  ) async {
    await pump(tester);
    await createExercise(tester, 'Hip Thrust');
    expect(find.text('CUSTOM'), findsOneWidget);
    await tester.tap(find.byTooltip('Options for Hip Thrust'));
    await settle(tester);
    await tester.tap(find.text('Edit'));
    await settle(tester);
    expect(find.text('Edit exercise'), findsOneWidget);
    expect(find.text('Hip Thrust'), findsWidgets);
    await tester.enterText(find.byType(TextField).last, 'Glute Bridge');
    await tester.tap(find.text('Legs'));
    await tester.tap(find.text('SAVE'));
    await settle(tester);
    expect(find.text('Hip Thrust'), findsNothing);
    expect(find.text('Glute Bridge'), findsOneWidget);
    expect(find.text('CUSTOM'), findsNothing);
    expect(find.byTooltip('Options for Glute Bridge'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('duplicate name shows inline error', (tester) async {
    await pump(tester);
    await createExercise(tester, 'barbell bench press');
    expect(find.textContaining('already exists'), findsOneWidget);
    expect(find.text('CREATE EXERCISE'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('tapping a row opens the exercise detail', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Dumbbell Row'));
    await settle(tester);
    expect(find.text('Summary'), findsOneWidget);
    expect(find.text('History'), findsOneWidget);
    expect(find.byTooltip('Edit exercise'), findsNothing);
    await unmount(tester);
  });

  testWidgets('custom exercise detail has an edit action', (tester) async {
    await pump(tester);
    await createExercise(tester, 'Hip Thrust');
    await tester.tap(find.text('Hip Thrust'));
    await settle(tester);
    await tester.tap(find.byTooltip('Edit exercise'));
    await settle(tester);
    expect(find.text('Edit exercise'), findsOneWidget);
    expect(find.text('SAVE'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('Progress All exercises opens the library', (tester) async {
    await pump(tester, start: Routes.progress);
    await tester.tap(find.text('All exercises'));
    await settle(tester);
    expect(find.byTooltip('New exercise'), findsOneWidget);
    expect(find.text('CHEST'), findsOneWidget);
    await unmount(tester);
  });

  Future<void> openDelete(WidgetTester tester, String name) async {
    await tester.tap(find.byTooltip('Options for $name'));
    await settle(tester);
    await tester.tap(find.text('Delete'));
    await settle(tester);
  }

  testWidgets('deleting a custom exercise removes it', (tester) async {
    await pump(tester);
    await createExercise(tester, 'Hip Thrust');
    await openDelete(tester, 'Hip Thrust');
    expect(find.text('Delete "Hip Thrust"?'), findsOneWidget);
    await tester.tap(find.text('Delete').last);
    await settle(tester);
    expect(find.text('Hip Thrust'), findsNothing);
    expect(find.text('Deleted Hip Thrust'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('deleting a built-in exercise removes it', (tester) async {
    await pump(tester);
    await tester.tap(find.byTooltip('Options for Dumbbell Row'));
    await settle(tester);
    expect(find.text('Edit'), findsNothing);
    await tester.tap(find.text('Delete'));
    await settle(tester);
    await tester.tap(find.text('Delete').last);
    await settle(tester);
    expect(find.text('Dumbbell Row'), findsNothing);
    await unmount(tester);
  });

  testWidgets('cancel keeps the exercise', (tester) async {
    await pump(tester);
    await openDelete(tester, 'Dumbbell Row');
    await tester.tap(find.text('Cancel'));
    await settle(tester);
    expect(find.text('Dumbbell Row'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('delete dialog lists templates and empty ones', (tester) async {
    await pump(tester);
    final repo = TemplateRepository(h.db);
    await tester.runAsync(() async {
      await repo.create(name: 'Solo Day', exerciseIds: [inclineId]);
      await repo.create(name: 'Push Day', exerciseIds: [inclineId, latId]);
    });
    await openDelete(tester, 'Incline Dumbbell Bench Press');
    expect(find.textContaining('Removed from:'), findsOneWidget);
    expect(find.textContaining('Solo Day'), findsWidgets);
    expect(find.textContaining('Push Day'), findsOneWidget);
    expect(
      find.text('"Solo Day" has no other exercises and will be deleted.'),
      findsOneWidget,
    );
    expect(find.textContaining('"Push Day" has no other'), findsNothing);
    await unmount(tester);
  });
}
