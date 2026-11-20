/// Train screen statistics per training type (feature 025): gym workouts and
/// each activity type, counted for the current Sunday-to-Saturday week and
/// all time.
///
/// Pure Dart. No Flutter, database or I/O imports (constitution principle II).
library;

import 'package:fitapp/domain/activity_types.dart';
import 'package:fitapp/domain/calendar.dart';
import 'package:meta/meta.dart';

/// Type id of a finished gym workout (activity ids never use it).
const gymTypeId = 'gym';

/// Type id that groups activities whose id this app version does not know.
const unknownActivityTypeId = 'activity';

/// One finished training session: its type id and local start time.
@immutable
class TrainingSession {
  const new(this.typeId, this.startedAt);

  /// [gymTypeId] or an activity type id.
  final String typeId;

  /// Local start time.
  final DateTime startedAt;
}

/// Session counts of one training type.
@immutable
class TypeCount {
  const new(this.typeId, {required this.thisWeek, required this.allTime});

  /// [gymTypeId], a known activity id or [unknownActivityTypeId].
  final String typeId;

  /// Sessions in the current Sunday-to-Saturday week.
  final int thisWeek;

  /// Sessions ever.
  final int allTime;
}

/// Whether [a] and [b] fall in the same Sunday-to-Saturday week (local
/// calendar days).
bool isSameWeek(DateTime a, DateTime b) => startOfWeek(a) == startOfWeek(b);

/// Whether [a] and [b] fall in the same local calendar month (feature 028).
bool isSameMonth(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month;

/// The types of [breakdown] with at least one session this week, in order
/// (Train's *By type* list, feature 028).
List<TypeCount> activeTypes(List<TypeCount> breakdown) => [
  for (final t in breakdown)
    if (t.thisWeek > 0) t,
];

/// Display label of a training type: "Gym", the activity label, or
/// "Activity" for unknown ids.
String trainingTypeLabel(String typeId) =>
    typeId == gymTypeId ? 'Gym' : activityLabel(typeId);

/// Counts per type of the types present in [sessions], ordered by this-week
/// count, then all-time count (both descending), then gym first and the
/// activity registry order (unknown last).
List<TypeCount> trainingBreakdown(
  Iterable<TrainingSession> sessions, {
  required DateTime now,
}) {
  final week = <String, int>{};
  final all = <String, int>{};
  for (final s in sessions) {
    final id = s.typeId == gymTypeId || activityTypeById(s.typeId) != null
        ? s.typeId
        : unknownActivityTypeId;
    all[id] = (all[id] ?? 0) + 1;
    if (isSameWeek(s.startedAt, now)) week[id] = (week[id] ?? 0) + 1;
  }
  int rank(String id) => switch (id) {
    gymTypeId => -1,
    unknownActivityTypeId => activityTypes.length,
    _ => activityTypes.indexWhere((t) => t.id == id),
  };
  final result = [
    for (final id in all.keys)
      TypeCount(id, thisWeek: week[id] ?? 0, allTime: all[id]!),
  ];
  return result..sort((a, b) {
    final byWeek = b.thisWeek.compareTo(a.thisWeek);
    if (byWeek != 0) return byWeek;
    final byAll = b.allTime.compareTo(a.allTime);
    return byAll != 0 ? byAll : rank(a.typeId).compareTo(rank(b.typeId));
  });
}
