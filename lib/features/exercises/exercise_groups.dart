import 'package:fitapp/core/format.dart';
import 'package:fitapp/data/db/app_database.dart';
import 'package:fitapp/data/db/seed_library.dart';

/// Header for exercises without a category.
const customGroup = 'Custom';

/// Groups [list] by category in library order (Chest, Back, Legs, Shoulders,
/// Arms, then Custom); empty categories are omitted.
List<(String, List<ExerciseRow>)> groupExercises(List<ExerciseRow> list) {
  final grouped = <String, List<ExerciseRow>>{};
  for (final e in list) {
    (grouped[e.muscleGroup ?? customGroup] ??= []).add(e);
  }
  final order = [
    ...muscleGroups.where(grouped.containsKey),
    ...grouped.keys.where((g) => !muscleGroups.contains(g)),
  ];
  return [for (final g in order) (g, grouped[g]!)];
}

/// Row subtitle: "per hand · +2.5 kg" or "+2.5 kg".
String exerciseSubtitle(ExerciseRow e) {
  final inc = '+${formatKg(e.defaultIncrement)}';
  return e.isPerHand ? 'per hand · $inc' : inc;
}
