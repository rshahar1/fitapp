/// Sport activities other than gym workouts (feature 006): a code-level
/// registry of activity types and the validation of a logged activity.
///
/// Pure Dart. No Flutter, database or I/O imports (constitution principle II).
/// To add a sport, add an entry to [activityTypes] (with a new stable id)
/// and an icon in `lib/features/activities/activity_icons.dart`.
library;

import 'package:meta/meta.dart';

/// One kind of activity. [id] is stored in the database and never changes.
@immutable
class ActivityType {
  const new(this.id, this.label);

  /// Stable id stored with each activity.
  final String id;

  /// Display name.
  final String label;
}

/// All activity types, in display order.
const activityTypes = [
  ActivityType('functional', 'Functional training'),
  ActivityType('cycling', 'Cycling'),
  ActivityType('snowboarding', 'Snowboarding'),
  ActivityType('running', 'Running'),
];

/// The type with [id], or null if unknown (e.g. from a newer app version).
ActivityType? activityTypeById(String id) {
  for (final t in activityTypes) {
    if (t.id == id) return t;
  }
  return null;
}

/// Display label for [typeId]; "Activity" for unknown ids.
String activityLabel(String typeId) =>
    activityTypeById(typeId)?.label ?? 'Activity';

/// Longest duration that can be logged (one day), in minutes.
const maxActivityMinutes = 1440;

/// Longest note, in characters.
const maxActivityNoteLength = 200;

/// A validated activity.
@immutable
class ValidActivity {
  const new({
    required this.typeId,
    required this.startedAt,
    this.durationMinutes,
    this.notes,
  });

  final String typeId;
  final DateTime startedAt;
  final int? durationMinutes;

  /// Trimmed; null when empty.
  final String? notes;
}

/// Validates an activity. Throws [ArgumentError] when the type is unknown
/// (unless [allowUnknownType], used when editing an entry of a retired
/// type), the local day of [startedAt] is after the local day of [now], the
/// duration is outside 1..[maxActivityMinutes], or the note is too long.
ValidActivity validateActivity({
  required String typeId,
  required DateTime startedAt,
  required DateTime now,
  int? durationMinutes,
  String? notes,
  bool allowUnknownType = false,
}) {
  if (!allowUnknownType && activityTypeById(typeId) == null) {
    throw ArgumentError.value(typeId, 'typeId', 'unknown activity type');
  }
  final day = _day(startedAt.toLocal());
  if (day.isAfter(_day(now.toLocal()))) {
    throw ArgumentError.value(startedAt, 'startedAt', 'is in the future');
  }
  final d = durationMinutes;
  if (d != null && (d < 1 || d > maxActivityMinutes)) {
    throw ArgumentError.value(d, 'durationMinutes', '1..$maxActivityMinutes');
  }
  final clean = notes?.trim();
  if (clean != null && clean.length > maxActivityNoteLength) {
    throw ArgumentError.value(
      clean.length,
      'notes',
      'max $maxActivityNoteLength characters',
    );
  }
  return ValidActivity(
    typeId: typeId,
    startedAt: startedAt,
    durationMinutes: d,
    notes: clean == null || clean.isEmpty ? null : clean,
  );
}

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);
