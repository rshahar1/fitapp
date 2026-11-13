# Research: Log Other Sport Activities

## R1 — Type registry in code, not in the database
- **Decision**: ordered `activityTypes` list of `ActivityType(id, label)` in `lib/domain/activity_types.dart`; icons mapped by id in the UI layer. Rows store only `type_id`.
- **Rationale**: adding a sport = adding one entry (+ icon); no migration, no seed table; pure domain stays Flutter-free (constitution II/IV).
- **Alternatives**: `activity_types` table (needs seeding and sync for no gain); enum persisted by index (fragile when reordering).

## R2 — One generic table
- **Decision**: `activities(id, type_id, started_at, duration_minutes?, notes?, updated_at, dirty)`; sport-specific data later goes into separate tables keyed by activity id.
- **Rationale**: keeps v1 tiny while leaving room for deeper features (owner request).

## R3 — Stats
- **Decision**: week stats use the union of finished-workout start dates and activity dates; Total workouts stays gym-only (owner decision).
- **Rationale**: consistency/streak is about training days; Total workouts is labelled "workouts".

## R4 — History merge
- **Decision**: a merged `HistoryEntry` list built in the data layer from both sources, newest first; History keeps month grouping.

## R5 — Date entry
- **Decision**: Material `showDatePicker` limited to [first workout date − 1 year .. today]; the stored time is the current time of day on the chosen date (now for today).
