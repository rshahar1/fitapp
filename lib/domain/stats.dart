/// Workout statistics: volume, estimated 1RM, personal records, session
/// summaries and weekly aggregates.
///
/// Pure Dart. No Flutter, database or I/O imports (constitution principle II).
library;

import 'dart:math' as math;

import 'package:fitapp/domain/calendar.dart';
import 'package:fitapp/domain/progression.dart';

double _round1(double x) => (x * 10).round() / 10;

/// Total volume: sum of weight x reps, doubled for per-hand exercises.
double volume(Iterable<LoggedSet> sets, {required bool perHand}) {
  final total = sets.fold<double>(0, (sum, s) => sum + s.weight * s.reps);
  return perHand ? total * 2 : total;
}

/// Volume of a single set.
double setVolume(LoggedSet set, {required bool perHand}) =>
    set.weight * set.reps * (perHand ? 2 : 1);

/// Estimated one-rep max (Epley), rounded to 0.1. 0 reps gives 0, 1 rep gives
/// the weight itself.
double epley1RM(double weight, int reps) {
  if (reps <= 0) return 0;
  if (reps == 1) return weight;
  return _round1(weight * (1 + reps / 30));
}

/// Kinds of personal record.
enum PrType {
  /// Heaviest weight lifted in one set.
  heaviestWeight,

  /// Best estimated 1RM.
  best1RM,

  /// Best single-set volume.
  bestSetVolume,
}

/// Best values across a history of sets.
class PersonalRecords {
  /// Creates records.
  const new({
    this.heaviestWeight = 0,
    this.best1RM = 0,
    this.bestSetVolume = 0,
  });

  /// Heaviest weight (kg).
  final double heaviestWeight;

  /// Best estimated 1RM (kg).
  final double best1RM;

  /// Best single-set volume (kg).
  final double bestSetVolume;

  /// No history.
  static const empty = PersonalRecords();
}

/// Computes personal records from all [history] sets.
PersonalRecords personalRecords(
  Iterable<LoggedSet> history, {
  required bool perHand,
}) {
  var heaviest = 0.0;
  var best1RM = 0.0;
  var bestVolume = 0.0;
  for (final s in history) {
    heaviest = math.max(heaviest, s.weight);
    best1RM = math.max(best1RM, epley1RM(s.weight, s.reps));
    bestVolume = math.max(bestVolume, setVolume(s, perHand: perHand));
  }
  return PersonalRecords(
    heaviestWeight: heaviest,
    best1RM: best1RM,
    bestSetVolume: bestVolume,
  );
}

/// Which record types [candidate] beats (strictly greater than [prior]).
Set<PrType> newPRTypes(
  LoggedSet candidate,
  PersonalRecords prior, {
  required bool perHand,
}) {
  if (candidate.reps <= 0) return const {};
  return {
    if (candidate.weight > prior.heaviestWeight) PrType.heaviestWeight,
    if (epley1RM(candidate.weight, candidate.reps) > prior.best1RM)
      PrType.best1RM,
    if (setVolume(candidate, perHand: perHand) > prior.bestSetVolume)
      PrType.bestSetVolume,
  };
}

/// Summary of one session of one exercise.
class SessionSummary {
  /// Creates a summary.
  const new({
    required this.sets,
    required this.reps,
    required this.volume,
    required this.topWeight,
    required this.workingWeight,
    required this.best1RM,
  });

  /// Number of logged sets.
  final int sets;

  /// Total reps.
  final int reps;

  /// Total volume (kg).
  final double volume;

  /// Heaviest set weight.
  final double topWeight;

  /// Heaviest non-overload set weight (0 if none).
  final double workingWeight;

  /// Best estimated 1RM of the session.
  final double best1RM;
}

/// Summarizes [sets]. Sets numbered [overloadSetNo] are excluded from
/// [SessionSummary.workingWeight].
SessionSummary summarizeSession(
  Iterable<LoggedSet> sets, {
  required bool perHand,
  int? overloadSetNo,
}) {
  final list = sets.toList();
  var top = 0.0;
  var working = 0.0;
  var best = 0.0;
  var reps = 0;
  for (final s in list) {
    reps += s.reps;
    top = math.max(top, s.weight);
    best = math.max(best, epley1RM(s.weight, s.reps));
    if (s.setNo != overloadSetNo) working = math.max(working, s.weight);
  }
  return SessionSummary(
    sets: list.length,
    reps: reps,
    volume: volume(list, perHand: perHand),
    topWeight: top,
    workingWeight: working,
    best1RM: best,
  );
}

/// Direction of change.
enum Trend {
  /// Increased.
  up,

  /// Decreased.
  down,

  /// Unchanged.
  same,
}

/// Change of one metric versus the previous session.
class MetricDelta {
  /// Creates a delta.
  const new(this.trend, this.percent);

  /// Computes the delta from [previous] to [current].
  factory of(num current, num previous) {
    const eps = 1e-9;
    final diff = current - previous;
    final trend = diff > eps
        ? Trend.up
        : diff < -eps
        ? Trend.down
        : Trend.same;
    final percent = previous.abs() < eps
        ? null
        : _round1(diff / previous * 100);
    return MetricDelta(trend, percent);
  }

  /// Direction.
  final Trend trend;

  /// Percentage change rounded to 0.1, or null when previous was 0.
  final double? percent;
}

/// Comparison of a session with the previous one.
class SummaryDiff {
  /// Creates a diff.
  const new({
    required this.sets,
    required this.reps,
    required this.volume,
    required this.topWeight,
  });

  /// Set count change.
  final MetricDelta sets;

  /// Rep count change.
  final MetricDelta reps;

  /// Volume change.
  final MetricDelta volume;

  /// Top weight change.
  final MetricDelta topWeight;
}

/// Compares [current] with [previous]. Returns null when there is no previous
/// session ("First session").
SummaryDiff? diffSummary(SessionSummary current, SessionSummary? previous) {
  if (previous == null) return null;
  return SummaryDiff(
    sets: MetricDelta.of(current.sets, previous.sets),
    reps: MetricDelta.of(current.reps, previous.reps),
    volume: MetricDelta.of(current.volume, previous.volume),
    topWeight: MetricDelta.of(current.topWeight, previous.topWeight),
  );
}

// ---------------------------------------------------------------------------
// Weeks run Sunday to Saturday on local calendar days (features 025, 026),
// the same weeks as the History calendar ([startOfWeek]).
// ---------------------------------------------------------------------------

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// Workouts per Sunday-to-Saturday week for the last [weeks] weeks ending
/// with the week of [now], keyed by each week's Sunday (date only), oldest
/// first, zero-filled.
Map<DateTime, int> workoutsPerWeek(
  Iterable<DateTime> workoutDates, {
  required DateTime now,
  int weeks = 8,
}) {
  final current = startOfWeek(now);
  final result = <DateTime, int>{
    for (var i = weeks - 1; i >= 0; i--)
      DateTime(current.year, current.month, current.day - 7 * i): 0,
  };
  for (final d in workoutDates) {
    final key = startOfWeek(d);
    if (result.containsKey(key)) result[key] = result[key]! + 1;
  }
  return result;
}

/// Bar labels for week starts: the day of month, with the short month name
/// on the first bar and whenever the month changes (`18 Oct`, `25`, `1 Nov`).
List<String> weekBarLabels(List<DateTime> sundays) => [
  for (var i = 0; i < sundays.length; i++)
    if (i == 0 || sundays[i].month != sundays[i - 1].month)
      '${sundays[i].day} ${_months[sundays[i].month - 1]}'
    else
      '${sundays[i].day}',
];

/// Number of consecutive Sunday-to-Saturday weeks (local calendar days,
/// feature 025) with at least one workout, ending with the week of [now] or
/// the week before. An empty current week does not break the streak.
int weeklyStreak(Iterable<DateTime> workoutDates, {required DateTime now}) {
  final weeksWithWorkouts = {for (final d in workoutDates) startOfWeek(d)};
  DateTime previous(DateTime sunday) =>
      DateTime(sunday.year, sunday.month, sunday.day - 7);
  var sunday = startOfWeek(now);
  if (!weeksWithWorkouts.contains(sunday)) sunday = previous(sunday);
  var streak = 0;
  while (weeksWithWorkouts.contains(sunday)) {
    streak++;
    sunday = previous(sunday);
  }
  return streak;
}
