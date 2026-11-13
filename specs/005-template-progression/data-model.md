# Data Model: schema v3

## Changed tables

### `template_exercises` (+5 nullable columns)

| Column | Type | Notes |
|---|---|---|
| `base_weight` | REAL NULL | rounded to 0.25 |
| `target_reps` | INTEGER NULL | ≥ 1 |
| `target_sets` | INTEGER NULL | ≥ 2 |
| `increment` | REAL NULL | > 0 |
| `rest_seconds` | INTEGER NULL | NULL = default rest from settings |

The plan exists iff `base_weight`, `target_reps`, `target_sets`, `increment` are all non-NULL.
Validation goes through the domain `Plan` constructor before writing.

### `workout_exercises` (+1 nullable column)

| Column | Type | Notes |
|---|---|---|
| `template_exercise_id` | TEXT NULL | id of the template exercise the session came from; **no FK**; may dangle after template deletion (orphan) |

Index: `workout_exercises_template_exercise ON workout_exercises (template_exercise_id)`.

## Migration v2 → v3 (`onUpgrade`, `from < 3`)

1. `addColumn` × 5 on `template_exercises`, × 1 on `workout_exercises`.
2. Seed: `UPDATE template_exercises SET base_weight = es.base_weight, target_reps = …,
   target_sets = …, increment = …, rest_seconds = es.rest_seconds FROM exercise_state es WHERE
   es.exercise_id = template_exercises.exercise_id` (implemented with correlated sub-selects for
   SQLite compatibility), also setting `dirty = 1`.
3. Create the index. Existing workout exercises keep `template_exercise_id = NULL` (ad hoc).

## Derived concepts (not stored)

- **StoredPlan** (models): base, reps, sets, increment, restSeconds; `toPlan()`; built from
  `PlanRow` or from a `TemplateExerciseRow` with a full plan.
- **PlanSource**: `exercise(exerciseId)` | `template(templateExerciseId)` | `orphan`.

## State transitions per session (unchanged shape, new target)

`live` → finish → snapshot + result written; plan of **its source** set to result if progressed and
the base still equals the snapshot base → edit/resume/delete undo or re-apply on that source only,
guarded by `canRewriteBase` (latest session **for that source**).
