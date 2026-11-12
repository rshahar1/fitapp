import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'workout_flow.dart';

void main() {
  testWidgets('end-to-end: log a workout and see progression', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await runWorkoutFlow(
      tester,
      settle: () async {
        for (var i = 0; i < 4; i++) {
          await tester.runAsync(() => Future<void>.delayed(Duration.zero));
          await tester.pump(const Duration(milliseconds: 400));
        }
      },
    );
  });
}
