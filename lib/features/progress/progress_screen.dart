import 'package:fitapp/app/router.dart';
import 'package:fitapp/app/theme/app_theme.dart';
import 'package:fitapp/app/theme/tokens.dart';
import 'package:fitapp/core/format.dart';
import 'package:fitapp/data/models.dart';
import 'package:fitapp/data/providers.dart';
import 'package:fitapp/widgets/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// Progress tab: workouts per week and the list of trained exercises.
class ProgressScreen extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final weekly = ref.watch(workoutsPerWeekProvider);
    final trained = ref.watch(trainedExercisesProvider);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.all(Space.m),
          children: [
            Semantics(
              header: true,
              child: Text('Progress', style: text.headlineLarge),
            ),
            const SizedBox(height: Space.m),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('WORKOUTS PER WEEK', style: text.labelSmall),
                  const SizedBox(height: Space.m),
                  weekly.when(
                    loading: () => const SizedBox(
                      height: Sizes.footer,
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (_, _) => const Text('Could not load chart.'),
                    data: (counts) => WeeklyBarChart(counts: counts),
                  ),
                ],
              ),
            ),
            const SectionHeader('Exercises'),
            trained.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => const Text('Could not load exercises.'),
              data: (items) => items.isEmpty
                  ? const EmptyState(
                      icon: Icons.show_chart,
                      title: 'Nothing trained yet',
                      message: 'Finish a workout to see your progress here.',
                    )
                  : Group(
                      children: [for (final t in items) _ExerciseRow(item: t)],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExerciseRow extends StatelessWidget {
  const new({required this.item});

  final TrainedExercise item;

  @override
  Widget build(BuildContext context) {
    final plan = item.plan;
    final weight = plan == null ? '—' : formatKg(plan.baseWeight);
    final last = formatDateShort(item.lastTrained.toLocal());
    return Semantics(
      button: true,
      label: '${item.exercise.name}, last $last, base $weight',
      excludeSemantics: true,
      child: GroupRow(
        title: item.exercise.name,
        subtitle: 'Last: $last',
        trailing: Text(
          weight,
          style: Theme.of(context).textTheme.bodyLarge
              ?.copyWith(color: context.metrics.weight, fontFeatures: tabular),
        ),
        showChevron: true,
        onTap: () => context.push(Routes.exercise(item.exercise.id)),
      ),
    );
  }
}
