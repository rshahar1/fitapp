// Runs the end-to-end flow on a device or emulator:
//   flutter test integration_test
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/e2e/gps_flow.dart';
import '../test/e2e/workout_flow.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('end-to-end: log a workout and see progression', (tester) async {
    await runWorkoutFlow(tester, settle: () => tester.pumpAndSettle());
  });

  testWidgets('end-to-end: record a GPS run and open its detail', (
    tester,
  ) async {
    // Bounded pumps: the live screen animates forever, so pumpAndSettle
    // would never settle.
    await runGpsFlow(
      tester,
      settle: () async {
        for (var i = 0; i < 4; i++) {
          await tester.pump(const Duration(milliseconds: 400));
        }
      },
    );
  });

  testWidgets('end-to-end: record a snowboarding day, review and replay', (
    tester,
  ) async {
    await runSnowFlow(
      tester,
      settle: () async {
        for (var i = 0; i < 4; i++) {
          await tester.pump(const Duration(milliseconds: 400));
        }
      },
    );
  });
}
