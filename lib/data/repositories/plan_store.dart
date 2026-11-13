import 'package:drift/drift.dart';
import 'package:fitapp/data/db/app_database.dart';
import 'package:fitapp/data/models.dart';
import 'package:fitapp/domain/progression.dart';

/// Shared reads and writes of stored plans: an exercise's own plan
/// (`exercise_state`) and a template exercise's plan (feature 005).
/// Callers own the transaction.
extension PlanStore on AppDatabase {
  /// Validates [plan] through the domain [Plan] and the rest-time bounds;
  /// returns it with rounded weights. Throws [ArgumentError] when invalid.
  StoredPlan validatedPlan(StoredPlan plan) {
    final p = plan.toPlan();
    final rest = plan.restSeconds;
    if (rest != null && (rest < 10 || rest > 600)) {
      throw ArgumentError.value(rest, 'restSeconds', '10..600');
    }
    return StoredPlan(
      baseWeight: p.baseWeight,
      targetReps: p.targetReps,
      targetSets: p.targetSets,
      increment: p.increment,
      restSeconds: rest,
    );
  }

  Future<StoredPlan?> exercisePlan(String exerciseId) async {
    final row = await (select(
      exerciseState,
    )..where((p) => p.exerciseId.equals(exerciseId))).getSingleOrNull();
    return row == null ? null : StoredPlan.fromRow(row);
  }

  /// Creates or replaces an exercise's own plan.
  Future<void> writeExercisePlan(String exerciseId, StoredPlan plan) async {
    final p = validatedPlan(plan);
    await into(exerciseState).insertOnConflictUpdate(
      ExerciseStateCompanion.insert(
        exerciseId: exerciseId,
        baseWeight: p.baseWeight,
        targetReps: p.targetReps,
        targetSets: p.targetSets,
        increment: p.increment,
        restSeconds: Value(p.restSeconds),
        updatedAt: now(),
        dirty: const Value(true),
      ),
    );
  }

  Future<TemplateExerciseRow?> templateExercise(String id) => (select(
    templateExercises,
  )..where((t) => t.id.equals(id))).getSingleOrNull();

  /// Replaces a template exercise's plan.
  Future<void> writeTemplatePlan(String templateExerciseId, StoredPlan plan) {
    final p = validatedPlan(plan);
    return (update(templateExercises)
          ..where((t) => t.id.equals(templateExerciseId)))
        .write(templatePlanCompanion(p));
  }

  /// Companion that sets the plan columns of a template exercise.
  TemplateExercisesCompanion templatePlanCompanion(StoredPlan? p) =>
      TemplateExercisesCompanion(
        baseWeight: Value(p?.baseWeight),
        targetReps: Value(p?.targetReps),
        targetSets: Value(p?.targetSets),
        increment: Value(p?.increment),
        restSeconds: Value(p?.restSeconds),
        updatedAt: Value(now()),
        dirty: const Value(true),
      );
}
