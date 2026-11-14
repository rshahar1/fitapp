import 'package:fitapp/app/theme/app_theme.dart';
import 'package:fitapp/core/haptics.dart';
import 'package:fitapp/widgets/widgets.dart';
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

class _Harness extends StatefulWidget {
  const new({required this.initial, this.max = 1440});
  final int initial;
  final int max;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  late int value = widget.initial;

  @override
  Widget build(BuildContext context) => DurationPicker(
    minutes: value,
    max: widget.max,
    onChanged: (v) => setState(() => value = v),
  );
}

Widget _app(Widget child) => ProviderScope(
  overrides: [hapticsProvider.overrideWithValue(_FakeHaptics())],
  child: MaterialApp(
    theme: buildAppTheme(),
    home: Scaffold(body: SingleChildScrollView(child: child)),
  ),
);

Finder _value(String text) => find.descendant(
  of: find.byKey(const Key('duration-value')),
  matching: find.text(text),
);

void main() {
  testWidgets('presets set the value in one tap', (tester) async {
    await tester.pumpWidget(_app(const _Harness(initial: 30)));
    await tester.tap(find.text('4 h'));
    await tester.pump();
    expect(_value('4 h'), findsOneWidget);
    await tester.tap(find.text('1 h 30'));
    await tester.pump();
    expect(_value('1 h 30 min'), findsOneWidget);
  });

  testWidgets('plus and minus step by 5 and clamp', (tester) async {
    await tester.pumpWidget(_app(const _Harness(initial: 7, max: 10)));
    await tester.tap(find.byIcon(Icons.remove));
    await tester.pump();
    expect(_value('5 min'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();
    expect(_value('10 min'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.add), warnIfMissed: false);
    await tester.pump();
    expect(_value('10 min'), findsOneWidget);
  });

  testWidgets('wheel sheet returns the chosen value', (tester) async {
    await tester.pumpWidget(_app(const _Harness(initial: 30)));
    await tester.tap(find.byKey(const Key('duration-value')));
    await tester.pumpAndSettle();
    // 2 hours (44 dp per item), 15 minutes (3 items).
    await tester.drag(
      find.byKey(const Key('duration-hours-wheel')),
      const Offset(0, -88),
    );
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const Key('duration-minutes-wheel')),
      const Offset(0, -44),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('DONE'));
    await tester.pumpAndSettle();
    expect(_value('2 h 35 min'), findsOneWidget);
  });

  testWidgets('wheel sheet preselects nearest lower multiple of 5', (
    tester,
  ) async {
    await tester.pumpWidget(_app(const _Harness(initial: 47)));
    await tester.tap(find.byKey(const Key('duration-value')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('DONE'));
    await tester.pumpAndSettle();
    expect(_value('45 min'), findsOneWidget);
  });
}
