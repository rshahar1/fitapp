import 'package:fitapp/app/router.dart';
import 'package:fitapp/app/theme/app_theme.dart';
import 'package:fitapp/app/theme/tokens.dart';
import 'package:fitapp/core/format.dart';
import 'package:fitapp/data/db/app_database.dart';
import 'package:fitapp/data/models.dart';
import 'package:fitapp/domain/activity_types.dart';
import 'package:fitapp/features/activities/activity_icons.dart';
import 'package:fitapp/features/activities/activity_sheet.dart';
import 'package:fitapp/widgets/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// Row for any history entry (workout or activity).
class HistoryEntryRow extends StatelessWidget {
  /// Creates a row.
  const new({super.key, required this.entry});

  /// Entry shown.
  final HistoryEntry entry;

  @override
  Widget build(BuildContext context) => switch (entry) {
    WorkoutHistoryEntry(:final workout) => HistoryWorkoutRow(item: workout),
    ActivityHistoryEntry(:final activity) => HistoryActivityRow(
      activity: activity,
    ),
  };
}

class HistoryIconBadge extends StatelessWidget {
  const new({
    super.key,
    required this.icon,
    required this.color,
    required this.bg,
  });

  final IconData icon;
  final Color color;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: Sizes.tap - Space.s,
      height: Sizes.tap - Space.s,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(Radii.chip),
      ),
      child: Icon(icon, size: 22, color: color),
    );
  }
}

class HistoryActivityRow extends StatelessWidget {
  const new({super.key, required this.activity});

  final ActivityRow activity;

  @override
  Widget build(BuildContext context) {
    final date = formatDateShort(activity.startedAt.toLocal());
    final label = activityLabel(activity.typeId);
    final minutes = activity.durationMinutes;
    final meters = activity.distanceMeters;
    final note = activity.notes;
    final subtitle = [
      label,
      if (meters != null) formatDistanceKm(meters),
      if (minutes != null) formatActivityMinutes(minutes),
      if (meters != null && minutes != null)
        ?switch (activity.typeId) {
          'running' => formatPace(meters, minutes),
          'cycling' => formatSpeed(meters, minutes),
          _ => null,
        },
      ?note,
    ].join(' · ');
    return Semantics(
      button: true,
      label: '$date, $subtitle',
      excludeSemantics: true,
      child: GroupRow(
        leading: HistoryIconBadge(
          icon: activityIcon(activity.typeId),
          color: context.metrics.volume,
          bg: AppColors.surfaceHigh,
        ),
        title: date,
        subtitle: subtitle,
        showChevron: true,
        onTap: () => showActivitySheet(context, existing: activity),
      ),
    );
  }
}

class HistoryWorkoutRow extends StatelessWidget {
  const new({super.key, required this.item});

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
                const HistoryIconBadge(
                  icon: gymWorkoutIcon,
                  color: AppColors.accent,
                  bg: AppColors.accentSoft,
                ),
                const SizedBox(width: Space.m),
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
