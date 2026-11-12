// Runs the end-to-end flow on a device or emulator:
//   flutter test integration_test
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/e2e/workout_flow.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('end-to-end: log a workout and see progression', (tester) async {
    await runWorkoutFlow(tester, settle: () => tester.pumpAndSettle());
  });
}
