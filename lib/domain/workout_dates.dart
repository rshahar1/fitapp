/// Dates of a gym workout (feature 007): moving a workout to another day and
/// the duration of a live (possibly resumed) workout.
///
/// Pure Dart. No Flutter, database or I/O imports (constitution principle II).
library;

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

/// [startedAt] moved to the local calendar day of [day], keeping its local
/// time of day. Returns UTC. Same day → [startedAt] unchanged.
DateTime shiftToDay(DateTime startedAt, DateTime day) {
  final local = startedAt.toLocal();
  final target = _day(day);
  if (_day(local) == target) return startedAt;
  return DateTime(
    target.year,
    target.month,
    target.day,
    local.hour,
    local.minute,
    local.second,
    local.millisecond,
  ).toUtc();
}

/// Duration of a live workout: the duration before it was resumed
/// ([priorSeconds], 0 for a new workout) plus the time since it became live.
/// The live part is never negative.
Duration liveDuration({
  required int priorSeconds,
  required DateTime liveSince,
  required DateTime now,
}) {
  final live = now.difference(liveSince);
  return Duration(seconds: priorSeconds) +
      (live.isNegative ? Duration.zero : live);
}

/// Throws [ArgumentError] when the local day of [day] is after the local day
/// of [now]: workouts cannot be dated in the future.
void checkWorkoutDay(DateTime day, DateTime now) {
  if (_day(day.toLocal()).isAfter(_day(now.toLocal()))) {
    throw ArgumentError.value(day, 'day', 'is in the future');
  }
}
