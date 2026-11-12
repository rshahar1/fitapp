import 'package:fitapp/app/router.dart';
import 'package:fitapp/app/theme/app_theme.dart';
import 'package:fitapp/app/theme/tokens.dart';
import 'package:fitapp/core/format.dart';
import 'package:fitapp/data/db/app_database.dart';
import 'package:fitapp/data/models.dart';
import 'package:fitapp/data/providers.dart';
import 'package:fitapp/domain/stats.dart';
import 'package:fitapp/features/workout/widgets/exercise_card.dart';
import 'package:fitapp/features/workout/widgets/plan_form.dart';
import 'package:fitapp/widgets/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// Exercise detail with Summary and History tabs.
class ExerciseDetailScreen extends ConsumerWidget {
  const new({required this.exerciseId, super.key});

  /// The exercise to show.
  final String exerciseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exercise = ref.watch(exerciseProvider(exerciseId)).value;
    final plan = ref.watch(planProvider(exerciseId)).value;
    final history = ref.watch(exerciseHistoryProvider(exerciseId));
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(exercise?.name ?? ''),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Summary'),
              Tab(text: 'History'),
            ],
          ),
        ),
        body: exercise == null || history.isLoading
            ? const Center(child: CircularProgressIndicator())
            : history.hasError
            ? const Center(child: Text('Could not load history.'))
            : TabBarView(
                children: [
                  _SummaryTab(
                    exercise: exercise,
                    plan: plan,
                    sessions: history.value ?? const [],
                  ),
                  _HistoryTab(sessions: history.value ?? const []),
                ],
              ),
      ),
    );
  }
}

enum _Metric {
  weight('Working weight'),
  volume('Volume'),
  oneRm('Est. 1RM');

  new(this.label);

  final String label;
}

/// Maximum number of sessions drawn on the chart.
const _chartSessions = 20;

String _prLabel(PrType t) => switch (t) {
  PrType.heaviestWeight => 'Heaviest',
  PrType.best1RM => '1RM',
  PrType.bestSetVolume => 'Volume',
};

/// Record types set by the latest session (newest first list), empty for a
/// first session.
Set<PrType> _latestPRs(List<ExerciseSession> sessions, bool perHand) {
  if (sessions.length < 2) return const {};
  final prior = personalRecords(
    sessions.skip(1).expand((s) => s.sets.map(loggedFromRow)),
    perHand: perHand,
  );
  return {
    for (final s in sessions.first.sets)
      ...newPRTypes(loggedFromRow(s), prior, perHand: perHand),
  };
}

class _SummaryTab extends StatefulWidget {
  const new({
    required this.exercise,
    required this.plan,
    required this.sessions,
  });

  final ExerciseRow exercise;
  final PlanRow? plan;
  final List<ExerciseSession> sessions;

  @override
  State<_SummaryTab> createState() => _SummaryTabState();
}

class _SummaryTabState extends State<_SummaryTab> {
  _Metric _metric = _Metric.weight;

  @override
  Widget build(BuildContext context) {
    final sessions = widget.sessions;
    final summaries = [for (final s in sessions) s.summary];
    final m = context.metrics;
    final heaviest = summaries.fold<double>(
      0,
      (v, s) => s.topWeight > v ? s.topWeight : v,
    );
    final best1RM = summaries.fold<double>(
      0,
      (v, s) => s.best1RM > v ? s.best1RM : v,
    );
    final has = sessions.isNotEmpty;
    return ListView(
      padding: const EdgeInsets.all(Space.m),
      children: [
        Row(
          children: [
            Expanded(
              child: MetricTile(
                label: 'Current base',
                value: widget.plan == null
                    ? '—'
                    : formatKg(widget.plan!.baseWeight),
                color: m.weight,
              ),
            ),
            const SizedBox(width: Space.s),
            Expanded(
              child: MetricTile(
                label: 'Heaviest set',
                value: has ? formatKg(heaviest) : '—',
                color: m.weight,
              ),
            ),
          ],
        ),
        const SizedBox(height: Space.s),
        Row(
          children: [
            Expanded(
              child: MetricTile(
                label: 'Est. 1RM',
                value: has ? formatKg(best1RM) : '—',
                color: m.weight,
              ),
            ),
            const SizedBox(width: Space.s),
            Expanded(
              child: MetricTile(
                label: 'Sessions',
                value: '${sessions.length}',
                color: m.sets,
              ),
            ),
          ],
        ),
        if (has) ...[
          const SizedBox(height: Space.m),
          _ChartCard(
            sessions: sessions,
            summaries: summaries,
            metric: _metric,
            onMetric: (v) => setState(() => _metric = v),
            prs: _latestPRs(sessions, widget.exercise.isPerHand),
          ),
          const SizedBox(height: Space.m),
          _CompareCard(
            latest: summaries.first,
            previous: summaries.elementAtOrNull(1),
          ),
        ],
        const SizedBox(height: Space.m),
        _PlanCard(exercise: widget.exercise, plan: widget.plan),
        if (!has)
          const EmptyState(
            icon: Icons.show_chart,
            title: 'No sessions yet',
            message: 'Finish a workout with this exercise to see progress.',
          ),
      ],
    );
  }
}

class _ChartCard extends StatelessWidget {
  const new({
    required this.sessions,
    required this.summaries,
    required this.metric,
    required this.onMetric,
    required this.prs,
  });

  final List<ExerciseSession> sessions;
  final List<SessionSummary> summaries;
  final _Metric metric;
  final ValueChanged<_Metric> onMetric;
  final Set<PrType> prs;

  @override
  Widget build(BuildContext context) {
    final m = context.metrics;
    final text = Theme.of(context).textTheme;
    final recent = summaries.take(_chartSessions).toList().reversed.toList();
    final (values, color) = switch (metric) {
      _Metric.weight => ([for (final s in recent) s.workingWeight], m.weight),
      _Metric.volume => ([for (final s in recent) s.volume], m.volume),
      _Metric.oneRm => ([for (final s in recent) s.best1RM], m.reps),
    };
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'LAST ${recent.length} '
                  '${recent.length == 1 ? 'SESSION' : 'SESSIONS'}',
                  style: text.labelSmall,
                ),
              ),
              if (prs.isNotEmpty) _PrBadge(types: prs),
            ],
          ),
          const SizedBox(height: Space.s),
          ChipSelector<_Metric>(
            options: _Metric.values,
            selected: metric,
            labelOf: (v) => v.label,
            onSelected: onMetric,
          ),
          const SizedBox(height: Space.m),
          GlowLineChart(
            values: values,
            color: color,
            format: metric == _Metric.volume ? formatVolume : formatKg,
          ),
        ],
      ),
    );
  }
}

class _PrBadge extends StatelessWidget {
  const new({required this.types});

  final Set<PrType> types;

  @override
  Widget build(BuildContext context) {
    final label = [
      for (final t in PrType.values)
        if (types.contains(t)) _prLabel(t),
    ].join(' · ');
    return Semantics(
      label: 'Personal record: $label',
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: const ShapeDecoration(
          color: AppColors.accentSoft,
          shape: StadiumBorder(),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Space.s + Space.xs,
            vertical: Space.xs,
          ),
          child: Text(
            'PR · $label',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: AppColors.accent,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _CompareCard extends StatelessWidget {
  const new({required this.latest, required this.previous});

  final SessionSummary latest;
  final SessionSummary? previous;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final m = context.metrics;
    final diff = diffSummary(latest, previous);
    Widget cell(String label, MetricDelta d, Color c) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: text.labelSmall),
          const SizedBox(height: Space.xs),
          DeltaBadge(delta: d, color: c),
        ],
      ),
    );
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('COMPARED TO PREVIOUS', style: text.labelSmall),
          const SizedBox(height: Space.s),
          if (diff == null)
            Text(
              'First session',
              style: text.bodyMedium?.copyWith(color: AppColors.textSecondary),
            )
          else
            Row(
              children: [
                cell('Sets', diff.sets, m.sets),
                cell('Reps', diff.reps, m.reps),
                cell('Volume', diff.volume, m.volume),
                cell('Top weight', diff.topWeight, m.weight),
              ],
            ),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const new({required this.exercise, required this.plan});

  final ExerciseRow exercise;
  final PlanRow? plan;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final p = plan;
    final rest = p?.restSeconds;
    return AppCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('PLAN', style: text.labelSmall),
                const SizedBox(height: Space.xs),
                if (p == null)
                  Text(
                    'No plan yet',
                    style: text.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  )
                else ...[
                  Text(
                    planSummary(p.toPlan(), perHand: exercise.isPerHand),
                    style: text.bodyMedium,
                  ),
                  Text(
                    rest == null
                        ? 'Rest: default'
                        : 'Rest: ${formatClock(Duration(seconds: rest))}',
                    style: text.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: Space.s),
          AppButton(
            label: p == null ? 'Set up plan' : 'Edit',
            variant: AppButtonVariant.secondary,
            onPressed: () =>
                showEditPlanSheet(context, exercise: exercise, plan: p),
          ),
        ],
      ),
    );
  }
}

class _HistoryTab extends StatelessWidget {
  const new({required this.sessions});

  final List<ExerciseSession> sessions;

  @override
  Widget build(BuildContext context) {
    if (sessions.isEmpty) {
      return const EmptyState(
        icon: Icons.history,
        title: 'No sessions yet',
        message: 'Finished sessions show up here.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(Space.m),
      itemCount: sessions.length,
      separatorBuilder: (_, _) => const SizedBox(height: Space.s),
      itemBuilder: (context, i) => _SessionCard(session: sessions[i]),
    );
  }
}

class _SessionCard extends StatelessWidget {
  const new({required this.session});

  final ExerciseSession session;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final m = context.metrics;
    final date = formatDateShort(session.date.toLocal());
    final sets = [...session.sets]..sort((a, b) => a.setNo.compareTo(b.setNo));
    final numbers = text.bodyLarge?.copyWith(fontFeatures: tabular);
    return AppCard(
      onTap: () => context.push(Routes.finishedWorkout(session.workoutId)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(date, style: text.titleMedium),
          const SizedBox(height: Space.s),
          for (final s in sets)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Space.xxs),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      s.isOverload ? 'Set ${s.setNo} ↑' : 'Set ${s.setNo}',
                      style: text.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  Text('${s.reps}', style: numbers?.copyWith(color: m.reps)),
                  const SizedBox(width: Space.l),
                  SizedBox(
                    width: Space.xxl + Space.l,
                    child: Text(
                      formatKg(s.weight),
                      textAlign: TextAlign.end,
                      style: numbers?.copyWith(color: m.weight),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
