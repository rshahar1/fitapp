import 'package:fitapp/domain/progression.dart';
import 'package:flutter_test/flutter_test.dart';

Plan plan({double base = 20, int reps = 10, int sets = 3, double inc = 2.5}) =>
    Plan(baseWeight: base, targetReps: reps, targetSets: sets, increment: inc);

LoggedSet s(int no, double w, int r) =>
    LoggedSet(setNo: no, weight: w, reps: r);

void main() {
  group('roundWeight', () {
    test('removes float drift', () {
      expect(roundWeight(0.1 + 0.2 + 22.2), 22.5);
    });
    test('rounds to nearest 0.25', () {
      expect(roundWeight(20.1), 20);
      expect(roundWeight(20.13), 20.25);
      expect(roundWeight(0), 0);
    });
  });

  group('Plan validation', () {
    test('valid plan', () {
      final p = plan();
      expect(p.baseWeight, 20);
      expect(p.overloadWeight, 22.5);
      expect(p, plan());
      expect(p.hashCode, plan().hashCode);
      expect(p.toString(), contains('base: 20'));
    });
    test('targetSets < 2 throws', () {
      expect(() => plan(sets: 1), throwsArgumentError);
    });
    test('targetReps < 1 throws', () {
      expect(() => plan(reps: 0), throwsArgumentError);
    });
    test('increment <= 0 throws', () {
      expect(() => plan(inc: 0), throwsArgumentError);
      expect(() => plan(inc: -2.5), throwsArgumentError);
    });
    test('negative base throws', () {
      expect(() => plan(base: -1), throwsArgumentError);
    });
    test('zero base allowed', () {
      expect(plan(base: 0).overloadWeight, 2.5);
    });
  });

  group('prescribe', () {
    test('3 sets: base, base, base + inc', () {
      expect(prescribe(plan()), const [
        PrescribedSet(setNo: 1, weight: 20, reps: 10, isOverload: false),
        PrescribedSet(setNo: 2, weight: 20, reps: 10, isOverload: false),
        PrescribedSet(setNo: 3, weight: 22.5, reps: 10, isOverload: true),
      ]);
    });
    test('4 sets', () {
      final p = prescribe(plan(sets: 4, reps: 8));
      expect(p.map((e) => e.weight), [20, 20, 20, 22.5]);
      expect(p.where((e) => e.isOverload).single.setNo, 4);
      expect(p.every((e) => e.reps == 8), isTrue);
    });
    test('+5 variant', () {
      final p = prescribe(plan(base: 100, inc: 5));
      expect(p.map((e) => e.weight), [100, 100, 105]);
    });
    test('value semantics and toString', () {
      const a = PrescribedSet(
        setNo: 3,
        weight: 22.5,
        reps: 10,
        isOverload: true,
      );
      expect(a.hashCode, isA<int>());
      expect(a.toString(), contains('overload'));
      expect(
        const PrescribedSet(
          setNo: 1,
          weight: 20,
          reps: 10,
          isOverload: false,
        ).toString(),
        isNot(contains('overload')),
      );
    });
  });

  group('evaluate', () {
    test('progressed', () {
      final e = evaluate(plan(), [s(1, 20, 10), s(2, 20, 10), s(3, 22.5, 6)]);
      expect(e.progressed, isTrue);
      expect(e.nextBaseWeight, 22.5);
      expect(e.reason, EvalReason.progressed);
      expect(e.reason.code, 'progressed');
      expect(e.toString(), contains('progressed'));
    });
    test('exceeding target reps still progresses', () {
      final e = evaluate(plan(), [s(1, 20, 12), s(2, 20, 11), s(3, 22.5, 10)]);
      expect(e.reason, EvalReason.progressed);
    });
    test('missed reps on set 2', () {
      final e = evaluate(plan(), [s(1, 20, 10), s(2, 20, 8), s(3, 22.5, 6)]);
      expect(e.progressed, isFalse);
      expect(e.nextBaseWeight, 20);
      expect(e.reason, EvalReason.missedReps);
      expect(e.reason.code, 'missed_reps');
    });
    test('reps hit at a lighter weight than base do not count', () {
      final e = evaluate(plan(), [s(1, 17.5, 10), s(2, 20, 10), s(3, 22.5, 6)]);
      expect(e.reason, EvalReason.missedReps);
    });
    test(
      'heavier than prescribed overload sets next base to lifted weight',
      () {
        final e = evaluate(plan(), [s(1, 20, 10), s(2, 20, 10), s(3, 25, 3)]);
        expect(e.nextBaseWeight, 25);
      },
    );
    test('overload missing', () {
      final e = evaluate(plan(), [s(1, 20, 10), s(2, 20, 10)]);
      expect(e.reason, EvalReason.noOverloadSet);
      expect(e.reason.code, 'no_overload_set');
      expect(e.nextBaseWeight, 20);
    });
    test('overload not heavier', () {
      final e = evaluate(plan(), [s(1, 20, 10), s(2, 20, 10), s(3, 20, 12)]);
      expect(e.reason, EvalReason.overloadNotHeavier);
      expect(e.reason.code, 'overload_not_heavier');
    });
    test('working set missing', () {
      final e = evaluate(plan(), [s(1, 20, 10), s(3, 22.5, 10)]);
      expect(e.reason, EvalReason.incomplete);
      expect(e.reason.code, 'incomplete');
    });
    test('incomplete is checked before missed reps', () {
      final e = evaluate(plan(sets: 4), [s(1, 20, 5), s(4, 22.5, 10)]);
      expect(e.reason, EvalReason.incomplete);
    });
    test('order independent', () {
      final e = evaluate(plan(), [s(3, 22.5, 6), s(1, 20, 10), s(2, 20, 10)]);
      expect(e.reason, EvalReason.progressed);
    });
    test('extra sets beyond N are ignored', () {
      final e = evaluate(plan(), [
        s(1, 20, 10),
        s(2, 20, 10),
        s(3, 22.5, 6),
        s(4, 10, 2),
      ]);
      expect(e.nextBaseWeight, 22.5);
    });
    test('overload weight is rounded', () {
      final e = evaluate(plan(), [
        s(1, 20, 10),
        s(2, 20, 10),
        s(3, 0.1 + 0.2 + 22.2, 6),
      ]);
      expect(e.nextBaseWeight, 22.5);
    });
    test('scenario 2: missed reps keeps 22.5', () {
      final e = evaluate(plan(base: 22.5), [
        s(1, 22.5, 10),
        s(2, 22.5, 8),
        s(3, 25, 4),
      ]);
      expect(e.reason, EvalReason.missedReps);
      expect(e.nextBaseWeight, 22.5);
    });
  });

  group('LoggedSet', () {
    test('value semantics', () {
      expect(s(1, 20, 10), s(1, 20, 10));
      expect(s(1, 20, 10).hashCode, s(1, 20, 10).hashCode);
      expect(s(1, 20, 10), isNot(s(1, 20, 9)));
      expect(s(1, 20, 10).toString(), 'LoggedSet(1: 20.0 x 10)');
    });
  });

  group('canRewriteBase', () {
    test('latest and matching -> true', () {
      expect(
        canRewriteBase(
          isLatestSessionForExercise: true,
          currentBase: 22.5,
          resultBaseWeight: 22.5,
        ),
        isTrue,
      );
    });
    test('matching after rounding -> true', () {
      expect(
        canRewriteBase(
          isLatestSessionForExercise: true,
          currentBase: 0.1 + 0.2 + 22.2,
          resultBaseWeight: 22.5,
        ),
        isTrue,
      );
    });
    test('plan edited since -> false', () {
      expect(
        canRewriteBase(
          isLatestSessionForExercise: true,
          currentBase: 30,
          resultBaseWeight: 22.5,
        ),
        isFalse,
      );
    });
    test('not latest -> false', () {
      expect(
        canRewriteBase(
          isLatestSessionForExercise: false,
          currentBase: 22.5,
          resultBaseWeight: 22.5,
        ),
        isFalse,
      );
    });
    test('never applied -> false', () {
      expect(
        canRewriteBase(
          isLatestSessionForExercise: true,
          currentBase: 22.5,
          resultBaseWeight: null,
        ),
        isFalse,
      );
    });
  });
}
