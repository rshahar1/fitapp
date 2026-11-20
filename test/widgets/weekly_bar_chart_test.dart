import 'package:fitapp/app/theme/app_theme.dart';
import 'package:fitapp/domain/stats.dart';
import 'package:fitapp/widgets/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('labels Sunday weeks by date and fits a narrow phone', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(320, 640)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final counts = workoutsPerWeek([
      DateTime(2026, 11, 15),
      DateTime(2026, 11, 18),
      DateTime(2026, 10, 30),
    ], now: DateTime(2026, 11, 20));
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: WeeklyBarChart(counts: counts),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    // Weeks of Sun 27 Sep .. Sun 15 Nov.
    for (final label in ['27 Sep', '4 Oct', '11', '1 Nov', '15']) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    expect(
      find.bySemanticsLabel(
        RegExp(r'starting: 27 Sep: 0.*25: 1, 1 Nov: 0.*15: 2$'),
      ),
      findsOneWidget,
    );
  });
}
