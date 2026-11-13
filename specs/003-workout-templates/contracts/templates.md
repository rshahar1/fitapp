# Contract: Templates (repository + UI)

## TemplateRepository (`lib/data/repositories/template_repository.dart`)

```dart
class TemplateSummary {                // read model
  final String id;
  final String name;
  final List<ExerciseRow> exercises;   // ordered; missing exercises skipped
  final DateTime createdAt;
  final DateTime? lastUsedAt;
}

class DuplicateTemplateName implements Exception { final String name; }

Stream<List<TemplateSummary>> watchTemplates();          // ordered per data-model.md
Future<TemplateSummary?> template(String id);
Future<String> create({required String name, required List<String> exerciseIds});   // returns id
Future<void> update(String id, {required String name, required List<String> exerciseIds});
Future<void> delete(String id);
Future<String> saveFromWorkout(String workoutId, {required String name});
Future<String> startWorkout(String templateId);          // returns new workout id
```

Validation errors: `ArgumentError` ("Name is required", "Name is too long (max 40)",
"Add at least one exercise"); `DuplicateTemplateName`; `StateError` when a workout is in progress.

## Routes

| Route | Screen |
|---|---|
| `/template/new` | Template editor (create) |
| `/template/:id` | Template editor (edit, with Delete in the app bar menu) |
| `/pick-exercise` | Exercise picker in *selection* mode: returns the chosen exercise id via `pop(id)` (reuses the existing picker UI incl. search and custom exercises) |

## Train tab

Section "Templates" (between the hero card and stats or below the hero): each template is a card
row — name (titleMedium), exercise names joined with " · " (2 lines max), a pill **START** button
(48 dp), and the row body opens the editor. Header action "New" opens `/template/new`. Empty state:
"Create a template to start a routine in one tap." When a workout is active, START shows a dialog
"Workout in progress" with **Continue workout** / Cancel.

## Template editor

App bar: title "New template" / "Edit template", Save action. Body: name TextField (max 40,
counter), reorderable list of exercises (drag handle, remove ✕ with 48 dp targets, semantics
"Move <name>" / "Remove <name>"), "Add exercise" button → `/pick-exercise`. Save validates and pops.
Delete (edit mode, menu) asks for confirmation. Unsaved changes on back → "Discard changes?" dialog.

## Save as template

Workout screen app bar gains a ⋮ menu with "Save as template" (live and edit mode; hidden when the
workout has no exercises) → dialog with a name field prefilled "Workout <d MMM>" → `saveFromWorkout`
→ SnackBar "Template saved".
