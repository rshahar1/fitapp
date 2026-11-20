import 'package:fitapp/features/activities/activity_detail_screen.dart';
import 'package:fitapp/features/activities/snow_replay_screen.dart';
import 'package:fitapp/features/exercises/exercise_library_screen.dart';
import 'package:fitapp/features/exercises/exercise_picker_screen.dart';
import 'package:fitapp/features/history/history_screen.dart';
import 'package:fitapp/features/progress/exercise_detail_screen.dart';
import 'package:fitapp/features/progress/progress_screen.dart';
import 'package:fitapp/features/settings/privacy_screen.dart';
import 'package:fitapp/features/settings/settings_screen.dart';
import 'package:fitapp/features/share/share_preview_screen.dart';
import 'package:fitapp/features/shell/shell_scaffold.dart';
import 'package:fitapp/features/templates/template_editor_screen.dart';
import 'package:fitapp/features/templates/templates_screen.dart';
import 'package:fitapp/features/tracking/live_track_screen.dart';
import 'package:fitapp/features/tracking/track_setup_screen.dart';
import 'package:fitapp/features/train/train_screen.dart';
import 'package:fitapp/features/workout/workout_screen.dart';
import 'package:fitapp/features/you/you_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// Route paths (contracts/ui-routes.md).
abstract final class Routes {
  static const train = '/train';
  static const history = '/history';
  static const progress = '/progress';

  /// You tab (feature 011): exercise library and settings.
  static const you = '/you';
  static const workout = '/workout';
  static const settings = '/settings';

  /// Step data explanation; also Health Connect's permission rationale.
  static const privacy = '/privacy';

  /// Live GPS tracking (feature 010): setup (GPS check) and the live screen.
  static const trackNew = '/track/new';
  static const trackLive = '/track/live';
  static String newTrack(String typeId) => '$trackNew?type=$typeId';

  /// Exercise library (feature 007), reachable without a workout.
  static const exercises = '/exercises';
  static String finishedWorkout(String id) => '/workout/$id';
  static String activity(String id) => '/activity/$id';
  static String exercise(String id) => '/exercise/$id';

  /// Share image previews (feature 027).
  static String shareWorkout(String id) => '/share/workout/$id';
  static String shareActivity(String id) => '/share/activity/$id';

  /// Gym templates list (feature 028), under You.
  static const templates = '/templates';
  static const newTemplate = '/template/new';
  static String template(String id) => '/template/$id';

  /// Exercise picker in selection mode; pops with the chosen exercise id.
  static const pickExercise = '/pick-exercise';
  static String addExercise(String workoutId) =>
      '/add-exercise?workout=$workoutId';
}

final _rootKey = GlobalKey<NavigatorState>();

GoRouter buildRouter() => GoRouter(
  navigatorKey: _rootKey,
  initialLocation:
      WidgetsBinding.instance.platformDispatcher.defaultRouteName ==
          Routes.privacy
      ? Routes.privacy
      : Routes.train,
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => ShellScaffold(shell: shell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(path: Routes.train, builder: (_, _) => const TrainScreen()),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: Routes.history,
              builder: (_, _) => const HistoryScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: Routes.progress,
              builder: (_, _) => const ProgressScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(path: Routes.you, builder: (_, _) => const YouScreen()),
          ],
        ),
      ],
    ),
    GoRoute(
      parentNavigatorKey: _rootKey,
      path: Routes.workout,
      builder: (_, _) => const WorkoutScreen(),
      routes: [
        GoRoute(
          path: ':id',
          builder: (_, state) =>
              WorkoutScreen(workoutId: state.pathParameters['id']),
        ),
      ],
    ),
    GoRoute(
      parentNavigatorKey: _rootKey,
      path: Routes.trackNew,
      builder: (_, state) =>
          TrackSetupScreen(typeId: state.uri.queryParameters['type']),
    ),
    GoRoute(
      parentNavigatorKey: _rootKey,
      path: Routes.trackLive,
      builder: (_, _) => const LiveTrackScreen(),
    ),
    GoRoute(
      parentNavigatorKey: _rootKey,
      path: '/activity/:id',
      builder: (_, state) =>
          ActivityDetailScreen(activityId: state.pathParameters['id']!),
    ),
    GoRoute(
      parentNavigatorKey: _rootKey,
      path: '/activity/:id/replay/:run',
      builder: (_, state) => SnowReplayScreen(
        activityId: state.pathParameters['id']!,
        runNumber: int.tryParse(state.pathParameters['run']!) ?? 1,
      ),
    ),
    GoRoute(
      parentNavigatorKey: _rootKey,
      path: '/share/workout/:id',
      builder: (_, state) => SharePreviewScreen(
        subject: ShareSubject.workout,
        id: state.pathParameters['id']!,
      ),
    ),
    GoRoute(
      parentNavigatorKey: _rootKey,
      path: '/share/activity/:id',
      builder: (_, state) => SharePreviewScreen(
        subject: ShareSubject.activity,
        id: state.pathParameters['id']!,
      ),
    ),
    GoRoute(
      parentNavigatorKey: _rootKey,
      path: '/exercise/:id',
      builder: (_, state) =>
          ExerciseDetailScreen(exerciseId: state.pathParameters['id']!),
    ),
    GoRoute(
      parentNavigatorKey: _rootKey,
      path: '/add-exercise',
      pageBuilder: (_, state) => MaterialPage(
        fullscreenDialog: true,
        child: ExercisePickerScreen(
          workoutId: state.uri.queryParameters['workout'],
        ),
      ),
    ),
    GoRoute(
      parentNavigatorKey: _rootKey,
      path: Routes.pickExercise,
      pageBuilder: (_, _) => const MaterialPage(
        fullscreenDialog: true,
        child: ExercisePickerScreen(),
      ),
    ),
    GoRoute(
      parentNavigatorKey: _rootKey,
      path: Routes.exercises,
      builder: (_, _) => const ExerciseLibraryScreen(),
    ),
    GoRoute(
      parentNavigatorKey: _rootKey,
      path: Routes.templates,
      builder: (_, _) => const TemplatesScreen(),
    ),
    GoRoute(
      parentNavigatorKey: _rootKey,
      path: Routes.newTemplate,
      builder: (_, _) => const TemplateEditorScreen(),
    ),
    GoRoute(
      parentNavigatorKey: _rootKey,
      path: '/template/:id',
      builder: (_, state) =>
          TemplateEditorScreen(templateId: state.pathParameters['id']),
    ),
    GoRoute(
      parentNavigatorKey: _rootKey,
      path: Routes.settings,
      builder: (_, _) => const SettingsScreen(),
    ),
    GoRoute(
      parentNavigatorKey: _rootKey,
      path: Routes.privacy,
      builder: (_, _) => const PrivacyScreen(),
    ),
  ],
);

final routerProvider = Provider<GoRouter>((ref) {
  final router = buildRouter();
  ref.onDispose(router.dispose);
  return router;
});
