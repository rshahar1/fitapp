import 'package:fitapp/app/router.dart';
import 'package:fitapp/app/theme/app_theme.dart';
import 'package:fitapp/app/theme/tokens.dart';
import 'package:fitapp/core/format.dart';
import 'package:fitapp/data/models.dart';
import 'package:fitapp/data/providers.dart';
import 'package:fitapp/domain/start_guard.dart';
import 'package:fitapp/domain/tracking/track_reducer.dart' show elapsedAt;
import 'package:fitapp/features/start/start_actions.dart';
import 'package:fitapp/features/tracking/tracking_controller.dart';
import 'package:fitapp/features/train/steps_card.dart';
import 'package:fitapp/features/workout/widgets/tick.dart';
import 'package:fitapp/widgets/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

/// Home tab: start or continue a workout, stats and recent workouts.
class TrainScreen extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final stats = ref.watch(homeStatsProvider).value;
    final now = ref.watch(clockProvider)();
    final templates = ref.watch(templatesProvider).value ?? const [];
    final recent = stats?.recent.take(3).toList() ?? const [];

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
            const StepsCard(),
            SectionHeader(
              'Templates',
              trailing: TextButton(
                onPressed: () => context.push(Routes.newTemplate),
                child: const Text('New'),
              ),
            ),
            if (templates.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.m),
                child: Text(
                  'Create a template to start a routine in one tap.',
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
                    onStart: () => actions.startGym(context, templateId: t.id),
                  ),
                ),
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
                    label: 'Week streak',
                    value: '${stats?.streak ?? 0}',
                    caption: 'weeks',
                  ),
                ),
                const SizedBox(width: Space.s),
                Expanded(
                  child: MetricTile(
                    label: 'Total workouts',
                    value: '${stats?.total ?? 0}',
                  ),
                ),
              ],
            ),
            const SectionHeader('Recent'),
            if (recent.isEmpty)
              const EmptyState(
                icon: Icons.fitness_center,
                title: 'No workouts yet',
                message: 'Start your first workout to see it here.',
              )
            else
              Group(
                children: [
                  for (final w in recent)
                    GroupRow(
                      title: formatDateShort(w.startedAt.toLocal()),
                      subtitle: w.exerciseNames.join(', '),
                      trailing: Text(
                        formatVolume(w.volume),
                        style: TextStyle(color: context.metrics.volume),
                      ),
                      showChevron: true,
                      onTap: () => context.push(Routes.finishedWorkout(w.id)),
                    ),
                ],
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

/// The one "start or continue" surface on Train: one tap to a gym workout,
/// or continue the gym workout or GPS session in progress (feature 011).
class _HeroCard extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final secondary = text.bodyMedium?.copyWith(color: AppColors.textSecondary);
    final now = ref.watch(clockProvider)();
    final inProgress = ref.watch(sessionInProgressProvider);
    final actions = ref.read(startActionsProvider);

    final String title;
    Widget? line;
    switch (inProgress?.kind) {
      case null:
        title = 'Ready to train?';
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
        title = '${inProgress!.label} in progress';
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
      borderColor: inProgress?.kind == SessionKind.tracking
          ? AppColors.accent
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: text.titleLarge),
          if (line != null) ...[const SizedBox(height: Space.xs), line],
          const SizedBox(height: Space.m),
          AppButton(
            label: inProgress?.continueLabel ?? 'Start gym workout',
            icon: inProgress?.kind == SessionKind.tracking
                ? Icons.my_location
                : null,
            expand: true,
            onPressed: inProgress == null
                ? () => actions.startGym(context)
                : () => actions.open(context, inProgress),
          ),
        ],
      ),
    );
  }
}
