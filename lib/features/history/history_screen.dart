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

/// Finished workouts grouped by month, newest first.
class HistoryScreen extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(historyProvider);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: history.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => const Center(
            child: Text(
              'Could not load history.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          data: (items) => items.isEmpty
              ? const EmptyState(
                  icon: Icons.history,
                  title: 'No workouts yet',
                  message: 'Finished workouts show up here.',
                )
              : _HistoryList(items: items),
        ),
      ),
    );
  }
}

class _HistoryList extends StatelessWidget {
  const new({required this.items});

  final List<WorkoutListItem> items;

  @override
  Widget build(BuildContext context) {
    final months = <String, List<WorkoutListItem>>{};
    for (final item in items) {
      months
          .putIfAbsent(formatMonth(item.startedAt.toLocal()), () => [])
          .add(item);
    }
    return ListView(
      padding: const EdgeInsets.all(Space.m),
      children: [
        Semantics(
          header: true,
          child: Text(
            'History',
            style: Theme.of(context).textTheme.headlineLarge,
          ),
        ),
        for (final entry in months.entries) ...[
          SectionHeader(entry.key),
          Group(children: [for (final item in entry.value) _Row(item: item)]),
        ],
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const new({required this.item});

  final WorkoutListItem item;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final date = formatDateShort(item.startedAt.toLocal());
    final exercises = item.exerciseNames.join(', ');
    final volume = formatVolume(item.volume);
    final sets =
        '${item.setCount} sets · '
        '${formatShortDuration(item.duration)}';
    return Semantics(
      button: true,
      label: '$date, $exercises, $volume, ${item.setCount} sets',
      excludeSemantics: true,
      child: InkWell(
        onTap: () => context.push(Routes.finishedWorkout(item.id)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: Sizes.tap + Space.xs),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Space.m,
              vertical: Space.s,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(date, style: text.bodyLarge),
                      Text(
                        exercises,
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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      volume,
                      style: text.bodyLarge?.copyWith(
                        color: context.metrics.volume,
                        fontFeatures: tabular,
                      ),
                    ),
                    Text(
                      sets,
                      style: text.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
