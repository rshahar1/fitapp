# Implementation Plan: 020-history-readonly-rest

No schema change (settings are key/value rows); no domain change.

- `SettingsRepository`: `defaultRestBetweenExercisesSeconds = 120`, key
  `rest_between_exercises_seconds`, `watchRestBetweenExercisesSeconds()`,
  `restBetweenExercises()`, `setRestBetweenExercisesSeconds()` (normalized, stamped for sync);
  included in `syncedSettings`/`applySyncedSettings`; `DeviceBinding` wipes it.
- `restBetweenExercisesProvider` (StreamProvider) in `providers.dart`.
- Settings screen: second stepper + presets under "Rest timer".
- `RestTimerController.startFor(..., betweenExercises: bool)` picks the global between-exercises
  time when true.
- `ExerciseCard._log`: `betweenExercises` = all planned set numbers logged after this set and this
  set is >= the planned count.
- `WorkoutScreen`: `_WorkoutView` becomes stateful with `_editing`; finished && !editing → read-only.
  `ExerciseCard(readOnly:)` hides options menu, Add Set, notes editor (shows notes text) and makes
  set rows inert; `SetRowView` callbacks become nullable.
