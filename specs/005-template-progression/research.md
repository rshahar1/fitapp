# Research: Templates That Carry Their Own Progression

## R1 — Evaluation rule

- **Decision**: progressed ⇔ all working sets 1..N−1 logged, each `reps ≥ target` and
  `roundWeight(weight) ≥ base`; `nextBase = roundWeight(base + increment)`. Reasons:
  `incomplete` (checked first), `missed_reps`, `progressed`.
- **Rationale**: owner decision 2026-11-13; the overload set is a "power" attempt that never gates.
- **Alternatives**: keep "jump to heavier overload weight" (rejected by owner: keep simple); keep the
  old rule for ad-hoc workouts (rejected: one rule everywhere).

## R2 — Where template plans are stored

- **Decision**: nullable plan columns (`base_weight`, `target_reps`, `target_sets`, `increment`,
  `rest_seconds`) on `template_exercises`; all four core values are set together or all NULL.
- **Rationale**: one plan per template exercise, same lifecycle (deleted with the row, synced with
  the row); no join table.
- **Alternatives**: separate `template_plans` table (extra join, no benefit); JSON column (not
  queryable, breaks validation symmetry).

## R3 — Linking a session to its template plan

- **Decision**: `workout_exercises.template_exercise_id TEXT NULL`, **no foreign key**, indexed.
  Plan source resolution per workout exercise:
  - `NULL` → **exercise plan** (`exercise_state`), latest-session check over sessions with NULL link;
  - id of an existing template exercise → **template plan**, latest-session check over sessions with
    the same link;
  - id of a deleted template exercise → **orphan**: never rewrites any plan.
- **Rationale**: with an FK `ON DELETE SET NULL` a deleted template's sessions would silently turn
  into ad-hoc sessions and could rewrite the exercise plan when the bases coincide. A dangling id is
  explicit and sync-friendly (rows are deleted independently).
- **Unlink rule**: when a template or a template exercise is deleted, workout exercises of
  **unfinished** workouts that still have **no snapshot** are unlinked (become ad hoc) so a live
  workout keeps working; everything else keeps the dangling link.
- **Alternatives**: `workouts.template_id` (cannot tell which exercises were added ad hoc).

## R4 — History safety per plan

- **Decision**: `canRewriteBase` logic unchanged; the "latest session" is computed per plan source
  (latest finished workout by `started_at`, `id` among sessions of that source). Its named flag is
  renamed `isLatestSessionForPlan`.
- **Rationale**: PRD §4.4 semantics hold within each plan; plans never interfere.

## R5 — Seeding template plans

- **Decision**: new template rows copy the plan that exercise uses in context: create/edit → the
  editor's draft plan (pre-filled from the exercise plan); save-from-workout → the plan the session
  is using (template plan if linked, otherwise exercise plan); migration → `exercise_state`.
  Re-adding a removed exercise seeds again (old progress not restored).

## R6 — Old sessions and the new rule

- **Decision**: edits of finished sessions re-evaluate with the new rule against their snapshot;
  `canRewriteBase` keeps the current base safe. No data back-fill.

## R7 — "Previous" column

- **Decision**: unchanged — previous session of the same exercise (any source). Keeps the feature
  focused; the prescription already reflects the template plan.

## R8 — PlanForm

- **Decision**: `PlanForm` takes `initial: StoredPlan?` and `onSubmit: Future<void> Function(StoredPlan)`
  so the same form saves an exercise plan, a template plan via a workout, or a template-editor draft.
