import 'package:fitapp/app/router.dart';
import 'package:fitapp/app/theme/app_theme.dart';
import 'package:fitapp/app/theme/tokens.dart';
import 'package:fitapp/core/format.dart';
import 'package:fitapp/core/haptics.dart';
import 'package:fitapp/data/models.dart';
import 'package:fitapp/data/providers.dart';
import 'package:fitapp/features/workout/rest_timer_controller.dart';
import 'package:fitapp/features/workout/widgets/exercise_card.dart';
import 'package:fitapp/features/workout/widgets/finish_summary_sheet.dart';
import 'package:fitapp/features/workout/widgets/rest_pill.dart';
import 'package:fitapp/features/workout/widgets/tick.dart';
import 'package:fitapp/widgets/guard.dart';
import 'package:fitapp/widgets/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// Whether a finished workout may be resumed right now.
final canResumeProvider = FutureProvider.autoDispose.family<bool, String>((
  ref,
  id,
) {
  // Re-evaluate whenever the active workout or history changes.
  ref
    ..watch(activeWorkoutProvider)
    ..watch(historyProvider);
  return ref.watch(workoutRepositoryProvider).canResume(id);
});

/// Live workout (no [workoutId]) or a finished workout in edit mode.
class WorkoutScreen extends ConsumerStatefulWidget {
  const new({this.workoutId, super.key});

  final String? workoutId;

  @override
  ConsumerState<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends ConsumerState<WorkoutScreen> {
  /// The live workout this screen opened with. Kept after finishing so the
  /// screen doesn't swap to "no workout" while the summary is shown.
  String? _liveId;

  @override
  Widget build(BuildContext context) {
    final id = widget.workoutId ?? _liveId;
    if (id != null) return _WorkoutBody(workoutId: id);
    final active = ref.watch(activeWorkoutProvider);
    return active.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, _) => const _Missing(message: 'Could not load the workout.'),
      data: (w) {
        if (w == null) {
          return const _Missing(message: 'No workout in progress.');
        }
        _liveId = w.id;
        return _WorkoutBody(workoutId: w.id);
      },
    );
  }
}

class _Missing extends StatelessWidget {
  const new({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(),
    body: EmptyState(
      icon: Icons.fitness_center,
      title: message,
      action: AppButton(
        label: 'Back to Train',
        onPressed: () => context.go(Routes.train),
      ),
    ),
  );
}

class _WorkoutBody extends ConsumerWidget {
  const new({required this.workoutId});

  final String workoutId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(workoutDetailProvider(workoutId));
    return detail.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, _) => const _Missing(message: 'Could not load the workout.'),
      data: (d) => d == null
          ? const _Missing(message: 'This workout no longer exists.')
          : _WorkoutView(detail: d),
    );
  }
}

class _WorkoutView extends ConsumerWidget {
  const new({required this.detail});

  final WorkoutDetail detail;

  bool get isLive => !detail.isFinished;

  Future<void> _finish(BuildContext context, WidgetRef ref) async {
    // Capture everything before the first await: finishing changes the
    // streams this widget is built from.
    final repo = ref.read(workoutRepositoryProvider);
    final rest = ref.read(restTimerProvider.notifier);
    final haptics = ref.read(hapticsProvider);
    final router = GoRouter.of(context);
    final rootContext = Navigator.of(context, rootNavigator: true).context;
    if (detail.setCount == 0) {
      final discard = await confirmDestructive(
        context,
        title: 'Discard workout?',
        message: 'No sets were logged. Discard this empty workout?',
        confirmLabel: 'Discard',
      );
      if (!discard || !context.mounted) return;
      final ok = await guard(
        context,
        () => repo.discardWorkout(detail.workout.id),
      );
      if (!ok) return;
      await rest.dismiss();
      router.go(Routes.train);
      return;
    }
    FinishResult? result;
    final ok = await guard(context, () async {
      result = await repo.finishWorkout(detail.workout.id);
    });
    if (!ok) return;
    await rest.dismiss();
    if (result!.outcomes.any((o) => o.toBase > o.fromBase)) haptics.success();
    if (rootContext.mounted) await showFinishSummary(rootContext, result!);
    router.go(Routes.train);
  }

  Future<void> _resume(BuildContext context, WidgetRef ref) async {
    final ok = await guard(
      context,
      () =>
          ref.read(workoutRepositoryProvider).resumeWorkout(detail.workout.id),
    );
    if (ok && context.mounted) context.go(Routes.workout);
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await confirmDestructive(
      context,
      title: 'Delete workout?',
      message:
          'This permanently deletes the workout and its sets. If it raised '
          'a working weight, that increase is undone.',
      confirmLabel: 'Delete',
    );
    if (!confirmed || !context.mounted) return;
    final ok = await guard(
      context,
      () =>
          ref.read(workoutRepositoryProvider).deleteWorkout(detail.workout.id),
    );
    if (ok && context.mounted) {
      ref.read(hapticsProvider).warning();
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final w = detail.workout;
    final m = context.metrics;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          isLive ? 'Workout' : formatDateShort(w.startedAt.toLocal()),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Space.m, 0, Space.m, Space.s),
            child: Row(
              children: [
                Expanded(
                  child: isLive
                      ? Tick(
                          builder: (_) => StatTile(
                            label: 'Duration',
                            value: formatClock(
                              ref
                                  .read(clockProvider)()
                                  .toUtc()
                                  .difference(w.startedAt),
                            ),
                          ),
                        )
                      : StatTile(
                          label: 'Duration',
                          value: formatShortDuration(
                            (w.endedAt ?? w.startedAt).difference(w.startedAt),
                          ),
                        ),
                ),
                Expanded(
                  child: StatTile(
                    label: 'Volume',
                    value: formatVolume(detail.volume),
                    color: m.volume,
                  ),
                ),
                Expanded(
                  child: StatTile(
                    label: 'Sets',
                    value: '${detail.setCount}',
                    color: m.sets,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Space.m, Space.s, Space.m, Space.xl),
        children: [
          if (!isLive)
            Padding(
              padding: const EdgeInsets.only(bottom: Space.s),
              child: Text(
                'Changes save automatically',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: AppColors.textSecondary),
              ),
            ),
          for (final e in detail.exercises)
            Padding(
              padding: const EdgeInsets.only(bottom: Space.m),
              child: ExerciseCard(
                key: ValueKey(e.row.id),
                detail: e,
                isLive: isLive,
              ),
            ),
          AppButton(
            label: 'Add Exercise',
            icon: Icons.add,
            variant: AppButtonVariant.secondary,
            expand: true,
            onPressed: () => context.push(Routes.addExercise(w.id)),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          height: Sizes.footer,
          padding: const EdgeInsets.symmetric(horizontal: Space.m),
          decoration: const BoxDecoration(
            color: AppColors.background,
            border: Border(
              top: BorderSide(
                color: AppColors.surfaceHigh,
                width: Sizes.hairline,
              ),
            ),
          ),
          child: isLive
              ? Row(
                  children: [
                    const Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: RestPill(),
                      ),
                    ),
                    AppButton(
                      label: 'Finish',
                      onPressed: () => _finish(context, ref),
                    ),
                  ],
                )
              : Row(
                  children: [
                    Expanded(
                      child: AppButton(
                        label: 'Done',
                        onPressed: () => context.canPop()
                            ? context.pop()
                            : context.go(Routes.history),
                      ),
                    ),
                    if (ref.watch(canResumeProvider(w.id)).value ?? false) ...[
                      const SizedBox(width: Space.s),
                      AppButton(
                        label: 'Resume',
                        variant: AppButtonVariant.secondary,
                        onPressed: () => _resume(context, ref),
                      ),
                    ],
                    const SizedBox(width: Space.s),
                    AppButton(
                      label: 'Delete',
                      variant: AppButtonVariant.danger,
                      onPressed: () => _delete(context, ref),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
