import 'package:fitapp/data/db/app_database.dart';
import 'package:fitapp/data/models.dart';
import 'package:fitapp/data/repositories/exercise_repository.dart';
import 'package:fitapp/data/repositories/settings_repository.dart';
import 'package:fitapp/data/repositories/workout_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Wall clock, overridable in tests.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// The database. Overridden in main() with the opened instance and in tests
/// with an in-memory one.
final databaseProvider = Provider<AppDatabase>(
  (ref) => throw UnimplementedError('databaseProvider must be overridden'),
);

final workoutRepositoryProvider = Provider<WorkoutRepository>(
  (ref) => WorkoutRepository(ref.watch(databaseProvider)),
);

final exerciseRepositoryProvider = Provider<ExerciseRepository>(
  (ref) => ExerciseRepository(ref.watch(databaseProvider)),
);

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepository(ref.watch(databaseProvider)),
);

// --- Read models -------------------------------------------------------------

final activeWorkoutProvider = StreamProvider<WorkoutRow?>(
  (ref) => ref.watch(workoutRepositoryProvider).watchActiveWorkout(),
);

final workoutDetailProvider = StreamProvider.family<WorkoutDetail?, String>(
  (ref, id) => ref.watch(workoutRepositoryProvider).watchWorkout(id),
);

final historyProvider = StreamProvider<List<WorkoutListItem>>(
  (ref) => ref.watch(workoutRepositoryProvider).watchHistory(),
);

final homeStatsProvider = StreamProvider<HomeStats>(
  (ref) => ref
      .watch(workoutRepositoryProvider)
      .watchHomeStats(ref.watch(clockProvider)),
);

final workoutsPerWeekProvider = StreamProvider<Map<String, int>>(
  (ref) => ref
      .watch(workoutRepositoryProvider)
      .watchWorkoutsPerWeek(ref.watch(clockProvider)),
);

final exercisesProvider = StreamProvider.family<List<ExerciseRow>, String>(
  (ref, query) =>
      ref.watch(exerciseRepositoryProvider).watchExercises(query: query),
);

final exerciseProvider = StreamProvider.family<ExerciseRow?, String>(
  (ref, id) => ref.watch(exerciseRepositoryProvider).watchExercise(id),
);

final planProvider = StreamProvider.family<PlanRow?, String>(
  (ref, id) => ref.watch(exerciseRepositoryProvider).watchPlan(id),
);

final trainedExercisesProvider = StreamProvider<List<TrainedExercise>>(
  (ref) => ref.watch(exerciseRepositoryProvider).watchTrainedExercises(),
);

final exerciseHistoryProvider =
    StreamProvider.family<List<ExerciseSession>, String>(
      (ref, id) => ref.watch(exerciseRepositoryProvider).watchHistory(id),
    );

final defaultRestProvider = StreamProvider<int>(
  (ref) => ref.watch(settingsRepositoryProvider).watchDefaultRestSeconds(),
);

final alertPrefsProvider = StreamProvider<RestAlertPrefs>(
  (ref) => ref.watch(settingsRepositoryProvider).watchAlertPrefs(),
);
