import 'package:fitapp/data/db/app_database.dart';
import 'package:fitapp/data/models.dart';
import 'package:fitapp/data/repositories/activity_repository.dart';
import 'package:fitapp/data/repositories/exercise_repository.dart';
import 'package:fitapp/data/repositories/live_session_store.dart';
import 'package:fitapp/data/repositories/settings_repository.dart';
import 'package:fitapp/data/repositories/template_repository.dart';
import 'package:fitapp/data/repositories/tracking_repository.dart';
import 'package:fitapp/data/repositories/workout_repository.dart';
import 'package:fitapp/data/tracking/geolocator_location_source.dart';
import 'package:fitapp/data/tracking/location_source.dart';
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

final templateRepositoryProvider = Provider<TemplateRepository>(
  (ref) => TemplateRepository(ref.watch(databaseProvider)),
);

final templatesProvider = StreamProvider<List<TemplateSummary>>(
  (ref) => ref.watch(templateRepositoryProvider).watchTemplates(),
);

final activityRepositoryProvider = Provider<ActivityRepository>(
  (ref) => ActivityRepository(ref.watch(databaseProvider)),
);

/// One activity by id (feature 010 detail screen); null when deleted.
final activityProvider = StreamProvider.family<ActivityRow?, String>(
  (ref, id) => ref.watch(activityRepositoryProvider).watchActivity(id),
);

/// Workouts and activities together, newest first (feature 006).
final historyEntriesProvider = StreamProvider<List<HistoryEntry>>(
  (ref) => ref.watch(workoutRepositoryProvider).watchHistoryEntries(),
);

/// The live-session record of the workout in progress (feature 007), or
/// null. Check `workoutId` against the active workout before using it.
final liveSessionProvider = StreamProvider<LiveSession?>(
  (ref) => ref.watch(workoutRepositoryProvider).watchLiveSession(),
);

final trackingRepositoryProvider = Provider<TrackingRepository>(
  (ref) => TrackingRepository(ref.watch(databaseProvider)),
);

/// The in-progress GPS tracking session row, or null (feature 010).
final activeTrackingProvider = StreamProvider<TrackingSessionRow?>(
  (ref) => ref.watch(trackingRepositoryProvider).watchSession(),
);

/// GPS source; overridden with a fake in tests.
final locationSourceProvider = Provider<LocationSource>(
  (ref) => GeolocatorLocationSource(),
);
