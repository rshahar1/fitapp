import 'package:fitapp/app/theme/app_theme.dart';
import 'package:fitapp/data/providers.dart';
import 'package:fitapp/data/tracking/sim/track_simulation.dart';
import 'package:fitapp/domain/tracking/track_sample.dart';
import 'package:fitapp/features/tracking/widgets/simulation_bar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  late DateTime fakeNow;
  late TrackSimulation sim;

  setUp(() {
    fakeNow = DateTime.utc(2026, 1, 1, 9);
    final t0 = DateTime.utc(2026, 1, 1, 8);
    sim = TrackSimulation([
      for (var i = 0; i < 5; i++)
        TrackSample(
          t: t0.add(Duration(seconds: i)),
          lat: 45.0 + i * 0.0001,
          lon: 6.5,
          accuracy: 5,
          speed: 1,
        ),
    ], realClock: () => fakeNow);
  });

  tearDown(() => sim.dispose());

  Future<void> pump(WidgetTester tester, {bool withSim = true}) {
    return tester.pumpWidget(
      ProviderScope(
        overrides: [if (withSim) simulationProvider.overrideWithValue(sim)],
        child: MaterialApp(
          theme: buildAppTheme(),
          home: const Scaffold(body: SimulationBar()),
        ),
      ),
    );
  }

  testWidgets('shows nothing without a simulation', (tester) async {
    await pump(tester, withSim: false);
    expect(find.text('SIMULATED GPS'), findsNothing);
  });

  testWidgets('shows the banner, status and speeds', (tester) async {
    await pump(tester);
    expect(find.text('SIMULATED GPS'), findsOneWidget);
    expect(find.text('Val Thorens · at the base'), findsOneWidget);
    for (final s in ['1×', '5×', '10×', '30×']) {
      expect(find.text(s), findsOneWidget);
    }
  });

  testWidgets('tapping a speed sets it', (tester) async {
    await pump(tester);
    await tester.tap(find.text('10×'));
    await tester.pump();
    expect(sim.speed, 10);
    expect(find.text('10×'), findsOneWidget);
  });

  testWidgets('shows progress while replaying', (tester) async {
    await pump(tester);
    final sub = sim.fixes.listen((_) {});
    addTearDown(sub.cancel);
    sim.startReplay('s1');
    fakeNow = fakeNow.add(const Duration(seconds: 2));
    sim.poll();
    await tester.pump();
    expect(find.textContaining(' / '), findsOneWidget);
  });

  testWidgets('does not overflow on a narrow screen', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pump(tester);
    expect(tester.takeException(), isNull);
  });
}
