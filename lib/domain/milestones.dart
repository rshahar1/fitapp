/// In-workout milestones that earn a reward.
///
/// Pure Dart. No Flutter, database or I/O imports (constitution principle II).
library;

/// Whether sets 1 and 2 were both logged with at least [targetReps] reps.
///
/// False when there is no plan (no target) or either set is not logged yet.
bool firstTwoSetsHitTarget({int? targetReps, int? set1Reps, int? set2Reps}) =>
    targetReps != null &&
    set1Reps != null &&
    set2Reps != null &&
    set1Reps >= targetReps &&
    set2Reps >= targetReps;
