import 'dart:async';

import 'package:fitapp/app/theme/app_theme.dart';
import 'package:fitapp/app/theme/tokens.dart';
import 'package:fitapp/core/format.dart';
import 'package:fitapp/core/haptics.dart';
import 'package:fitapp/data/models.dart';
import 'package:fitapp/data/providers.dart';
import 'package:fitapp/domain/progression.dart';
import 'package:fitapp/domain/stats.dart';
import 'package:fitapp/features/workout/rest_timer_controller.dart';
import 'package:fitapp/features/workout/widgets/plan_form.dart';
import 'package:fitapp/features/workout/widgets/set_sheet.dart';
import 'package:fitapp/features/workout/widgets/set_table.dart';
import 'package:fitapp/widgets/guard.dart';
import 'package:fitapp/widgets/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// Plan summary such as `3 × 10 @ 20 kg · overload +2.5 · per hand`.
String planSummary(Plan plan, {required bool perHand}) => [
  '${plan.targetSets} × ${plan.targetReps} @ ${formatKg(plan.baseWeight)}',
  'overload +${formatWeight(plan.increment)}',
  if (perHand) 'per hand',
].join(' · ');

/// Builds the rows of the set table from plan, logged and previous sets.
List<SetLine> buildSetLines(WorkoutExerciseDetail d, {int extraRows = 0}) {
  final plan = d.effectivePlan;
  final prescribed = plan == null ? const <PrescribedSet>[] : prescribe(plan);
  final maxLogged = d.sets.isEmpty
      ? 0
      : d.sets.map((s) => s.setNo).reduce((a, b) => a > b ? a : b);
  final count =
      [prescribed.length, maxLogged].reduce((a, b) => a > b ? a : b) +
      extraRows;
  final lines = <SetLine>[];
  double? lastWeight;
  for (var n = 1; n <= count; n++) {
    final p = n <= prescribed.length ? prescribed[n - 1] : null;
    final logged = d.setNo(n);
    final fallbackWeight =
        lastWeight ?? plan?.baseWeight ?? d.previousSetNo(n)?.weight ?? 0;
    lines.add(
      SetLine(
        setNo: n,
        weight: p?.weight ?? fallbackWeight,
        reps: p?.reps ?? plan?.targetReps ?? d.previousSetNo(n)?.reps ?? 10,
        isOverload: p?.isOverload ?? false,
        isWorking: plan != null && n < plan.targetSets,
        targetReps: plan?.targetReps,
        logged: logged,
        previous: d.previousSetNo(n),
      ),
    );
    lastWeight = logged?.weight ?? lastWeight;
  }
  return lines;
}

/// Exercise card with the Hevy-style set table (PRD §5.3).
class ExerciseCard extends ConsumerStatefulWidget {
  const new({required this.detail, required this.isLive, super.key});

  final WorkoutExerciseDetail detail;

  /// Live workouts start the rest timer; edit mode doesn't.
  final bool isLive;

  @override
  ConsumerState<ExerciseCard> createState() => _ExerciseCardState();
}

class _ExerciseCardState extends ConsumerState<ExerciseCard> {
  int _extraRows = 0;

  WorkoutExerciseDetail get d => widget.detail;

  Future<void> _log(SetLine line, double weight, int reps) async {
    final ok = await guard(
      context,
      () => ref
          .read(workoutRepositoryProvider)
          .logSet(d.row.id, setNo: line.setNo, weight: weight, reps: reps),
    );
    if (!ok) return;
    ref.read(hapticsProvider).success();
    if (widget.isLive) {
      await ref
          .read(restTimerProvider.notifier)
          .startFor(exerciseRestSeconds: d.restSeconds);
    }
    if (line.setNo > (d.effectivePlan?.targetSets ?? 0) && _extraRows > 0) {
      setState(() => _extraRows--);
    }
  }

  Future<void> _edit(SetLine line) async {
    ref.read(hapticsProvider).tick();
    final logged = line.logged;
    final result = await showSetSheet(
      context,
      title: line.isOverload
          ? 'Set ${line.setNo} · overload'
          : 'Set ${line.setNo}',
      weight: logged?.weight ?? line.weight,
      reps: logged?.reps ?? line.reps,
      step: d.effectivePlan?.increment ?? d.exercise.defaultIncrement,
      isLogged: logged != null,
      perHand: d.exercise.isPerHand,
    );
    if (!mounted || result == null) return;
    switch (result) {
      case LogSetResult(:final weight, :final reps):
        await _log(line, weight, reps);
      case ClearSetResult():
        final ok = await guard(
          context,
          () => ref
              .read(workoutRepositoryProvider)
              .clearSet(d.row.id, line.setNo),
        );
        if (ok) ref.read(hapticsProvider).warning();
    }
  }

  Future<void> _remove() async {
    final confirmed = await confirmDestructive(
      context,
      title: 'Remove exercise?',
      message:
          'Remove ${d.exercise.name} and its logged sets from this workout?',
      confirmLabel: 'Remove',
    );
    if (!confirmed || !mounted) return;
    final ok = await guard(
      context,
      () => ref.read(workoutRepositoryProvider).removeExercise(d.row.id),
    );
    if (ok) ref.read(hapticsProvider).warning();
  }

  @override
  Widget build(BuildContext context) {
    final plan = d.effectivePlan;
    final needsSetup = plan == null && d.sets.isEmpty;
    final lines = buildSetLines(d, extraRows: _extraRows);
    return AppCard(
      padding: const EdgeInsets.fromLTRB(Space.m, Space.s, Space.xs, Space.m),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      d.exercise.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.accent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (plan != null)
                      Text(
                        planSummary(plan, perHand: d.exercise.isPerHand),
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: AppColors.textSecondary),
                      ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Exercise options for ${d.exercise.name}',
                icon: const Icon(Icons.more_vert),
                onSelected: (v) async {
                  switch (v) {
                    case 'plan':
                      await showEditPlanSheet(
                        context,
                        exercise: d.exercise,
                        plan: d.currentPlan,
                      );
                    case 'remove':
                      await _remove();
                  }
                },
                itemBuilder: (_) => [
                  if (!needsSetup)
                    const PopupMenuItem(
                      value: 'plan',
                      child: Text('Edit plan'),
                    ),
                  const PopupMenuItem(
                    value: 'remove',
                    child: Text('Remove exercise'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: Space.s),
          if (needsSetup)
            Padding(
              padding: const EdgeInsets.only(right: Space.s),
              child: PlanSetupCard(exercise: d.exercise),
            )
          else ...[
            const SetTableHeader(),
            for (final line in lines)
              SetRowView(
                key: ValueKey('set-${d.row.id}-${line.setNo}'),
                line: line,
                onCheck: () => line.isLogged
                    ? _edit(line)
                    : _log(line, line.weight, line.reps),
                onTap: () => _edit(line),
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () {
                  ref.read(hapticsProvider).tick();
                  setState(() => _extraRows++);
                },
                icon: const Icon(Icons.add),
                label: const Text('Add Set'),
              ),
            ),
            _NotesField(detail: d),
            if (d.sets.isNotEmpty) ...[
              const SizedBox(height: Space.s),
              Padding(
                padding: const EdgeInsets.only(right: Space.s),
                child: CompareCard(detail: d),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _NotesField extends ConsumerStatefulWidget {
  const new({required this.detail});

  final WorkoutExerciseDetail detail;

  @override
  ConsumerState<_NotesField> createState() => _NotesFieldState();
}

class _NotesFieldState extends ConsumerState<_NotesField> {
  late final _controller = TextEditingController(text: widget.detail.row.notes);
  late final _focus = FocusNode()..addListener(_onFocus);

  void _onFocus() {
    if (_focus.hasFocus) return;
    final text = _controller.text;
    if (text == (widget.detail.row.notes ?? '')) return;
    unawaited(
      guard(
        context,
        () => ref
            .read(workoutRepositoryProvider)
            .setExerciseNotes(widget.detail.row.id, text),
      ),
    );
  }

  @override
  void dispose() {
    _focus.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: Space.s),
    child: TextField(
      controller: _controller,
      focusNode: _focus,
      minLines: 1,
      maxLines: 3,
      textCapitalization: TextCapitalization.sentences,
      decoration: const InputDecoration(
        hintText: 'Add notes',
        isDense: true,
        border: InputBorder.none,
      ),
    ),
  );
}

/// "Compared to previous" card (PRD §5.3).
class CompareCard extends StatelessWidget {
  const new({required this.detail, super.key});

  final WorkoutExerciseDetail detail;

  @override
  Widget build(BuildContext context) {
    final current = detail.summary;
    final prev = detail.previousSummary;
    final diff = diffSummary(current, prev);
    final m = context.metrics;
    final label = Theme.of(context).textTheme.labelSmall;
    if (diff == null) {
      return Container(
        padding: const EdgeInsets.all(Space.m),
        decoration: BoxDecoration(
          color: AppColors.surfaceHigh,
          borderRadius: BorderRadius.circular(Radii.chip),
        ),
        child: Text('FIRST SESSION', style: label),
      );
    }
    Widget cell(String name, String value, MetricDelta delta, Color color) =>
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: label),
              const SizedBox(height: Space.xxs),
              Text(
                value,
                style: Theme.of(context).textTheme.titleSmall
                    ?.copyWith(color: color, fontFeatures: tabular),
              ),
              DeltaBadge(delta: delta, color: color),
            ],
          ),
        );
    return Container(
      padding: const EdgeInsets.all(Space.m),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(Radii.chip),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('COMPARED TO PREVIOUS', style: label),
          const SizedBox(height: Space.s),
          Row(
            children: [
              cell('SETS', '${current.sets}', diff.sets, m.sets),
              cell('REPS', '${current.reps}', diff.reps, m.reps),
              cell(
                'VOLUME',
                formatVolume(current.volume),
                diff.volume,
                m.volume,
              ),
              cell(
                'TOP',
                formatKg(current.topWeight),
                diff.topWeight,
                m.weight,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
