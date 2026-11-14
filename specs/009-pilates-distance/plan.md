# Implementation Plan: Pilates and Manual Distance

**Branch**: `009-pilates-distance` | **Date**: 2026-11-14 | **Spec**: [spec.md](./spec.md)

## Summary

Add `pilates` to the pure-Dart activity registry (+ icon). Add a capability flag
`ActivityType.hasDistance` (true for running, cycling) and a nullable `distance_meters` column on
`activities` (schema v5, `stepByStep from4To5` → `addColumn`). Validation, repository, sheet and
History row carry the optional distance; pure helpers parse km input, format distance and derive
pace / speed.

## Technical Context

**Language/Version**: Dart 3.14, Flutter 3.50 | **Dependencies**: none added

**Storage**: drift schema v5: `activities.distance_meters INTEGER NULL`

**Testing**: domain (registry, validation, parse/format/pace/speed); repository (create/update with
distance, rejection on non-distance types); migration v4→v5; widget tests (Pilates chip, Distance
shown only for running/cycling, invalid input disables Save, History subtitle)

**Constraints**: offline; migration never drops data; kg/km-only UI

## Data model

| Column | Type | Notes |
|---|---|---|
| `distance_meters` | INTEGER NULL | 1 .. 1,000,000; only for types with `hasDistance` |

Domain additions in `lib/domain/activity_types.dart`:

- `ActivityType(id, label, {hasDistance = false})`; registry order:
  functional, cycling (distance), snowboarding, running (distance), **pilates**.
- `const maxActivityDistanceMeters = 1000000;`
- `validateActivity(..., int? distanceMeters)`: range 1..max; `ArgumentError` when the type is
  known and `!hasDistance`. `ValidActivity.distanceMeters`.
- `int? parseDistanceKm(String input)`: trims, accepts `,` or `.`, returns metres rounded to the
  nearest 10 m; null for empty / non-numeric / ≤ 0 / > max.
- `String formatDistanceKm(int meters)`: `5.2 km`, `36.75 km`, `10 km` (≤ 2 decimals, trailing
  zeros dropped).
- `String formatPace(int meters, int minutes)`: `5:23 /km` (seconds per km, rounded).
- `String formatSpeed(int meters, int minutes)`: `24.5 km/h` (one decimal).
- `String? activityMetricsLine(typeId, distanceMeters, durationMinutes)` is NOT added; the History
  row composes `distance · duration · pace|speed` (pace for running, speed for cycling).

## Constitution Check

| Principle | Status |
|---|---|
| I. Offline, versioned migration v5 (add nullable column), no data loss | ✅ |
| II. Pure domain helpers with tests first | ✅ |
| III. Tests first | ✅ |
| IV. Widgets → providers → `ActivityRepository` | ✅ |
| V. Sheet controls ≥ 48 dp, semantics on new controls | ✅ |
| VI. No secrets | ✅ |
| VII. Owner request 2026-11-14 brings manual distance for running/cycling into scope → amend VII (1.3.0). Live tracking, routes, sensors remain out of scope | ✅ (amendment) |

## Project Structure

```text
lib/domain/activity_types.dart                 # pilates, hasDistance, distance validation + helpers
lib/data/db/tables.dart                        # + distanceMeters
lib/data/db/app_database.dart                  # schemaVersion 5, from4To5
drift_schemas/fitapp/drift_schema_v5.json      # make-migrations
lib/data/repositories/activity_repository.dart # distanceMeters on create/update
lib/features/activities/activity_icons.dart    # pilates → Icons.self_improvement
lib/features/activities/activity_sheet.dart    # Distance None/Set + km field
lib/features/history/history_rows.dart         # subtitle with distance and pace/speed
```
