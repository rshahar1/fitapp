# Research: Workout Templates (003)

## R1. Storage and migration
- **Decision**: two drift tables (`templates`, `template_exercises`), schema v2 with
  `onUpgrade: from < 2 → createTable(templates), createTable(templateExercises), create name index`.
  Migration verified with drift's `make-migrations` tooling (schema dumps in `drift_schemas/`,
  generated test helpers in `test/drift/`).
- **Rationale**: relational like the rest of the data; cascade delete; sync-ready columns.
- **Alternatives**: JSON list of exercise ids in one column (simpler but no FK integrity, awkward
  for sync conflict resolution).

## R2. Editing semantics
- **Decision**: the editor keeps a local draft (name + ordered ids) and saves on "Save" via one
  `update` transaction that diffs rows. Removing an exercise in the editor needs no confirmation;
  deleting the template does.
- **Rationale**: avoids partial states while dragging; one write per save.

## R3. Starting a workout
- **Decision**: `TemplateRepository.startWorkout` reuses the same row shapes as
  `WorkoutRepository.startWorkout/addExercise` inside one transaction, so the result is identical
  to a manually built workout (FR-008, SC-005).

## R4. Reorder UI
- **Decision**: Flutter's built-in `ReorderableListView` with explicit drag handles
  (`ReorderableDragStartListener`) — no package.

## R5. Picker reuse
- **Decision**: refactor `ExercisePickerScreen` into a selection widget with two modes: *add to
  workout* (existing behaviour) and *select* (returns the id). Avoids a second picker.
