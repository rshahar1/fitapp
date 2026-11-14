import 'package:material_ui/material_ui.dart';

/// Icon of a gym workout in lists.
const gymWorkoutIcon = Icons.fitness_center;

/// Icon for an activity type; a generic one for unknown ids.
IconData activityIcon(String typeId) => switch (typeId) {
  'functional' => Icons.sports_gymnastics,
  'cycling' => Icons.directions_bike,
  'snowboarding' => Icons.snowboarding,
  'running' => Icons.directions_run,
  'pilates' => Icons.self_improvement,
  _ => Icons.sports,
};
