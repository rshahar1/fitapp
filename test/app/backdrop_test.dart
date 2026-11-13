import 'package:fitapp/app/backdrop.dart';
import 'package:fitapp/app/theme/app_theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(),
      home: AppBackdrop(child: child),
    ),
  );

  testWidgets('child is shown and hit-testable', (tester) async {
    var taps = 0;
    await pump(
      tester,
      Center(
        child: TextButton(onPressed: () => taps++, child: const Text('Tap me')),
      ),
    );
    await tester.pump();
    expect(find.text('Tap me'), findsOneWidget);
    await tester.tap(find.text('Tap me'));
    expect(taps, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('decoration adds no semantics besides the child', (tester) async {
    final handle = tester.ensureSemantics();
    await pump(tester, const Center(child: Text('Hello')));
    await tester.pump();
    expect(find.bySemanticsLabel('Hello'), findsOneWidget);
    final images = find.descendant(
      of: find.byType(AppBackdrop),
      matching: find.byType(Image),
    );
    for (final e in images.evaluate()) {
      expect((e.widget as Image).excludeFromSemantics, isTrue);
    }
    expect(tester.takeException(), isNull);
    handle.dispose();
  });
}
