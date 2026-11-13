# Data Model: schema v4

## New table `activities`

| Column | Type | Notes |
|---|---|---|
| `id` | TEXT PK | UUID v4 |
| `type_id` | TEXT | id from the code registry (`functional`, `cycling`, `snowboarding`, `running`); not a FK so new or retired types never break rows |
| `started_at` | DATETIME (ISO-8601 UTC text) | chosen day + time of logging; never in the future |
| `duration_minutes` | INTEGER NULL | 1–1440 |
| `notes` | TEXT NULL | trimmed, ≤ 200 chars, empty → NULL |
| `updated_at` | DATETIME | sync |
| `dirty` | BOOLEAN default true | sync |

Index: `activities_started_at ON activities (started_at)`. Deletes are queued in `pending_deletes`
(`table_name = 'activities'`).

## Migration v3 → v4

`stepByStep.from3To4`: `createTable(schema.activities)`; index created by `_createIndexes` when the
target version ≥ 4. No existing table changes.

## Code-level registry (not stored)

`ActivityType { String id; String label; }` in `lib/domain/activity_types.dart`, ordered list
`activityTypes`; `activityTypeById(id) → ActivityType?`. Icons live in the UI layer
(`lib/features/activities/activity_icons.dart`): `fitness_center` for gym workouts,
`sports_gymnastics` (functional), `directions_bike` (cycling), `snowboarding`, `directions_run`,
`sports` for unknown ids.

## Derived

`HistoryEntry` = `WorkoutHistoryEntry(WorkoutListItem)` | `ActivityHistoryEntry(ActivityRow)`,
sorted by start time desc, then id.
Week stats: `dates = finished workout start dates ∪ activity start dates` for This week, streak and
weekly bars; Total workouts = finished workouts only.
