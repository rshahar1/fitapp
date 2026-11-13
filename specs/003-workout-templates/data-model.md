# Data Model: Workout Templates (003)

Schema version **1 → 2**. Migration only creates the two new tables and their index; no existing
data is touched (constitution I). Covered by a drift schema-migration test using the committed
`drift_schemas/fitapp/drift_schema_v1.json`.

## templates
| Column | Type | Rules |
|---|---|---|
| id | TEXT PK | UUID v4 |
| name | TEXT NOT NULL | trimmed, 1–40 chars; unique ignoring case (`UNIQUE INDEX templates_name_ci ON templates(lower(name))`) |
| created_at | DATETIME NOT NULL | UTC |
| last_used_at | DATETIME NULL | set when a workout is started from it |
| updated_at | DATETIME NOT NULL | |
| dirty | BOOL NOT NULL default 1 | |

## template_exercises
| Column | Type | Rules |
|---|---|---|
| id | TEXT PK | UUID v4 |
| template_id | TEXT → templates.id ON DELETE CASCADE | |
| exercise_id | TEXT → exercises.id | |
| position | INT NOT NULL | 0-based, contiguous |
| updated_at, dirty | | |

`UNIQUE(template_id, exercise_id)` — one entry per exercise per template.

## Ordering

Templates list: `last_used_at DESC NULLS LAST, created_at DESC`.

## Writes (all in one transaction each)

- **create(name, exerciseIds)**: validate, insert template + rows (positions 0..n-1, duplicates
  dropped keeping first occurrence).
- **update(id, name, exerciseIds)**: validate; rename; replace rows: delete removed rows (queue
  `pending_deletes('template_exercises', id)`), update positions of kept rows, insert new rows.
- **delete(id)**: queue `pending_deletes('templates', id)` (children cascade), delete.
- **saveFromWorkout(workoutId, name)**: exercise ids from `workout_exercises` ordered by position,
  distinct, then `create`.
- **startWorkout(templateId)**: refuse if a workout is active (`StateError`); insert workout; add
  workout exercises for the template's existing exercises in order; set `last_used_at`; return the
  workout id.

## Sync (Phase 2 design only)

Server mirrors both tables with `user_id`; push order: custom exercises → templates →
template_exercises (after exercise_state); deletes replayed first, children before parents.
