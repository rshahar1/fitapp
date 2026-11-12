# Data Model: FitApp v1

Source: PRD §7. Local drift (SQLite) database, `schemaVersion = 1`, foreign keys ON. All ids are
UUID v4 text generated on the client; timestamps are UTC ISO-8601 text. Weights are `REAL` kg,
always stored after `roundWeight` (nearest 0.25). Syncable tables carry `updated_at` and `dirty`
(1 = changed locally) for Phase 2; v1 sets `dirty = 1` on every write and never clears it.

## Tables

### exercises
| Column | Type | Rules |
|---|---|---|
| id | TEXT PK | seed: `00000000-0000-4000-8000-%012x` (1…16); custom: UUID v4 |
| name | TEXT NOT NULL | unique case-insensitive (`UNIQUE` on `lower(name)` index) |
| muscle_group | TEXT NULL | Chest, Legs, Back, Shoulders, Arms, or NULL for custom |
| is_per_hand | BOOL NOT NULL | volume ×2 when true |
| default_increment | REAL NOT NULL | > 0 |
| is_custom | BOOL NOT NULL | false for seed rows |
| updated_at | DATETIME NOT NULL | |
| dirty | BOOL NOT NULL default 1 | seed rows set 0 (never pushed) |

Seeding (PRD §5.1 table) is an upsert on every app start: inserts missing rows and refreshes name,
muscle group, per-hand flag and default increment of seed rows; never touches custom rows.

### exercise_state (the plan)
| Column | Type | Rules |
|---|---|---|
| exercise_id | TEXT PK → exercises.id | one plan per exercise |
| base_weight | REAL NOT NULL | ≥ 0, rounded |
| target_reps | INT NOT NULL | ≥ 1 |
| target_sets | INT NOT NULL | ≥ 2 |
| increment | REAL NOT NULL | > 0 (chips: 1, 2, 2.5, 5) |
| rest_seconds | INT NULL | NULL = use default; else 10…600 |
| updated_at, dirty | | |

### workouts
| Column | Type | Rules |
|---|---|---|
| id | TEXT PK | |
| name | TEXT NULL | |
| started_at | DATETIME NOT NULL | |
| ended_at | DATETIME NULL | NULL = in progress; at most one row with NULL |
| notes | TEXT NULL | |
| updated_at, dirty | | |

### workout_exercises
| Column | Type | Rules |
|---|---|---|
| id | TEXT PK | |
| workout_id | TEXT → workouts.id ON DELETE CASCADE | |
| exercise_id | TEXT → exercises.id | |
| position | INT NOT NULL | display order, 0-based |
| notes | TEXT NULL | SHOULD |
| plan_base_weight, plan_target_reps, plan_target_sets, plan_increment | NULL | snapshot written on finish |
| result_base_weight | REAL NULL | snapshot result; cleared on resume |
| updated_at, dirty | | |

### sets
| Column | Type | Rules |
|---|---|---|
| id | TEXT PK | new id on every re-log after a clear |
| workout_exercise_id | TEXT → workout_exercises.id ON DELETE CASCADE | |
| set_no | INT NOT NULL | 1-based; `UNIQUE(workout_exercise_id, set_no)` |
| weight | REAL NOT NULL | ≥ 0, rounded |
| reps | INT NOT NULL | ≥ 0 |
| is_overload | BOOL NOT NULL | true iff set_no == plan target_sets |
| completed_at | DATETIME NOT NULL | |
| updated_at, dirty | | |

Re-logging an existing `set_no` is an upsert on the unique key (overwrite, no duplicates).
There is **no** `set_type` column (constitution VII).

### pending_deletes
| Column | Type | Rules |
|---|---|---|
| table_name | TEXT | PK part |
| row_id | TEXT | PK part |

v1 inserts a row for each deleted workout (and cleared set / removed workout exercise) so Phase 2
can replay them. Never read in v1.

### settings (local only)
| key | value (TEXT) | default |
|---|---|---|
| default_rest_seconds | int | 60 (range 10…600, 5 s steps) |
| rest_alert_haptic | bool | true |
| rest_alert_sound | bool | true |
| active_rest_started_at | ISO UTC | absent when no timer |
| active_rest_target_seconds | int | absent when no timer |

## Indexes

- `workouts(ended_at)` for history and "latest finished" lookups.
- `workout_exercises(exercise_id, workout_id)` for previous-session and latest-session lookups.
- `sets(workout_exercise_id)` (covered by the unique key).
- `exercises(lower(name))` unique.

## Derived values (not stored)

- **Prescription** from plan (domain `prescribe`).
- **Volume**, **Est. 1RM**, **PRs**, **session summary/diff**, **weekly counts**, **streak** (domain
  `stats`).
- **Latest finished session for an exercise**: the workout with max `ended_at` (ties: max
  `started_at`, then id) among finished workouts containing that exercise.
- **Most recent finished workout overall**: max `ended_at` among finished workouts.

## State transitions

### Workout
```
            start()                finish() [≥1 set logged]
 (none) ───────────────▶ ACTIVE ─────────────────────────▶ FINISHED
                           │  finish() [0 sets] → discard()   │   │
                           ▼                                  │   │ delete()
                       (deleted)   ◀──────────────────────────┘   ▼
                                       resume() [most recent      (deleted)
                       ACTIVE ◀─────── finished & no ACTIVE]
```
- `start`: only when no ACTIVE workout exists.
- `finish`: transaction — for each workout exercise with a plan and ≥ 1 set: snapshot, evaluate,
  conditionally raise current base; set `ended_at`.
- `resume`: transaction — for each workout exercise with a snapshot: if `canRewriteBase` restore
  `plan_base_weight` to current base; clear `result_base_weight`; `ended_at = NULL`.
- `delete`: transaction — undo progression where `canRewriteBase`, queue pending delete, cascade.
- `edit` (FINISHED): each change saves immediately, then `recalculate(workoutExerciseId)`.

### Set
`not logged` → `logged` (log / one-tap) → `logged` (overwrite) → `not logged` (clear).

## Validation summary

- Plan: sets ≥ 2, reps ≥ 1, increment > 0, base ≥ 0 → otherwise `ArgumentError` from domain and a
  user-facing message in UI.
- Custom exercise: non-empty trimmed name, unique case-insensitive, increment > 0.
- Settings: default rest clamped to 10…600 and snapped to 5 s.
