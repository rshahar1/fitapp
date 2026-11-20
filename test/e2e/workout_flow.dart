import 'package:drift/drift.dart' show DatabaseConnection, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:fitapp/app/app.dart';
import 'package:fitapp/core/haptics.dart';
import 'package:fitapp/core/rest_alerts.dart';
import 'package:fitapp/data/db/app_database.dart';
import 'package:fitapp/data/providers.dart';
import 'package:fitapp/data/repositories/template_repository.dart';
import 'package:fitapp/widgets/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

class _NoHaptics implements Haptics {
  @override
  void success() {}
  @override
  void tick() {}
  @override
  void warning() {}
}

/// Shared end-to-end flow (PRD §12): start workout from a template → add exercise →
/// set up plan → log 3 sets → finish → exercise detail shows the new base and a
/// chart point. Used by the widget test and the on-device integration test.
Future<void> runWorkoutFlow(
  WidgetTester tester, {
  required Future<void> Function() settle,
}) async {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  final db = AppDatabase(DatabaseConnection(NativeDatabase.memory()));
  // Gym workouts start only from a template (feature 024); seed one with a
  // different exercise (Barbell Bench Press) than the one added in the flow.
  await tester.runAsync(
    () => TemplateRepository(db).create(
      name: 'Push',
      exerciseIds: ['00000000-0000-4000-8000-000000000001'],
    ),
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        hapticsProvider.overrideWithValue(_NoHaptics()),
        restAlertsProvider.overrideWithValue(const NoopRestAlerts()),
      ],
      child: const FitApp(),
    ),
  );
  await settle();

  Future<void> tap(Finder f, {bool last = false}) async {
    final target = last ? f.last : f.first;
    // Centre it: the default aligns to the top edge, under the app bar.
    await Scrollable.ensureVisible(tester.element(target), alignment: 0.5);
    await tester.pump();
    await tester.tap(target);
    await settle();
  }

  await tap(find.bySemanticsLabel('Start Push template'));
  await tap(find.text('ADD EXERCISE'));
  await tap(find.text('Incline Dumbbell Bench Press'));

  // Plan: base 20 (8 × 2.5), defaults 10 reps × 3 sets, +2.5.
  final increaseBase = find.bySemanticsLabel('Increase Base weight (per hand)');
  // The seeded template's exercise sits above the plan card; scroll to it.
  await Scrollable.ensureVisible(tester.element(increaseBase), alignment: 0.5);
  await tester.pump();
  for (var i = 0; i < 8; i++) {
    await tester.tap(increaseBase);
    await tester.pump();
  }
  // Two matching buttons exist; the last is the one on top.
  final btn = find.widgetWithText(AppButton, 'START WITH THIS PLAN');
  await tap(btn, last: true);

  // The template's exercise is listed first; the added one is last.
  await tap(find.bySemanticsLabel('Log set 1 as prescribed'), last: true);
  await tap(find.bySemanticsLabel('Log set 2 as prescribed'), last: true);

  // Overload set: 22.5 × 6 via the editor.
  await tap(find.bySemanticsLabel(RegExp('^Set 3, overload')), last: true);
  for (var i = 0; i < 4; i++) {
    await tester.tap(find.bySemanticsLabel('Decrease Reps'));
    await tester.pump();
  }
  await tap(find.text('LOG SET'));

  await tap(find.text('FINISH'));
  expect(
    find.textContaining('Incline Dumbbell Bench Press: 20 kg → 22.5 kg'),
    findsOneWidget,
  );
  await tap(
    find.descendant(of: find.byType(BottomSheet), matching: find.text('DONE')),
  );

  await tap(find.text('Progress'));
  await tap(find.text('Incline Dumbbell Bench Press'));
  expect(find.text('22.5 kg'), findsWidgets);
  expect(find.text('1'), findsWidgets); // Sessions tile

  await tester.pumpWidget(const SizedBox());
  await settle();
  await tester.runAsync(db.close);
}
