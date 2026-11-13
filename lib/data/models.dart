import 'package:fitapp/data/db/app_database.dart';
import 'package:fitapp/domain/progression.dart';
import 'package:fitapp/domain/stats.dart';
import 'package:meta/meta.dart';

/// Converts a stored plan row into a domain [Plan].
Plan planFromRow(PlanRow r) => Plan(
  baseWeight: r.baseWeight,
  targetReps: r.targetReps,
  targetSets: r.targetSets,
  increment: r.increment,
);

/// A stored plan with its rest override: an exercise's own plan
/// (`exercise_state`) or a template exercise's plan (feature 005).
@immutable
class StoredPlan {
  const new({
    required this.baseWeight,
    required this.targetReps,
    required this.targetSets,
    required this.increment,
    this.restSeconds,
  });

  /// From an exercise's own plan row.
  factory fromRow(PlanRow r) => StoredPlan(
    baseWeight: r.baseWeight,
    targetReps: r.targetReps,
    targetSets: r.targetSets,
    increment: r.increment,
    restSeconds: r.restSeconds,
  );

  final double baseWeight;
  final int targetReps;
  final int targetSets;
  final double increment;

  /// NULL = use the default rest time from settings.
  final int? restSeconds;

  /// The plan of a template exercise, or null when it has none yet.
  static StoredPlan? ofTemplate(TemplateExerciseRow r) {
    final base = r.baseWeight;
    final reps = r.targetReps;
    final sets = r.targetSets;
    final inc = r.increment;
    if (base == null || reps == null || sets == null || inc == null) {
      return null;
    }
    return StoredPlan(
      baseWeight: base,
      targetReps: reps,
      targetSets: sets,
      increment: inc,
      restSeconds: r.restSeconds,
    );
  }

  /// Validated domain plan (throws [ArgumentError] when invalid).
  Plan toPlan() => Plan(
    baseWeight: baseWeight,
    targetReps: targetReps,
    targetSets: targetSets,
    increment: increment,
  );

  StoredPlan withBase(double base) => StoredPlan(
    baseWeight: base,
    targetReps: targetReps,
    targetSets: targetSets,
    increment: increment,
    restSeconds: restSeconds,
  );

  @override
  bool operator ==(Object other) =>
      other is StoredPlan &&
      other.baseWeight == baseWeight &&
      other.targetReps == targetReps &&
      other.targetSets == targetSets &&
      other.increment == increment &&
      other.restSeconds == restSeconds;

  @override
  int get hashCode =>
      Object.hash(baseWeight, targetReps, targetSets, increment, restSeconds);
}

/// Which plan a workout exercise uses and progresses (feature 005).
enum PlanSourceKind {
  /// The exercise's own plan (ad-hoc sessions).
  exercise,

  /// The plan of the template exercise the session came from.
  template,

  /// The session came from a template exercise that no longer exists; it
  /// never changes any plan.
  orphan,
}

/// The snapshot plan stored on a workout exercise, if any.
Plan? snapshotOf(WorkoutExerciseRow we) {
  final base = we.planBaseWeight;
  final reps = we.planTargetReps;
  final sets = we.planTargetSets;
  final inc = we.planIncrement;
  if (base == null || reps == null || sets == null || inc == null) return null;
  return Plan(
    baseWeight: base,
    targetReps: reps,
    targetSets: sets,
    increment: inc,
  );
}

LoggedSet loggedFromRow(SetRow r) =>
    LoggedSet(setNo: r.setNo, weight: r.weight, reps: r.reps);

/// One exercise inside a workout, with everything the workout screen needs.
class WorkoutExerciseDetail {
  const new({
    required this.row,
    required this.exercise,
    required this.currentPlan,
    required this.sets,
    required this.previous,
    required this.restSeconds,
    this.planSource = PlanSourceKind.exercise,
  });

  final WorkoutExerciseRow row;
  final ExerciseRow exercise;

  /// The current plan of the session's plan source (null if not set up yet,
  /// or for an orphan).
  final StoredPlan? currentPlan;

  /// Where [currentPlan] lives and what this session progresses.
  final PlanSourceKind planSource;

  /// Logged sets ordered by set number.
  final List<SetRow> sets;

  /// Sets of the previous session of this exercise (null if none).
  final List<SetRow>? previous;

  /// Per-exercise rest override (null = default).
  final int? restSeconds;

  /// The plan that drives prescription: the snapshot for a session that has
  /// one, otherwise the current plan.
  Plan? get effectivePlan => snapshotOf(row) ?? currentPlan?.toPlan();

  List<LoggedSet> get logged => sets.map(loggedFromRow).toList();

  SetRow? setNo(int n) {
    for (final s in sets) {
      if (s.setNo == n) return s;
    }
    return null;
  }

  SetRow? previousSetNo(int n) {
    for (final s in previous ?? const <SetRow>[]) {
      if (s.setNo == n) return s;
    }
    return null;
  }

  SessionSummary get summary => summarizeSession(
    logged,
    perHand: exercise.isPerHand,
    overloadSetNo: effectivePlan?.targetSets,
  );

  SessionSummary? get previousSummary => previous == null
      ? null
      : summarizeSession(
          previous!.map(loggedFromRow),
          perHand: exercise.isPerHand,
          overloadSetNo: _overloadNo(previous!),
        );
}

int? _overloadNo(List<SetRow> sets) {
  for (final s in sets) {
    if (s.isOverload) return s.setNo;
  }
  return null;
}

class WorkoutDetail {
  const new({required this.workout, required this.exercises});

  final WorkoutRow workout;
  final List<WorkoutExerciseDetail> exercises;

  bool get isFinished => workout.endedAt != null;

  int get setCount => exercises.fold(0, (n, e) => n + e.sets.length);

  double get volume => exercises.fold(0, (v, e) => v + e.summary.volume);
}

/// Per-exercise outcome of finishing a workout.
class FinishOutcome {
  const new({
    required this.exerciseName,
    required this.fromBase,
    required this.toBase,
    required this.reason,
  });

  final String exerciseName;
  final double fromBase;
  final double toBase;
  final EvalReason reason;

  bool get progressed => reason == EvalReason.progressed;
}

class FinishResult {
  const new({required this.outcomes, required this.discarded});

  final List<FinishOutcome> outcomes;

  /// True when the workout had no logged sets and was discarded instead.
  final bool discarded;
}

class WorkoutListItem {
  const new({
    required this.id,
    required this.startedAt,
    required this.endedAt,
    required this.exerciseNames,
    required this.volume,
    required this.setCount,
  });

  final String id;
  final DateTime startedAt;
  final DateTime? endedAt;
  final List<String> exerciseNames;
  final double volume;
  final int setCount;

  Duration get duration => (endedAt ?? startedAt).difference(startedAt);
}

class HomeStats {
  const new({
    required this.thisWeek,
    required this.streak,
    required this.total,
    required this.recent,
  });

  final int thisWeek;
  final int streak;
  final int total;
  final List<WorkoutListItem> recent;
}

class TrainedExercise {
  const new({
    required this.exercise,
    required this.plan,
    required this.lastTrained,
  });

  final ExerciseRow exercise;
  final PlanRow? plan;
  final DateTime lastTrained;
}

/// One finished session of one exercise.
class ExerciseSession {
  const new({
    required this.workoutId,
    required this.date,
    required this.sets,
    required this.perHand,
  });

  final String workoutId;
  final DateTime date;
  final List<SetRow> sets;
  final bool perHand;

  int? get overloadSetNo => _overloadNo(sets);

  SessionSummary get summary => summarizeSession(
    sets.map(loggedFromRow),
    perHand: perHand,
    overloadSetNo: overloadSetNo,
  );
}

extension PlanRowX on PlanRow {
  Plan toPlan() => planFromRow(this);
}

/// A workout template with its exercises in order (feature 003).
class TemplateSummary {
  const new({
    required this.id,
    required this.name,
    required this.exercises,
    required this.createdAt,
    required this.lastUsedAt,
    this.plans = const {},
  });

  final String id;
  final String name;
  final List<ExerciseRow> exercises;

  /// This template's plan per exercise id (feature 005); a missing or null
  /// entry means "no plan yet".
  final Map<String, StoredPlan?> plans;
  final DateTime createdAt;
  final DateTime? lastUsedAt;
}
