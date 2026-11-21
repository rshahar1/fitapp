import 'dart:async';

import 'package:fitapp/app/router.dart';
import 'package:fitapp/app/theme/app_icons.dart';
import 'package:fitapp/app/theme/app_theme.dart';
import 'package:fitapp/app/theme/tokens.dart';
import 'package:fitapp/core/format.dart';
import 'package:fitapp/core/haptics.dart';
import 'package:fitapp/data/models.dart';
import 'package:fitapp/data/providers.dart';
import 'package:fitapp/data/repositories/live_session_store.dart';
import 'package:fitapp/data/repositories/template_repository.dart';
import 'package:fitapp/domain/calendar.dart' show dateOnly;
import 'package:fitapp/domain/workout_progress.dart';
import 'package:fitapp/features/settings/account_section.dart';
import 'package:fitapp/features/workout/rest_timer_controller.dart';
import 'package:fitapp/features/workout/widgets/exercise_card.dart';
import 'package:fitapp/features/workout/widgets/finish_summary_sheet.dart';
import 'package:fitapp/features/workout/widgets/rest_pill.dart';
import 'package:fitapp/features/workout/widgets/tick.dart';
import 'package:fitapp/widgets/guard.dart';
import 'package:fitapp/widgets/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

/// Live workout (no [workoutId]) or a finished workout, shown read-only
/// until Edit is tapped (feature 020).
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
      icon: AppIcons.gym,
      title: message,
      action: AppButton(
        label: 'Back to Home',
        onPressed: () => context.go(Routes.train),
      ),
    ),
  );
}

class _WorkoutBody extends ConsumerStatefulWidget {
  const new({required this.workoutId});

  final String workoutId;

  @override
  ConsumerState<_WorkoutBody> createState() => _WorkoutBodyState();
}

class _WorkoutBodyState extends ConsumerState<_WorkoutBody> {
  /// A finished workout opens read-only; Edit switches this on.
  bool _editing = false;

  final _scroll = ScrollController();
  final _cardKeys = <String, GlobalKey>{};

  /// The live workout jumps to its current exercise once per visit
  /// (feature 023), never again after the user scrolls or logs.
  bool _resumed = false;

  GlobalKey _keyFor(String workoutExerciseId) =>
      _cardKeys.putIfAbsent(workoutExerciseId, GlobalKey.new);

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _resumeAt(WorkoutDetail d) {
    if (_resumed) return;
    _resumed = true;
    if (d.isFinished) return;
    final index = resumeExerciseIndex([
      for (final e in d.exercises)
        ExerciseProgress(
          loggedSetNos: {for (final s in e.sets) s.setNo},
          plannedSets: e.effectivePlan?.targetSets,
        ),
    ]);
    if (index == null) return;
    final key = _keyFor(d.exercises[index].row.id);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = key.currentContext;
      if (!mounted || target == null || !target.mounted) return;
      Scrollable.ensureVisible(target);
    });
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(workoutDetailProvider(widget.workoutId));
    return detail.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, _) => const _Missing(message: 'Could not load the workout.'),
      data: (d) {
        if (d == null) {
          return const _Missing(message: 'This workout no longer exists.');
        }
        _resumeAt(d);
        return _WorkoutView(
          detail: d,
          editing: _editing,
          onToggleEdit: () => setState(() => _editing = !_editing),
          scrollController: _scroll,
          cardKey: _keyFor,
        );
      },
    );
  }
}

class _WorkoutView extends ConsumerWidget {
  const new({
    required this.detail,
    required this.editing,
    required this.onToggleEdit,
    required this.scrollController,
    required this.cardKey,
  });

  final WorkoutDetail detail;
  final ScrollController scrollController;

  /// Locates an exercise card (by workout exercise id) for scrolling.
  final GlobalKey Function(String workoutExerciseId) cardKey;

  /// Edit mode of a finished workout (ignored while live).
  final bool editing;
  final VoidCallback onToggleEdit;

  bool get isLive => !detail.isFinished;

  /// A finished workout outside edit mode: review only.
  bool get readOnly => !isLive && !editing;

  Future<void> _finish(BuildContext context, WidgetRef ref) async {
    // Capture everything before the first await: finishing changes the
    // streams this widget is built from.
    final repo = ref.read(workoutRepositoryProvider);
    final rest = ref.read(restTimerProvider.notifier);
    final haptics = ref.read(hapticsProvider);
    final router = GoRouter.of(context);
    final rootContext = Navigator.of(context, rootNavigator: true).context;
    final messenger = ScaffoldMessenger.of(context);
    final container = ProviderScope.containerOf(context);
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
    requestSyncFrom(ref); // back up the finished workout (FR-013)
    await rest.dismiss();
    if (result!.outcomes.any((o) => o.toBase > o.fromBase)) haptics.success();
    var choice = FinishChoice.done;
    if (rootContext.mounted) {
      choice = await showFinishSummary(rootContext, result!);
    }
    if (choice == FinishChoice.resume) {
      try {
        await repo.resumeWorkout(detail.workout.id);
        router.go(Routes.workout);
        return;
      } on Object {
        // Fall through to Home if resuming is no longer possible.
      }
    }
    try {
      await maybeShowBackupNudge(
        container,
        messenger: messenger,
        router: router,
      );
    } on Object {
      // The nudge is optional; never block leaving the screen.
    }
    router.go(Routes.train);
    if (choice == FinishChoice.share) {
      unawaited(router.push(Routes.shareWorkout(detail.workout.id)));
    }
  }

  Future<void> _discard(
    BuildContext context,
    WidgetRef ref,
    LiveSession? session,
  ) async {
    final repo = ref.read(workoutRepositoryProvider);
    final rest = ref.read(restTimerProvider.notifier);
    final haptics = ref.read(hapticsProvider);
    final router = GoRouter.of(context);
    final resumed = session?.isResumed ?? false;
    final confirmed = await confirmDestructive(
      context,
      title: 'Discard workout?',
      message: resumed
          ? 'This workout was resumed from History. Discarding deletes the '
                'whole workout, including the sets logged before. This cannot '
                'be undone.'
          : 'This workout and its logged sets will be deleted. This cannot '
                'be undone.',
      confirmLabel: 'Discard',
    );
    if (!confirmed || !context.mounted) return;
    final ok = await guard(
      context,
      () => repo.discardWorkout(detail.workout.id),
    );
    if (!ok) return;
    await rest.dismiss();
    haptics.warning();
    router.go(Routes.train);
  }

  String _dayLabel(DateTime day, DateTime now) {
    final today = dateOnly(now.toLocal());
    if (day == today) return 'Today';
    if (day == today.subtract(const Duration(days: 1))) return 'Yesterday';
    return formatDateShort(day);
  }

  Future<void> _pickDay(
    BuildContext context,
    WidgetRef ref,
    DateTime current,
  ) async {
    final repo = ref.read(workoutRepositoryProvider);
    final today = dateOnly(ref.read(clockProvider)().toLocal());
    final picked = await showDatePicker(
      context: context,
      initialDate: current.isAfter(today) ? today : current,
      firstDate: DateTime(today.year - 5, today.month, today.day),
      lastDate: today,
    );
    if (picked == null || !context.mounted) return;
    final day = dateOnly(picked);
    await guard(
      context,
      () => isLive
          ? repo.setLiveWorkoutDay(detail.workout.id, day)
          : repo.setWorkoutDay(detail.workout.id, day),
    );
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

  Future<void> _saveAsTemplate(BuildContext context, WidgetRef ref) async {
    final repo = ref.read(templateRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _SaveTemplateDialog(
        initial:
            'Workout ${DateFormat('d MMM').format(detail.workout.startedAt.toLocal())}',
      ),
    );
    if (name == null || !context.mounted) return;
    var duplicate = false;
    final ok = await guard(context, () async {
      try {
        await repo.saveFromWorkout(detail.workout.id, name: name);
      } on DuplicateTemplateName {
        duplicate = true;
      }
    });
    if (!ok) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(duplicate ? 'Name already used' : 'Template saved'),
      ),
    );
  }

  void _toggleEdit(WidgetRef ref) {
    ref.read(hapticsProvider).tick();
    onToggleEdit();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final w = detail.workout;
    final m = context.metrics;
    final liveSession = isLive ? ref.watch(liveSessionProvider).value : null;
    final session = liveSession?.workoutId == w.id ? liveSession : null;
    final now = ref.watch(clockProvider)();
    final shownDay = session?.day ?? dateOnly(w.startedAt.toLocal());
    // A finished workout has no footer (feature 020): its options menu holds
    // only Edit, Share and Delete (feature 037); Resume is offered from the
    // finish summary. Back leaves the screen; while editing only "Done
    // editing" stays in the app bar.
    return Scaffold(
      appBar: AppBar(
        title: Text(
          isLive ? 'Workout' : formatDateShort(w.startedAt.toLocal()),
        ),
        actions: [
          if (!isLive && editing)
            IconButton(
              icon: const Icon(AppIcons.check),
              tooltip: 'Done editing',
              onPressed: () => _toggleEdit(ref),
            ),
          // Always shown: finished workouts hold Share/Edit/Delete here, live ones
          // hold Discard.
          PopupMenuButton<String>(
            tooltip: 'Workout options',
            onSelected: (v) => switch (v) {
              'edit' => _toggleEdit(ref),
              'discard' => _discard(context, ref, session),
              'share' => context.push(Routes.shareWorkout(w.id)),
              'delete' => _delete(context, ref),
              'template' => _saveAsTemplate(context, ref),
              _ => null,
            },
            itemBuilder: (_) => [
              if (readOnly)
                const PopupMenuItem(
                  value: 'share',
                  child: ListTile(
                    leading: Icon(AppIcons.share),
                    title: Text('Share'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              if (readOnly)
                const PopupMenuItem(
                  value: 'edit',
                  child: ListTile(
                    leading: Icon(AppIcons.edit),
                    title: Text('Edit workout'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              if (isLive && detail.exercises.isNotEmpty)
                const PopupMenuItem(
                  value: 'template',
                  child: Text('Save as template'),
                ),
              if (!isLive)
                const PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                    leading: Icon(AppIcons.delete, color: AppColors.danger),
                    title: Text(
                      'Delete workout',
                      style: TextStyle(color: AppColors.danger),
                    ),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              if (isLive)
                const PopupMenuItem(
                  value: 'discard',
                  child: Text('Discard workout'),
                ),
            ],
          ),
        ],
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
                            value: formatClock(() {
                              final t = ref.read(clockProvider)().toUtc();
                              return session?.elapsed(t) ??
                                  t.difference(w.startedAt);
                            }()),
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
      // Every card is built (not lazily) so the live workout can scroll to
      // its current exercise on open (feature 023).
      body: SingleChildScrollView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(Space.m, Space.s, Space.m, Space.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: Space.m),
              child: Group(
                children: [
                  GroupRow(
                    title: 'Date',
                    trailing: Text(
                      _dayLabel(shownDay, now),
                      style: Theme.of(context).textTheme.bodyLarge
                          ?.copyWith(color: AppColors.accent),
                    ),
                    showChevron: !readOnly,
                    onTap: readOnly
                        ? null
                        : () => _pickDay(context, ref, shownDay),
                  ),
                ],
              ),
            ),
            if (!isLive && editing)
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
                key: cardKey(e.row.id),
                padding: const EdgeInsets.only(bottom: Space.m),
                child: ExerciseCard(
                  key: ValueKey(e.row.id),
                  detail: e,
                  isLive: isLive,
                  readOnly: readOnly,
                ),
              ),
            if (readOnly && detail.exercises.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: Space.l),
                child: Text(
                  'No exercises logged',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: AppColors.textSecondary),
                ),
              ),
            if (!readOnly)
              AppButton(
                label: 'Add Exercise',
                icon: AppIcons.add,
                variant: AppButtonVariant.secondary,
                expand: true,
                onPressed: () => context.push(Routes.addExercise(w.id)),
              ),
          ],
        ),
      ),
      bottomNavigationBar: !isLive
          ? null
          : SafeArea(
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
                child: Row(
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
                ),
              ),
            ),
    );
  }
}

class _SaveTemplateDialog extends StatefulWidget {
  const new({required this.initial});

  final String initial;

  @override
  State<_SaveTemplateDialog> createState() => _SaveTemplateDialogState();
}

class _SaveTemplateDialogState extends State<_SaveTemplateDialog> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Save as template'),
    content: TextField(
      controller: _controller,
      autofocus: true,
      maxLength: 40,
      decoration: const InputDecoration(labelText: 'Template name'),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      TextButton(
        onPressed: () => Navigator.of(context).pop(_controller.text),
        child: const Text('Save'),
      ),
    ],
  );
}
