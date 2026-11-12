import 'package:fitapp/features/exercises/exercise_picker_screen.dart';
import 'package:fitapp/features/history/history_screen.dart';
import 'package:fitapp/features/progress/exercise_detail_screen.dart';
import 'package:fitapp/features/progress/progress_screen.dart';
import 'package:fitapp/features/settings/settings_screen.dart';
import 'package:fitapp/features/shell/shell_scaffold.dart';
import 'package:fitapp/features/train/train_screen.dart';
import 'package:fitapp/features/workout/workout_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// Route paths (contracts/ui-routes.md).
abstract final class Routes {
  static const train = '/train';
  static const history = '/history';
  static const progress = '/progress';
  static const workout = '/workout';
  static const settings = '/settings';
  static String finishedWorkout(String id) => '/workout/$id';
  static String exercise(String id) => '/exercise/$id';
  static String addExercise(String workoutId) =>
      '/add-exercise?workout=$workoutId';
}

final _rootKey = GlobalKey<NavigatorState>();

GoRouter buildRouter() => GoRouter(
  navigatorKey: _rootKey,
  initialLocation: Routes.train,
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
          workoutId: state.uri.queryParameters['workout']!,
        ),
      ),
    ),
    GoRoute(
      parentNavigatorKey: _rootKey,
      path: Routes.settings,
      builder: (_, _) => const SettingsScreen(),
    ),
  ],
);

final routerProvider = Provider<GoRouter>((ref) {
  final router = buildRouter();
  ref.onDispose(router.dispose);
  return router;
});
