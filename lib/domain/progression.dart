/// Progression engine: prescription, evaluation and history-safety rules.
///
/// Pure Dart. No Flutter, database or I/O imports (constitution principle II).
library;

import 'package:meta/meta.dart';

/// Rounds [kg] to the nearest 0.25 kg to remove floating-point drift.
double roundWeight(double kg) => (kg * 4).round() / 4;

/// A training plan for one exercise.
@immutable
class Plan {
  /// Creates a validated plan. Throws [ArgumentError] when invalid.
  new({
    required double baseWeight,
    required this.targetReps,
    required this.targetSets,
    required double increment,
  }) : baseWeight = roundWeight(baseWeight),
       increment = roundWeight(increment) {
    if (targetSets < 2) {
      throw ArgumentError.value(targetSets, 'targetSets', 'must be >= 2');
    }
    if (targetReps < 1) {
      throw ArgumentError.value(targetReps, 'targetReps', 'must be >= 1');
    }
    if (!(increment > 0)) {
      throw ArgumentError.value(increment, 'increment', 'must be > 0');
    }
    if (baseWeight < 0) {
      throw ArgumentError.value(baseWeight, 'baseWeight', 'must be >= 0');
    }
  }

  /// Working weight for sets 1..N-1.
  final double baseWeight;

  /// Target reps per set.
  final int targetReps;

  /// Number of sets N; set N is the overload set.
  final int targetSets;

  /// Added to [baseWeight] for the overload set.
  final double increment;

  /// Weight prescribed for the overload set.
  double get overloadWeight => roundWeight(baseWeight + increment);

  @override
  bool operator ==(Object other) =>
      other is Plan &&
      other.baseWeight == baseWeight &&
      other.targetReps == targetReps &&
      other.targetSets == targetSets &&
      other.increment == increment;

  @override
  int get hashCode =>
      Object.hash(baseWeight, targetReps, targetSets, increment);

  @override
  String toString() =>
      'Plan(base: $baseWeight, reps: $targetReps, sets: $targetSets, '
      'inc: $increment)';
}

/// One prescribed set.
@immutable
class PrescribedSet {
  /// Creates a prescribed set.
  const new({
    required this.setNo,
    required this.weight,
    required this.reps,
    required this.isOverload,
  });

  /// 1-based set number.
  final int setNo;

  /// Prescribed weight (kg).
  final double weight;

  /// Prescribed reps.
  final int reps;

  /// Whether this is the overload (last) set.
  final bool isOverload;

  @override
  bool operator ==(Object other) =>
      other is PrescribedSet &&
      other.setNo == setNo &&
      other.weight == weight &&
      other.reps == reps &&
      other.isOverload == isOverload;

  @override
  int get hashCode => Object.hash(setNo, weight, reps, isOverload);

  @override
  String toString() =>
      'PrescribedSet($setNo: $weight x $reps${isOverload ? ' overload' : ''})';
}

/// One logged set.
@immutable
class LoggedSet {
  /// Creates a logged set.
  const new({required this.setNo, required this.weight, required this.reps});

  /// 1-based set number.
  final int setNo;

  /// Weight lifted (kg; per hand for per-hand exercises).
  final double weight;

  /// Reps done.
  final int reps;

  @override
  bool operator ==(Object other) =>
      other is LoggedSet &&
      other.setNo == setNo &&
      other.weight == weight &&
      other.reps == reps;

  @override
  int get hashCode => Object.hash(setNo, weight, reps);

  @override
  String toString() => 'LoggedSet($setNo: $weight x $reps)';
}

/// Prescribes sets 1..N for [plan]: base for working sets, base + increment
/// for the overload set N.
List<PrescribedSet> prescribe(Plan plan) => [
  for (var i = 1; i <= plan.targetSets; i++)
    PrescribedSet(
      setNo: i,
      weight: i == plan.targetSets ? plan.overloadWeight : plan.baseWeight,
      reps: plan.targetReps,
      isOverload: i == plan.targetSets,
    ),
];

/// Why an evaluation came out the way it did.
enum EvalReason {
  /// A working set was not logged.
  incomplete('incomplete'),

  /// A working set missed reps or was lighter than base.
  missedReps('missed_reps'),

  /// The overload set was not logged.
  noOverloadSet('no_overload_set'),

  /// The overload set was not heavier than base.
  overloadNotHeavier('overload_not_heavier'),

  /// The base weight goes up.
  progressed('progressed');

  new(this.code);

  /// Stable string code (PRD §4.2).
  final String code;
}

/// Result of evaluating a session against a plan.
class Evaluation {
  /// Creates an evaluation.
  const new({
    required this.progressed,
    required this.nextBaseWeight,
    required this.reason,
  });

  /// Whether the base weight increases.
  final bool progressed;

  /// The base weight for the next session.
  final double nextBaseWeight;

  /// Why.
  final EvalReason reason;

  @override
  String toString() => 'Evaluation(${reason.code}, next: $nextBaseWeight)';
}

/// Evaluates logged [sets] against [plan] (PRD §4.2). Order-independent;
/// sets beyond N are ignored. If a set number appears more than once the last
/// one wins.
Evaluation evaluate(Plan plan, Iterable<LoggedSet> sets) {
  final bySetNo = <int, LoggedSet>{for (final s in sets) s.setNo: s};
  final base = plan.baseWeight;
  Evaluation stay(EvalReason reason) =>
      Evaluation(progressed: false, nextBaseWeight: base, reason: reason);

  final working = [for (var i = 1; i < plan.targetSets; i++) bySetNo[i]];
  if (working.any((s) => s == null)) return stay(EvalReason.incomplete);
  if (working.any(
    (s) => s!.reps < plan.targetReps || roundWeight(s.weight) < base,
  )) {
    return stay(EvalReason.missedReps);
  }
  final overload = bySetNo[plan.targetSets];
  if (overload == null) return stay(EvalReason.noOverloadSet);
  final lifted = roundWeight(overload.weight);
  if (lifted <= base) return stay(EvalReason.overloadNotHeavier);
  return Evaluation(
    progressed: true,
    nextBaseWeight: lifted,
    reason: EvalReason.progressed,
  );
}

/// Whether editing, resuming or deleting a finished workout may rewrite the
/// current base weight (PRD §4.4).
bool canRewriteBase({
  required bool isLatestSessionForExercise,
  required double currentBase,
  required double? resultBaseWeight,
}) =>
    isLatestSessionForExercise &&
    resultBaseWeight != null &&
    roundWeight(currentBase) == roundWeight(resultBaseWeight);
