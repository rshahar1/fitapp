import 'package:fitapp/app/router.dart';
import 'package:fitapp/app/theme/app_theme.dart';
import 'package:fitapp/app/theme/tokens.dart';
import 'package:fitapp/core/format.dart';
import 'package:fitapp/core/haptics.dart';
import 'package:fitapp/data/models.dart';
import 'package:fitapp/data/providers.dart';
import 'package:fitapp/features/activities/activity_sheet.dart';
import 'package:fitapp/widgets/guard.dart';
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
    final active = ref.watch(activeWorkoutProvider).value;
    final now = ref.watch(clockProvider)();
    final liveSession = ref.watch(liveSessionProvider).value;
    final session = liveSession?.workoutId == active?.id ? liveSession : null;
    final templates = ref.watch(templatesProvider).value ?? const [];
    final recent = stats?.recent.take(3).toList() ?? const [];

    Future<void> start() async {
      final repo = ref.read(workoutRepositoryProvider);
      final haptics = ref.read(hapticsProvider);
      final ok = await guard(context, repo.startWorkout);
      if (!ok || !context.mounted) return;
      haptics.success();
      await context.push(Routes.workout);
    }

    Future<void> startTemplate(String id) async {
      if (active != null) {
        final cont = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Workout in progress'),
            content: const Text(
              'Finish or continue your current workout first.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Continue workout'),
              ),
            ],
          ),
        );
        if (cont == true && context.mounted) await context.push(Routes.workout);
        return;
      }
      final repo = ref.read(templateRepositoryProvider);
      final haptics = ref.read(hapticsProvider);
      final ok = await guard(context, () => repo.startWorkout(id));
      if (!ok || !context.mounted) return;
      haptics.success();
      await context.push(Routes.workout);
    }

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(Space.m),
          children: [
            Text(
              DateFormat('EEEE, d MMMM').format(now.toLocal()).toUpperCase(),
              style: text.labelSmall,
            ),
            Row(
              children: [
                Expanded(child: Text('Train', style: text.headlineLarge)),
                SizedBox.square(
                  dimension: Sizes.tap,
                  child: IconButton(
                    tooltip: 'Exercises',
                    icon: const Icon(Icons.list_alt),
                    onPressed: () => context.push(Routes.exercises),
                  ),
                ),
                SizedBox.square(
                  dimension: Sizes.tap,
                  child: IconButton(
                    tooltip: 'Settings',
                    icon: const Icon(Icons.settings_outlined),
                    onPressed: () => context.push(Routes.settings),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Space.m),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    active == null ? 'Ready to train?' : 'Workout in progress',
                    style: text.titleLarge,
                  ),
                  if (active != null) ...[
                    const SizedBox(height: Space.xs),
                    Text(
                      session != null && session.isResumed
                          ? '${formatShortDuration(session.elapsed(now.toUtc()))} trained so far'
                          : 'Started ${formatShortDuration(session?.elapsed(now.toUtc()) ?? now.difference(active.startedAt))} ago',
                      style: text.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                  const SizedBox(height: Space.m),
                  AppButton(
                    label: active == null
                        ? 'Start workout'
                        : 'Continue workout',
                    expand: true,
                    onPressed: active == null
                        ? start
                        : () => context.push(Routes.workout),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Space.s),
            AppButton(
              label: 'Log activity',
              expand: true,
              icon: Icons.add,
              variant: AppButtonVariant.secondary,
              onPressed: () => showActivitySheet(context),
            ),
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
                    onStart: () => startTemplate(t.id),
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
