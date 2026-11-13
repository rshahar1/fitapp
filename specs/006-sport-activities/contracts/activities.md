# Contract: activities

```dart
// lib/domain/activity_types.dart (pure)
class ActivityType { final String id; final String label; }
const activityTypes = [functional, cycling, snowboarding, running];
ActivityType? activityTypeById(String id);
const maxActivityMinutes = 1440; const maxActivityNoteLength = 200;

// lib/data/repositories/activity_repository.dart
Future<String> create({required String typeId, required DateTime startedAt, int? durationMinutes, String? notes});
Future<void> update(String id, {required String typeId, required DateTime startedAt, int? durationMinutes, String? notes});
Future<void> delete(String id);                // queued in pending_deletes
Future<ActivityRow?> activity(String id);
Stream<List<ActivityRow>> watchActivities();   // newest first
// ArgumentError: unknown type on create, duration outside 1..1440, note > 200, startedAt in the future (local day after today)

// lib/data/models.dart
sealed class HistoryEntry { DateTime get startedAt; }
class WorkoutHistoryEntry extends HistoryEntry { final WorkoutListItem workout; }
class ActivityHistoryEntry extends HistoryEntry { final ActivityRow activity; }

// providers: activityRepositoryProvider, historyEntriesProvider (WorkoutRepository.watchHistoryEntries)
```
