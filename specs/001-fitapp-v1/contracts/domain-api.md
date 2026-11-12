# Contract: Domain API (pure Dart, `lib/domain/`)

No imports from `package:flutter`, drift, or I/O. All functions are deterministic; "now" is passed in.

## progression.dart

```dart
double roundWeight(double kg);                 // (kg * 4).round() / 4 ; 0.1+0.2+22.2 → 22.5

class Plan {                                   // throws ArgumentError if invalid
  const Plan({required double baseWeight, required int targetReps,
              required int targetSets, required double increment});
  // validate(): targetSets >= 2, targetReps >= 1, increment > 0, baseWeight >= 0
}

class PrescribedSet { int setNo; double weight; int reps; bool isOverload; }
class LoggedSet     { int setNo; double weight; int reps; }

List<PrescribedSet> prescribe(Plan plan);
// sets 1..N-1: base ; set N: roundWeight(base + increment), isOverload = true

enum EvalReason { incomplete, missedReps, noOverloadSet, overloadNotHeavier, progressed }
// string forms: incomplete, missed_reps, no_overload_set, overload_not_heavier, progressed

class Evaluation { bool progressed; double nextBaseWeight; EvalReason reason; }

Evaluation evaluate(Plan plan, Iterable<LoggedSet> sets);
// keyed by setNo, order-independent; extra sets (> N) ignored; checks in order:
// 1 any working set missing            → incomplete,        next = base
// 2 any working reps < target or w < base → missed_reps,    next = base
// 3 set N missing                      → no_overload_set,   next = base
// 4 set N weight <= base               → overload_not_heavier, next = base
// 5 else                               → progressed,        next = roundWeight(set N weight)

bool canRewriteBase({required bool isLatestSessionForExercise,
                     required double currentBase,
                     required double? resultBaseWeight});
// true iff isLatest && resultBaseWeight != null
//        && roundWeight(currentBase) == roundWeight(resultBaseWeight)
```

## stats.dart

```dart
double volume(Iterable<LoggedSet> sets, {required bool perHand}); // Σ w×r, ×2 if perHand
double epley1RM(double weight, int reps); // reps==0 → 0; reps==1 → w; else round1(w*(1+reps/30))

enum PrType { heaviestWeight, best1RM, bestSetVolume }
class PersonalRecords { double heaviestWeight; double best1RM; double bestSetVolume; }
PersonalRecords personalRecords(Iterable<LoggedSet> history, {required bool perHand});
Set<PrType> newPRTypes(LoggedSet candidate, PersonalRecords prior, {required bool perHand});
// strictly greater than prior values

class SessionSummary { int sets; int reps; double volume; double topWeight;
                       double workingWeight; double best1RM; }
SessionSummary summarizeSession(Iterable<LoggedSet> sets, {required bool perHand,
                                int? overloadSetNo});
// workingWeight = heaviest set whose setNo != overloadSetNo

enum Trend { up, down, same }
class MetricDelta { Trend trend; double? percent; }   // percent null when previous == 0
class SummaryDiff { MetricDelta sets, reps, volume, topWeight; }
SummaryDiff? diffSummary(SessionSummary current, SessionSummary? previous); // null → "First session"

String isoWeekKey(DateTime localDate);   // 2026-11-09 → "2026-W46"; 2027-01-01 → "2026-W53"
Map<String, int> workoutsPerWeek(Iterable<DateTime> workoutDates, {required DateTime now,
                                 int weeks = 8});   // ordered oldest → current, zero-filled
int weeklyStreak(Iterable<DateTime> workoutDates, {required DateTime now});
// consecutive ISO weeks with ≥1 workout ending at this week or last week;
// an empty current week does not break the streak; spans year boundaries
```

## Test obligations (PRD §12, domain)

- `prescribe`: 3-set, 4-set, +5 variant; each invalid plan field throws.
- `evaluate`: progressed; exceeding target reps; missed reps on set 2; reps hit at lighter weight;
  heavier-than-prescribed overload; overload missing; overload not heavier; working set missing;
  order independence; extra sets ignored.
- `roundWeight`: float drift case.
- `canRewriteBase`: latest & matching → true; edited since / not latest / never applied → false.
- Stats: per-hand volume; Epley 100×10 → 133.3, ×1 → 100, ×0 → 0; PRs and `newPRTypes`; summary and
  diff incl. first session; ISO keys incl. W53; weekly counts; streak with in-progress week, with a
  gap, across year boundary.
- 100% line coverage of `progression.dart`.
