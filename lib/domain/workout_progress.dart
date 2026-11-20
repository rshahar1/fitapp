/// Where a live workout resumes (feature 023). Pure Dart.
library;

/// The logged set numbers of one exercise in a workout and its planned set
/// count (null without a plan).
class ExerciseProgress {
  const new({required this.loggedSetNos, this.plannedSets});

  final Set<int> loggedSetNos;
  final int? plannedSets;

  /// Every planned set (1..[plannedSets]) is logged. Never true without a
  /// plan.
  bool get isComplete {
    final planned = plannedSets;
    if (planned == null || planned <= 0) return false;
    for (var n = 1; n <= planned; n++) {
      if (!loggedSetNos.contains(n)) return false;
    }
    return true;
  }
}

/// Index of the exercise a reopened live workout should show: the last
/// exercise with logged sets, or the one after it when it is complete. Null
/// when nothing is logged (stay at the top).
int? resumeExerciseIndex(List<ExerciseProgress> exercises) {
  for (var i = exercises.length - 1; i >= 0; i--) {
    final e = exercises[i];
    if (e.loggedSetNos.isEmpty) continue;
    return e.isComplete && i < exercises.length - 1 ? i + 1 : i;
  }
  return null;
}
