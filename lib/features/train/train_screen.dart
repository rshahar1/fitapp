import 'package:fitapp/app/router.dart';
import 'package:fitapp/app/theme/app_theme.dart';
import 'package:fitapp/app/theme/tokens.dart';
import 'package:fitapp/core/format.dart';
import 'package:fitapp/core/haptics.dart';
import 'package:fitapp/data/providers.dart';
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
    final recent = stats?.recent.take(3).toList() ?? const [];

    Future<void> start() async {
      final repo = ref.read(workoutRepositoryProvider);
      final haptics = ref.read(hapticsProvider);
      final ok = await guard(context, repo.startWorkout);
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
                      'Started ${formatShortDuration(now.difference(active.startedAt))} ago',
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
