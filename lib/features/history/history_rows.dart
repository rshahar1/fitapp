import 'package:fitapp/app/router.dart';
import 'package:fitapp/app/theme/app_icons.dart';
import 'package:fitapp/app/theme/app_theme.dart';
import 'package:fitapp/app/theme/text_styles.dart';
import 'package:fitapp/app/theme/tokens.dart';
import 'package:fitapp/core/format.dart';
import 'package:fitapp/data/db/app_database.dart';
import 'package:fitapp/data/models.dart';
import 'package:fitapp/domain/activity_types.dart';
import 'package:fitapp/features/activities/activity_icons.dart';
import 'package:fitapp/widgets/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// Row for any history entry (workout or activity).
class HistoryEntryRow extends StatelessWidget {
  /// Creates a row.
  const new({super.key, required this.entry, this.compact = false});

  /// Entry shown.
  final HistoryEntry entry;

  /// Whether gym workouts show only date and template name (Home's Recent).
  final bool compact;

  @override
  Widget build(BuildContext context) => switch (entry) {
    WorkoutHistoryEntry(:final workout) =>
      compact
          ? HistoryWorkoutCompactRow(item: workout)
          : HistoryWorkoutRow(item: workout),
    ActivityHistoryEntry(:final activity) => HistoryActivityRow(
      activity: activity,
    ),
  };
}

/// Leading badge of a History row: the workout or activity-type icon in the
/// accent colour on a soft accent tile, the same icons and colour as the
/// History calendar (feature 022).
class HistoryIconBadge extends StatelessWidget {
  /// Creates a badge for a Material [icon] or an activity [typeId].
  const new({super.key, this.icon, this.typeId})
    : assert(
        icon != null || typeId != null,
        'HistoryIconBadge needs an icon or a typeId',
      );

  /// Material icon (gym workouts).
  final IconData? icon;

  /// Activity type id; rendered with [ActivityIcon] when [icon] is null.
  final String? typeId;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: Sizes.tap - Space.s,
      height: Sizes.tap - Space.s,
      decoration: const BoxDecoration(color: AppColors.accentSoft),
      child: icon != null
          ? Icon(icon, size: 22, color: AppColors.accent)
          : ActivityIcon(typeId!, size: 22, color: AppColors.accent),
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
    final runs = activity.runCount;
    final drop = activity.verticalDropMeters;
    final snow =
        activity.typeId == 'snowboarding' &&
        activity.source == 'gps' &&
        runs != null &&
        drop != null;
    final subtitle = [
      label,
      if (snow) ...[
        if (runs == 1) '1 run' else '$runs runs',
        '${formatMetersGrouped(drop)} ↓',
      ] else ...[
        if (meters != null) formatDistanceKm(meters),
      ],
      if (minutes != null) formatActivityMinutes(minutes),
      if (!snow && meters != null && minutes != null)
        ?switch (activity.typeId) {
          'running' => formatPace(meters, minutes),
          'cycling' => formatSpeed(meters, minutes),
          _ => null,
        },
      ?note,
    ].join(' · ');
    final isGps = activity.source == 'gps';
    return Semantics(
      button: true,
      label: '$date, $subtitle${isGps ? ', GPS tracked' : ''}',
      excludeSemantics: true,
      child: GroupRow(
        leading: HistoryIconBadge(typeId: activity.typeId),
        title: date,
        subtitle: subtitle,
        trailing: isGps
            ? const Icon(
                AppIcons.locationOn,
                size: 16,
                color: AppColors.textSecondary,
              )
            : null,
        showChevron: true,
        onTap: () => context.push(Routes.activity(activity.id)),
      ),
    );
  }
}

/// Compact gym workout row: date and template name only.
class HistoryWorkoutCompactRow extends StatelessWidget {
  const new({super.key, required this.item});

  final WorkoutListItem item;

  @override
  Widget build(BuildContext context) {
    final date = formatDateShort(item.startedAt.toLocal());
    final name = item.templateName ?? 'Workout';
    return Semantics(
      button: true,
      label: '$date, $name',
      excludeSemantics: true,
      child: GroupRow(
        leading: const HistoryIconBadge(icon: gymWorkoutIcon),
        title: date,
        subtitle: name,
        showChevron: true,
        onTap: () => context.push(Routes.finishedWorkout(item.id)),
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
                const HistoryIconBadge(icon: gymWorkoutIcon),
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
                      style: context.plate.number(
                        20,
                        color: context.metrics.volume,
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
