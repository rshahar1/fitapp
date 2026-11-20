import 'package:fitapp/domain/workout_progress.dart';
import 'package:flutter_test/flutter_test.dart';

ExerciseProgress _p(Set<int> logged, [int? planned]) =>
    ExerciseProgress(loggedSetNos: logged, plannedSets: planned);

void main() {
  group('resumeExerciseIndex', () {
    test('no exercises or nothing logged: stay at the top', () {
      expect(resumeExerciseIndex(const []), isNull);
      expect(resumeExerciseIndex([_p({}, 3), _p({}, 3)]), isNull);
    });

    test('the last exercise with sets still has planned sets: itself', () {
      expect(
        resumeExerciseIndex([
          _p({1, 2, 3}, 3),
          _p({1}, 3),
          _p({}, 3),
        ]),
        1,
      );
    });

    test('the last exercise with sets is complete: the next one', () {
      expect(
        resumeExerciseIndex([
          _p({1, 2, 3}, 3),
          _p({1, 2, 3}, 3),
          _p({}, 3),
        ]),
        2,
      );
    });

    test('complete and last: itself', () {
      expect(
        resumeExerciseIndex([
          _p({1}, 3),
          _p({1, 2}, 2),
        ]),
        1,
      );
    });

    test('more sets than planned count as complete', () {
      expect(
        resumeExerciseIndex([
          _p({1, 2, 3, 4}, 3),
          _p({}, 3),
        ]),
        1,
      );
    });

    test('a missing planned set means not complete', () {
      expect(
        resumeExerciseIndex([
          _p({1, 3}, 3),
          _p({}, 3),
        ]),
        0,
      );
    });

    test('no plan: the exercise with sets is current', () {
      expect(
        resumeExerciseIndex([
          _p({1, 2}),
          _p({}),
        ]),
        0,
      );
      expect(
        resumeExerciseIndex([
          _p({1, 2}, 0),
          _p({}),
        ]),
        0,
      );
    });

    test('skipped exercises before the last logged one are ignored', () {
      expect(
        resumeExerciseIndex([
          _p({}, 3),
          _p({1, 2, 3}, 3),
          _p({}, 3),
        ]),
        2,
      );
      expect(
        resumeExerciseIndex([
          _p({}, 3),
          _p({}, 3),
          _p({1}, 3),
        ]),
        2,
      );
    });
  });
}
