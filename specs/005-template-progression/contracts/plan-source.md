# Contract: plan sources and repository API changes

## Domain (`lib/domain/progression.dart`)

```dart
enum EvalReason { incomplete, missedReps, progressed }   // codes: incomplete, missed_reps, progressed
Evaluation evaluate(Plan plan, Iterable<LoggedSet> sets); // nextBase = roundWeight(base + inc) on progress
bool canRewriteBase({required bool isLatestSessionForPlan, required double currentBase,
                     required double? resultBaseWeight});
```

## Models (`lib/data/models.dart`)

```dart
class StoredPlan { double baseWeight; int targetReps; int targetSets; double increment; int? restSeconds;
                   Plan toPlan(); static StoredPlan fromRow(PlanRow); static StoredPlan? ofTemplate(TemplateExerciseRow); }
enum PlanSourceKind { exercise, template, orphan }
WorkoutExerciseDetail { …; StoredPlan? currentPlan; PlanSourceKind planSource; }
TemplateSummary { …; List<ExerciseRow> exercises; Map<String /*exerciseId*/, StoredPlan?> plans; }
```

## WorkoutRepository

- `finishWorkout`, `logSet`, `clearSet`, `recalculate`, `removeExercise`, `resumeWorkout`,
  `deleteWorkout`: progression applies to the session's plan source.
- `savePlan(String workoutExerciseId, StoredPlan plan)`: writes the plan of the session's source
  (exercise plan upsert, or the template exercise's columns). Throws `StateError` for an orphan.
- `workoutDetail`: `currentPlan`/`restSeconds`/`planSource` from the session's source.

## TemplateRepository

- `create({name, exerciseIds, Map<String, StoredPlan> plans = const {}})` and
  `update(id, {name, exerciseIds, plans = const {}})`: new rows take `plans[exerciseId]` or else the
  exercise plan (or none); kept rows are updated only when `plans` has an entry for them.
- `saveFromWorkout(workoutId, {name})`: plans = each session's current source plan.
- `startWorkout(templateId)`: each inserted workout exercise gets `template_exercise_id`.
- `delete(id)` and exercise removal in `update`: unlink workout exercises of unfinished workouts
  with no snapshot that point to the removed template exercises.
