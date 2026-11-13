import 'package:drift/drift.dart' show DatabaseConnection, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:fitapp/app/app.dart';
import 'package:fitapp/core/haptics.dart';
import 'package:fitapp/core/rest_alerts.dart';
import 'package:fitapp/data/db/app_database.dart';
import 'package:fitapp/data/providers.dart';
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

/// Shared end-to-end flow (PRD §12): start workout → add exercise → set up
/// plan → log 3 sets → finish → exercise detail shows the new base and a
/// chart point. Used by the widget test and the on-device integration test.
Future<void> runWorkoutFlow(
  WidgetTester tester, {
  required Future<void> Function() settle,
}) async {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  final db = AppDatabase(DatabaseConnection(NativeDatabase.memory()));
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

  Future<void> tap(Finder f) async {
    await tester.ensureVisible(f.first);
    await tester.pump();
    await tester.tap(f.first);
    await settle();
  }

  await tap(find.text('START WORKOUT'));
  await tap(find.text('ADD EXERCISE'));
  await tap(find.text('Incline Dumbbell Bench Press'));

  // Plan: base 20 (8 × 2.5), defaults 10 reps × 3 sets, +2.5.
  final increaseBase = find.bySemanticsLabel('Increase Base weight (per hand)');
  for (var i = 0; i < 8; i++) {
    await tester.tap(increaseBase);
    await tester.pump();
  }
  await tap(find.text('START WITH THIS PLAN'));

  await tap(find.bySemanticsLabel('Log set 1 as prescribed'));
  await tap(find.bySemanticsLabel('Log set 2 as prescribed'));

  // Overload set: 22.5 × 6 via the editor.
  await tap(find.bySemanticsLabel(RegExp('^Set 3, overload')));
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
  await tap(find.text('DONE'));

  await tap(find.text('Progress'));
  await tap(find.text('Incline Dumbbell Bench Press'));
  expect(find.text('22.5 kg'), findsWidgets);
  expect(find.text('1'), findsWidgets); // Sessions tile

  await tester.pumpWidget(const SizedBox());
  await settle();
  await tester.runAsync(db.close);
}
