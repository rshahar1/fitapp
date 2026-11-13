# Quickstart & Validation: Workout Templates (003)

```bash
flutter analyze
flutter test test/data/template_repository_test.dart test/data/migration_test.dart test/features/templates_test.dart
```

| # | Steps | Expected |
|---|---|---|
| V1 | Train → New → "Push", add Bench, Incline DB, OHP, Triceps → Save | "Push" listed with 4 exercises |
| V2 | Drag Triceps to top, rename "Push A" → Save | order and name persisted |
| V3 | START on "Push A" | live workout with the 4 exercises in order, prescribed from plans |
| V4 | With a workout in progress, START another template | "Workout in progress" → Continue |
| V5 | History → open a workout → ⋮ Save as template → name | template created in workout order |
| V6 | Delete a template (confirm) | gone; history unchanged |
| V7 | Name "push a" for a second template | "Name already used" |
| V8 | Upgrade from the previous APK (v1 DB) | app opens, history intact, templates empty |
