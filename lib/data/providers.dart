import 'dart:async';

import 'package:fitapp/core/env.dart';
import 'package:fitapp/core/step_source.dart';
import 'package:fitapp/data/db/app_database.dart';
import 'package:fitapp/data/models.dart';
import 'package:fitapp/data/repositories/activity_repository.dart';
import 'package:fitapp/data/repositories/auth_repository.dart';
import 'package:fitapp/data/repositories/exercise_repository.dart';
import 'package:fitapp/data/repositories/live_session_store.dart';
import 'package:fitapp/data/repositories/settings_repository.dart';
import 'package:fitapp/data/repositories/template_repository.dart';
import 'package:fitapp/data/repositories/tracking_repository.dart';
import 'package:fitapp/data/repositories/workout_repository.dart';
import 'package:fitapp/data/sync/account_service.dart';
import 'package:fitapp/data/sync/device_binding.dart';
import 'package:fitapp/data/sync/supabase_sync_remote.dart';
import 'package:fitapp/data/sync/sync_remote.dart';
import 'package:fitapp/data/sync/sync_service.dart';
import 'package:fitapp/data/tracking/geolocator_location_source.dart';
import 'package:fitapp/data/tracking/location_source.dart';
import 'package:fitapp/data/tracking/sim/track_simulation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

final workoutsPerWeekProvider = StreamProvider<Map<DateTime, int>>(
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

final restBetweenExercisesProvider = StreamProvider<int>(
  (ref) =>
      ref.watch(settingsRepositoryProvider).watchRestBetweenExercisesSeconds(),
);

final alertPrefsProvider = StreamProvider<RestAlertPrefs>(
  (ref) => ref.watch(settingsRepositoryProvider).watchAlertPrefs(),
);

final stepsEnabledProvider = StreamProvider<bool>(
  (ref) => ref.watch(settingsRepositoryProvider).watchStepsEnabled(),
);

/// Never touches the source while the feature is off.
final stepAccessProvider = FutureProvider.autoDispose<StepAccess>((ref) async {
  final enabled = await ref.watch(stepsEnabledProvider.future);
  if (!enabled) return StepAccess.unavailable;
  final access = await ref.watch(stepSourceProvider).access();
  return access;
});

/// Today's steps (local midnight to now); null when unreadable.
final todayStepsProvider = FutureProvider.autoDispose<int?>((ref) async {
  final enabled = await ref.watch(stepsEnabledProvider.future);
  if (!enabled) return null;
  final access = await ref.watch(stepAccessProvider.future);
  if (access != StepAccess.granted) return null;
  final now = ref.read(clockProvider)();
  final steps = await ref
      .read(stepSourceProvider)
      .stepsBetween(todayStart(now), now);
  return steps;
});

/// Whether the distance permission is granted (only asked once steps are).
final distanceAccessProvider = FutureProvider.autoDispose<bool>((ref) async {
  final access = await ref.watch(stepAccessProvider.future);
  if (access != StepAccess.granted) return false;
  return await ref.watch(stepSourceProvider).distanceAccess();
});

/// Today's distance in metres (midnight to now); null when unreadable.
final todayDistanceProvider = FutureProvider.autoDispose<double?>((ref) async {
  if (!await ref.watch(distanceAccessProvider.future)) return null;
  final now = ref.read(clockProvider)();
  return await ref
      .read(stepSourceProvider)
      .distanceBetween(todayStart(now), now);
});

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

/// The dev-only GPS simulation (feature 019), or null in a normal build.
/// Set in main() only when `kSimulateGps` is true.
final simulationProvider = Provider<TrackSimulation?>((ref) => null);

// --- Cloud backup and sync (feature 013) -----------------------------------

/// The Supabase client, or null when the build has no backend configured.
/// Overridden in main() after `Supabase.initialize`.
final supabaseClientProvider = Provider<SupabaseClient?>((ref) => null);

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(
    client: ref.watch(supabaseClientProvider),
    google: NativeGoogleTokenSource(serverClientId: Env.googleWebClientId),
  ),
);

/// The signed-in account, or null.
final authAccountProvider = StreamProvider<AuthAccount?>(
  (ref) => ref.watch(authRepositoryProvider).watchAccount(),
);

final deviceBindingProvider = Provider<DeviceBinding>(
  (ref) => DeviceBinding(ref.watch(databaseProvider)),
);

/// The backend for sync; null when not configured. Overridable in tests.
final syncRemoteProvider = Provider<SyncRemote?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client == null ? null : SupabaseSyncRemote(client);
});

/// Null when cloud backup is not configured in this build.
final syncServiceProvider = Provider<SyncService?>((ref) {
  final remote = ref.watch(syncRemoteProvider);
  if (remote == null) return null;
  final auth = ref.watch(authRepositoryProvider);
  final service = SyncService(
    db: ref.watch(databaseProvider),
    remote: remote,
    settings: ref.watch(settingsRepositoryProvider),
    binding: ref.watch(deviceBindingProvider),
    currentUserId: () => auth.current?.userId,
  );
  ref.onDispose(service.dispose);
  return service;
});

/// Null when cloud backup is not configured in this build.
final accountServiceProvider = Provider<AccountService?>((ref) {
  final sync = ref.watch(syncServiceProvider);
  final remote = ref.watch(syncRemoteProvider);
  if (sync == null || remote == null) return null;
  return AccountService(
    auth: ref.watch(authRepositoryProvider),
    binding: ref.watch(deviceBindingProvider),
    sync: sync,
    remote: remote,
  );
});

final syncStatusProvider = StreamProvider<SyncStatus>((ref) {
  final sync = ref.watch(syncServiceProvider);
  if (sync == null) return Stream.value(const SyncStatus());
  return sync.watchStatus();
});

/// Time of the last successful backup, or null.
final lastBackupProvider = StreamProvider<DateTime?>(
  (ref) => ref.watch(deviceBindingProvider).watchLastSuccessAt(),
);

/// Email of the account this phone's data belongs to, or null.
final boundEmailProvider = StreamProvider<String?>(
  (ref) => ref.watch(deviceBindingProvider).watchBoundEmail(),
);

/// Starts a background sync if backup is configured; never waits or throws
/// (FR-002, FR-013).
void requestSync(Ref ref) => _request(ref.read(syncServiceProvider));

/// [requestSync] for widgets.
void requestSyncFrom(WidgetRef ref) => _request(ref.read(syncServiceProvider));

void _request(SyncService? sync) {
  if (sync != null) unawaited(sync.syncNow());
}

/// Steps on one local day (key: date-only local DateTime); null when off, not
/// granted, outside the readable window, or unreadable. Never reads the
/// source in those cases.
final daySteps = FutureProvider.autoDispose.family<int?, DateTime>((
  ref,
  day,
) async {
  final enabled = await ref.watch(stepsEnabledProvider.future);
  if (!enabled) return null;
  final window = stepWindow(day, ref.read(clockProvider)());
  if (window == null) return null;
  final access = await ref.watch(stepAccessProvider.future);
  if (access != StepAccess.granted) return null;
  return await ref
      .read(stepSourceProvider)
      .stepsBetween(window.start, window.end);
});

/// Distance in metres on one local day (same rules as [daySteps]).
final dayDistance = FutureProvider.autoDispose.family<double?, DateTime>((
  ref,
  day,
) async {
  final window = stepWindow(day, ref.read(clockProvider)());
  if (window == null) return null;
  if (!await ref.watch(distanceAccessProvider.future)) return null;
  return await ref
      .read(stepSourceProvider)
      .distanceBetween(window.start, window.end);
});
