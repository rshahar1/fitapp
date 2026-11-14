import 'package:fitapp/domain/milestones.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('firstTwoSetsHitTarget', () {
    test('both sets exactly on target', () {
      expect(
        firstTwoSetsHitTarget(targetReps: 10, set1Reps: 10, set2Reps: 10),
        isTrue,
      );
    });
    test('both sets above target', () {
      expect(
        firstTwoSetsHitTarget(targetReps: 10, set1Reps: 12, set2Reps: 11),
        isTrue,
      );
    });
    test('set 1 short', () {
      expect(
        firstTwoSetsHitTarget(targetReps: 10, set1Reps: 9, set2Reps: 10),
        isFalse,
      );
    });
    test('set 2 short', () {
      expect(
        firstTwoSetsHitTarget(targetReps: 10, set1Reps: 10, set2Reps: 8),
        isFalse,
      );
    });
    test('set 2 not logged yet', () {
      expect(firstTwoSetsHitTarget(targetReps: 10, set1Reps: 10), isFalse);
    });
    test('set 1 not logged yet', () {
      expect(firstTwoSetsHitTarget(targetReps: 10, set2Reps: 10), isFalse);
    });
    test('no plan means no target', () {
      expect(firstTwoSetsHitTarget(set1Reps: 10, set2Reps: 10), isFalse);
    });
  });
}
