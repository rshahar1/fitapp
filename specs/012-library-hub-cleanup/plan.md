# Implementation Plan: Library deletion, hub cleanup, faster duration input

**Branch**: `012-library-hub-cleanup` | **Spec**: [spec.md](spec.md)

## Technical Context

Flutter, Riverpod, drift (SQLite), go_router. Schema 6 → 7.

## Constitution Check

- Offline-first, never drop user data: soft delete; migration only adds a nullable column. ✅
- Tests first for data/domain: repository tests before implementation; migration test v6→v7. ✅

## Design

### Data (schema v7)

- `exercises.deleted_at` (nullable DateTime). `from6To7` adds the column; `make-migrations`
  dumps `drift_schemas/fitapp/drift_schema_v7.json` and regenerates test schemas.
- `seedLibrary()` upsert does not touch `deleted_at`, so deleted built-ins stay deleted.
- `ExerciseRepository`:
  - `watchExercises` / `trainedExercises` exclude deleted rows.
  - `templatesUsing(id)` → `List<TemplateUsage(id, name, exerciseCount)>` for the confirmation.
  - `delete(id)`: one transaction — set `deleted_at`, `dirty`; for every template containing it,
    remove the template row (via `TemplateRepository.removeExercise`, which unlinks live sessions
    and queues the sync delete) and delete templates left empty.
  - `createCustom`: a name match on a deleted row restores it (clears `deleted_at`; custom rows
    get the new values); a match on an active row still throws `DuplicateExerciseName`.
  - `updateCustom` treats a deleted row as not found.
- History (`history`, workout detail) keeps reading the row, so names and sets stay.

### UI

- Library: each row gets a delete action (trailing menu with Edit/Delete for custom, Delete for
  built-in); confirmation dialog names affected templates. Title "Gym Exercise Library".
- You screen row label "Gym Exercise Library".
- Hub: drop Gym + template rows and More sports; list live sports then other sports.
  `GymChoice` removed (only the hub used it).
- Duration: new `DurationPicker` widget (lib/widgets/duration_picker.dart): big value (tap → bottom
  sheet with two `ListWheelScrollView`s, hours 0–24 and minutes 0–55 by 5), −/+ 5 min buttons,
  and a wrap of preset chips. Used by the activity sheet in place of `AppStepper`.
