import 'package:fitapp/app/router.dart';
import 'package:fitapp/app/theme/app_icons.dart';
import 'package:fitapp/app/theme/app_theme.dart';
import 'package:fitapp/app/theme/text_styles.dart';
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
                  Text('Workouts per week', style: text.labelSmall),
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
            SectionHeader(
              'Exercises',
              trailing: TextButton(
                onPressed: () => context.push(Routes.exercises),
                child: const Text('All exercises'),
              ),
            ),
            trained.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => const Text('Could not load exercises.'),
              data: (items) => items.isEmpty
                  ? const EmptyState(
                      icon: AppIcons.chart,
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
    final current = item.currentWeight;
    final weight = current == null ? '—' : formatKg(current);
    final last = formatDateShort(item.lastTrained.toLocal());
    return Semantics(
      button: true,
      label: '${item.exercise.name}, last $last, weight $weight',
      excludeSemantics: true,
      child: GroupRow(
        title: item.exercise.name,
        subtitle: 'Last: $last',
        trailing: Text(
          weight,
          style: context.plate.number(20, color: context.metrics.weight),
        ),
        showChevron: true,
        onTap: () => context.push(Routes.exercise(item.exercise.id)),
      ),
    );
  }
}
