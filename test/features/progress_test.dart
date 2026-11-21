import 'package:fitapp/app/theme/app_theme.dart';
import 'package:fitapp/core/haptics.dart';
import 'package:fitapp/data/providers.dart';
import 'package:fitapp/features/progress/exercise_detail_screen.dart';
import 'package:fitapp/features/progress/progress_screen.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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

  const progressed = <(double, int)>[(20, 10), (20, 10), (22.5, 6)];
  const heavier = <(double, int)>[(22.5, 10), (22.5, 10), (25, 6)];
  const lighter = <(double, int)>[(10, 5), (10, 5), (10, 5)];

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();
    }
  }

  Future<void> pumpScreen(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(h.db),
          hapticsProvider.overrideWithValue(_FakeHaptics()),
          clockProvider.overrideWithValue(() => h.now),
        ],
        child: MaterialApp(theme: buildAppTheme(), home: screen),
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

  Future<void> seed(List<List<(double, int)>> sessions) =>
      h.plan().then((_) async {
        for (final s in sessions) {
          await h.session(s);
        }
      });

  int chartPoints(WidgetTester tester) => tester
      .widget<LineChart>(find.byType(LineChart))
      .data
      .lineBarsData
      .first
      .spots
      .length;

  for (final n in [1, 2, 25]) {
    testWidgets('detail renders with $n sessions', (tester) async {
      await tester.runAsync(
        () => seed([for (var i = 0; i < n; i++) progressed]),
      );
      await pumpScreen(
        tester,
        const ExerciseDetailScreen(exerciseId: inclineId),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Incline Dumbbell Bench Press'), findsOneWidget);
      expect(find.text('Sessions'), findsOneWidget);
      expect(chartPoints(tester), n > 20 ? 20 : n);
      expect(
        find.text('First session'),
        n == 1 ? findsOneWidget : findsNothing,
      );
      await unmount(tester);
    });
  }

  testWidgets('PR badge shows when latest session is heavier', (tester) async {
    await tester.runAsync(() => seed([progressed, heavier]));
    await pumpScreen(tester, const ExerciseDetailScreen(exerciseId: inclineId));

    expect(find.textContaining('PR ·'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('no PR badge for a first or lighter latest session', (
    tester,
  ) async {
    await tester.runAsync(() => seed([progressed, heavier, lighter]));
    await pumpScreen(tester, const ExerciseDetailScreen(exerciseId: inclineId));

    expect(find.textContaining('PR ·'), findsNothing);
    await unmount(tester);
  });

  testWidgets('history tab lists sessions with set rows', (tester) async {
    await tester.runAsync(() => seed([progressed, heavier]));
    await pumpScreen(tester, const ExerciseDetailScreen(exerciseId: inclineId));

    await tester.tap(find.text('History'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Set 1'), findsNWidgets(2));
    expect(find.text('Set 3 ↑'), findsNWidgets(2));
    expect(find.text('25 kg'), findsOneWidget);
    expect(find.text('22.5 kg'), findsWidgets);
    await unmount(tester);
  });

  testWidgets('progress tab lists exercise with base weight and bars', (
    tester,
  ) async {
    await tester.runAsync(() => seed([progressed]));
    await pumpScreen(tester, const ProgressScreen());

    expect(find.text('Progress'), findsOneWidget);
    expect(find.text('Workouts per week'), findsOneWidget);
    expect(find.text('Incline Dumbbell Bench Press'), findsOneWidget);
    expect(find.text('22.5 kg'), findsOneWidget);
    final chart = tester.widget<BarChart>(find.byType(BarChart));
    expect(chart.data.barGroups, hasLength(8));
    expect(chart.data.barGroups.last.barRods.single.toY, 1);
    await unmount(tester);
  });
}
