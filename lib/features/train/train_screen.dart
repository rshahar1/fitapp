import 'package:fitapp/app/router.dart';
import 'package:fitapp/app/theme/tokens.dart';
import 'package:fitapp/core/format.dart';
import 'package:fitapp/data/models.dart';
import 'package:fitapp/data/providers.dart';
import 'package:fitapp/domain/start_guard.dart';
import 'package:fitapp/domain/tracking/track_reducer.dart' show elapsedAt;
import 'package:fitapp/domain/training_breakdown.dart';
import 'package:fitapp/features/activities/activity_icons.dart';
import 'package:fitapp/features/history/history_rows.dart';
import 'package:fitapp/features/start/start_actions.dart';
import 'package:fitapp/features/tracking/tracking_controller.dart';
import 'package:fitapp/features/train/steps_card.dart';
import 'package:fitapp/features/workout/widgets/tick.dart';
import 'package:fitapp/widgets/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

/// Home tab: continue a session in progress, start a template, stats (this
/// week, this month, all time), the types trained this week and the newest
/// sessions of any type (feature 028). Templates are created under You.
class TrainScreen extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final stats = ref.watch(homeStatsProvider).value;
    final now = ref.watch(clockProvider)();
    final templates = ref.watch(templatesProvider).value ?? const [];
    final recent = stats?.recent.take(3).toList() ?? const [];
    final byType = activeTypes(stats?.byType ?? const <TypeCount>[]);

    final actions = ref.read(startActionsProvider);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(Space.m),
          children: [
            Text(
              DateFormat('EEEE, d MMMM').format(now.toLocal()).toUpperCase(),
              style: text.labelSmall,
            ),
            Text('Train', style: text.headlineLarge),
            const SizedBox(height: Space.m),
            const _HeroCard(),
            const SectionHeader('Templates'),
            if (templates.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.m),
                child: Text(
                  'Create a template in You → Gym Templates to start a routine in one tap.',
                  style: text.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              )
            else
              for (final t in templates)
                Padding(
                  padding: const EdgeInsets.only(bottom: Space.s),
                  child: _TemplateCard(
                    template: t,
                    onStart: () => actions.startTemplate(context, t.id),
                  ),
                ),
            const StepsCard(),
            const SizedBox(height: Space.m),
            Row(
              children: [
                Expanded(
                  child: MetricTile(
                    label: 'This week',
                    value: '${stats?.thisWeek ?? 0}',
                  ),
                ),
                const SizedBox(width: Space.s),
                Expanded(
                  child: MetricTile(
                    label: 'This month',
                    value: '${stats?.thisMonth ?? 0}',
                  ),
                ),
                const SizedBox(width: Space.s),
                Expanded(
                  child: MetricTile(
                    label: 'All time',
                    value: '${stats?.allTime ?? 0}',
                  ),
                ),
              ],
            ),
            if (byType.isNotEmpty) ...[
              const SectionHeader('By type'),
              Group(
                children: [
                  for (final t in byType)
                    GroupRow(
                      leading: t.typeId == gymTypeId
                          ? const Icon(
                              gymWorkoutIcon,
                              size: 22,
                              color: AppColors.accent,
                            )
                          : ActivityIcon(
                              t.typeId,
                              size: 22,
                              color: AppColors.accent,
                            ),
                      title: trainingTypeLabel(t.typeId),
                      subtitle: '${t.allTime} all time',
                      trailing: Text(
                        '${t.thisWeek} this week',
                        style: const TextStyle(color: AppColors.accent),
                      ),
                    ),
                ],
              ),
            ],
            const SectionHeader('Recent'),
            if (recent.isEmpty)
              const EmptyState(
                icon: Icons.fitness_center,
                title: 'No workouts yet',
                message: 'Start your first workout to see it here.',
              )
            else
              Group(
                children: [for (final e in recent) HistoryEntryRow(entry: e)],
              ),
          ],
        ),
      ),
    );
  }
}

class _TemplateCard extends StatelessWidget {
  const new({required this.template, required this.onStart});

  final TemplateSummary template;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return AppCard(
      onTap: () => context.push(Routes.template(template.id)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(template.name, style: text.titleMedium),
                const SizedBox(height: Space.xs),
                Text(
                  template.exercises.map((e) => e.name).join(' · '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: Space.s),
          Semantics(
            button: true,
            label: 'Start ${template.name} template',
            excludeSemantics: true,
            onTap: onStart,
            child: TextButton(
              onPressed: onStart,
              style: TextButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: AppColors.onAccent,
                minimumSize: const Size(Sizes.tap, Sizes.tap),
                padding: const EdgeInsets.symmetric(horizontal: Space.m),
                shape: const StadiumBorder(),
              ),
              child: const Text(
                'START',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The "continue" surface on Train: shown only while a gym workout or GPS
/// session is in progress (features 011, 024). There is no empty gym start;
/// gym workouts start from a template.
class _HeroCard extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inProgress = ref.watch(sessionInProgressProvider);
    if (inProgress == null) return const SizedBox.shrink();
    final text = Theme.of(context).textTheme;
    final secondary = text.bodyMedium?.copyWith(color: AppColors.textSecondary);
    final now = ref.watch(clockProvider)();
    final actions = ref.read(startActionsProvider);

    final String title;
    Widget? line;
    switch (inProgress.kind) {
      case SessionKind.gym:
        title = 'Workout in progress';
        final active = ref.watch(activeWorkoutProvider).value;
        final live = ref.watch(liveSessionProvider).value;
        final session = live != null && live.workoutId == active?.id
            ? live
            : null;
        final started = active?.startedAt ?? now;
        line = Text(
          session != null && session.isResumed
              ? '${formatShortDuration(session.elapsed(now.toUtc()))} trained so far'
              : 'Started ${formatShortDuration(session?.elapsed(now.toUtc()) ?? now.difference(started))} ago',
          style: secondary,
        );
      case SessionKind.tracking:
        title = '${inProgress.label} in progress';
        final live = ref.watch(trackingControllerProvider);
        if (live is TrackingLive) {
          line = Tick(
            builder: (_) {
              final elapsed = elapsedAt(
                live.state,
                ref.read(clockProvider)().toUtc(),
              );
              return Text(
                '${formatClock(elapsed)} · '
                '${(live.state.distanceMeters / 1000).toStringAsFixed(1)} km',
                style: secondary,
              );
            },
          );
        }
    }

    return AppCard(
      borderColor: AppColors.live,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(child: Text(title, style: text.titleLarge)),
              const SizedBox(width: Space.s),
              Semantics(
                label: 'In progress',
                excludeSemantics: true,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: Space.s),
                  decoration: const ShapeDecoration(
                    color: AppColors.liveSoft,
                    shape: StadiumBorder(),
                  ),
                  child: Text(
                    '● LIVE',
                    style: text.labelSmall?.copyWith(color: AppColors.live),
                  ),
                ),
              ),
            ],
          ),
          if (line != null) ...[const SizedBox(height: Space.xs), line],
          const SizedBox(height: Space.m),
          AppButton(
            label: inProgress.continueLabel,
            icon: Icons.play_arrow,
            variant: AppButtonVariant.live,
            expand: true,
            onPressed: () => actions.open(context, inProgress),
          ),
        ],
      ),
    );
  }
}
