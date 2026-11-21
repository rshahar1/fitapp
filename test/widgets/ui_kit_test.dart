import 'package:fitapp/app/backdrop.dart';
import 'package:fitapp/app/theme/app_icons.dart';
import 'package:fitapp/app/theme/app_theme.dart';
import 'package:fitapp/core/haptics.dart';
import 'package:fitapp/domain/stats.dart';
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

Widget _app(Widget child, _FakeHaptics haptics) => ProviderScope(
  overrides: [hapticsProvider.overrideWithValue(haptics)],
  child: MaterialApp(
    theme: buildAppTheme(),
    home: Scaffold(body: Center(child: child)),
  ),
);

void main() {
  testWidgets('AppStepper clamps at min and ticks', (tester) async {
    final h = _FakeHaptics();
    var value = 1.0;
    await tester.pumpWidget(
      _app(
        StatefulBuilder(
          builder: (context, set) => AppStepper(
            label: 'Reps',
            value: value,
            step: 1,
            onChanged: (v) => set(() => value = v),
          ),
        ),
        h,
      ),
    );
    await tester.tap(find.bySemanticsLabel('Decrease Reps'));
    await tester.pump();
    expect(value, 0);
    expect(h.ticks, 1);
    await tester.tap(find.bySemanticsLabel('Decrease Reps'));
    await tester.pump();
    expect(value, 0);
    expect(h.ticks, 1);
    await tester.tap(find.bySemanticsLabel('Increase Reps'));
    await tester.pump();
    expect(value, 1);
    expect(h.ticks, 2);
  });

  testWidgets('ChipSelector calls onSelected', (tester) async {
    String? picked;
    await tester.pumpWidget(
      _app(
        ChipSelector<String>(
          options: const ['A', 'B'],
          selected: 'A',
          labelOf: (s) => s,
          onSelected: (s) => picked = s,
        ),
        _FakeHaptics(),
      ),
    );
    await tester.tap(find.text('B'));
    expect(picked, 'B');
  });

  testWidgets('AppButton disabled when onPressed is null', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      _app(
        Column(
          children: [
            const AppButton(label: 'Off', onPressed: null),
            AppButton(label: 'On', onPressed: () => taps++),
          ],
        ),
        _FakeHaptics(),
      ),
    );
    await tester.tap(find.text('Off'));
    expect(taps, 0);
    await tester.tap(find.text('On'));
    expect(taps, 1);
  });

  testWidgets('other widgets render', (tester) async {
    await tester.pumpWidget(
      _app(
        SingleChildScrollView(
          child: Column(
            children: [
              const AppCard(child: Text('card')),
              Group(
                header: 'Head',
                children: [
                  GroupRow(
                    title: 'Row',
                    subtitle: 'sub',
                    onTap: () {},
                    showChevron: true,
                  ),
                  const GroupRow(title: 'Row2'),
                ],
              ),
              const MetricTile(label: 'Sets', value: '12', caption: 'cap'),
              DeltaBadge(delta: MetricDelta.of(10, 9), color: Colors.green),
              DeltaBadge(delta: MetricDelta.of(8, 9), color: Colors.green),
              DeltaBadge(delta: MetricDelta.of(9, 9), color: Colors.green),
              const DeltaBadge(delta: null, color: Colors.green),
              const StatTile(value: '5', label: 'Sets'),
              const SizedBox(
                height: 200,
                child: EmptyState(icon: AppIcons.add, title: 'Nothing'),
              ),
            ],
          ),
        ),
        _FakeHaptics(),
      ),
    );
    expect(find.text('Head'), findsOneWidget);
    expect(find.textContaining('▲'), findsOneWidget);
    expect(find.text('—'), findsOneWidget);
  });

  testWidgets('tap targets meet guideline', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _app(
        Column(
          children: [
            AppButton(label: 'Go', onPressed: () {}),
            AppStepper(label: 'Reps', value: 5, step: 1, onChanged: (_) {}),
            ChipSelector<String>(
              options: const ['A', 'B'],
              selected: 'A',
              labelOf: (s) => s,
              onSelected: (_) {},
            ),
          ],
        ),
        _FakeHaptics(),
      ),
    );
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    handle.dispose();
  });

  testWidgets('AppBackdrop adds no semantics for decoration', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      const MaterialApp(home: AppBackdrop(child: SizedBox.expand())),
    );
    final painted = find.descendant(
      of: find.byType(AppBackdrop),
      matching: find.byType(Image),
    );
    expect(painted, findsWidgets);
    expect(
      find.descendant(
        of: find.byType(AppBackdrop),
        matching: find.byType(ExcludeSemantics),
      ),
      findsOneWidget,
    );
    handle.dispose();
  });
}
