import 'package:drift/drift.dart' show DatabaseConnection, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:fitapp/app/theme/app_theme.dart';
import 'package:fitapp/core/haptics.dart';
import 'package:fitapp/data/db/app_database.dart';
import 'package:fitapp/data/providers.dart';
import 'package:fitapp/data/repositories/settings_repository.dart';
import 'package:fitapp/features/settings/settings_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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
  late SettingsRepository settings;

  setUp(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    db = AppDatabase(DatabaseConnection(NativeDatabase.memory()));
    settings = SettingsRepository(db);
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
        child: MaterialApp(
          theme: buildAppTheme(),
          home: const SettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('preset persists default rest', (tester) async {
    await pump(tester);
    await tester.tap(find.text('1:30'));
    await tester.pumpAndSettle();
    expect(await tester.runAsync(settings.defaultRest), 90);
    await unmount(tester);
  });

  testWidgets('stepper plus adds 5 seconds', (tester) async {
    await pump(tester);
    expect(find.text('1:00'), findsWidgets);
    await tester.tap(find.bySemanticsLabel('Increase Default rest time'));
    await tester.pumpAndSettle();
    expect(await tester.runAsync(settings.defaultRest), 65);
    expect(find.text('1:05'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('alert toggles persist', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Vibrate'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sound'));
    await tester.pumpAndSettle();
    final prefs = await tester.runAsync(settings.alertPrefs);
    expect(prefs, const RestAlertPrefs(haptic: false, sound: false));
    await unmount(tester);
  });
}
