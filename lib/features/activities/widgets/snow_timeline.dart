import 'package:fitapp/app/theme/tokens.dart';
import 'package:fitapp/core/format.dart' show formatClock;
import 'package:fitapp/domain/activity_types.dart'
    show formatDistanceKm, formatMetersGrouped, formatSpeedKmh;
import 'package:fitapp/domain/tracking/snow_review.dart';
import 'package:fitapp/domain/tracking/snow_state.dart';
import 'package:fitapp/domain/tracking/snow_summary.dart';
import 'package:fitapp/widgets/widgets.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

/// The label of [badge].
String snowBadgeLabel(RunBadge badge) => switch (badge) {
  RunBadge.fastest => 'Fastest',
  RunBadge.longest => 'Longest',
  RunBadge.mostVertical => 'Most vertical',
};

/// Small pill naming a badge a run earned.
class SnowBadgeChip extends StatelessWidget {
  const new({required this.badge, super.key});

  final RunBadge badge;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.accentSoft,
        borderRadius: BorderRadius.circular(Radii.chip),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Space.s,
          vertical: Space.xs / 2,
        ),
        child: Text(
          snowBadgeLabel(badge),
          style: Theme.of(context).textTheme.labelSmall
              ?.copyWith(color: AppColors.accent),
        ),
      ),
    );
  }
}

/// The badges of a run in a stable order.
List<RunBadge> sortedBadges(Set<RunBadge>? badges) => [
  for (final b in RunBadge.values)
    if (badges?.contains(b) ?? false) b,
];

/// Every counted run and every lift of a snowboarding day in time order
/// (feature 017).
class SnowTimeline extends StatelessWidget {
  const new({
    required this.startedAt,
    required this.records,
    required this.onReplay,
    super.key,
  });

  /// When the activity started (any zone; shown in local time).
  final DateTime startedAt;
  final List<SnowRecord> records;

  /// Called when a run row is tapped.
  final ValueChanged<SnowDescent> onReplay;

  @override
  Widget build(BuildContext context) {
    final descents = snowDescents(records);
    final badges = snowBadges(descents);
    final local = startedAt.toLocal();
    String clock(int seconds) =>
        DateFormat('HH:mm').format(local.add(Duration(seconds: seconds)));
    // (start, row) pairs so runs and lifts interleave in time order.
    final rows = <(int, Widget)>[
      for (final d in descents)
        (
          d.startSeconds,
          _TimelineRow(
            title: 'Run ${d.number}',
            badges: sortedBadges(badges[d.number]),
            details: [
              clock(d.startSeconds),
              formatClock(Duration(seconds: d.durationSeconds)),
              '${formatMetersGrouped(d.dropMeters)} ↓',
              formatDistanceKm(d.distanceMeters),
              formatSpeedKmh(d.maxSpeedMps),
            ],
            onTap: () => onReplay(d),
          ),
        ),
      for (final r in records)
        if (r.kind == SnowKind.lift)
          (
            r.startSeconds,
            _TimelineRow(
              title: 'Lift',
              badges: const [],
              details: [
                clock(r.startSeconds),
                formatClock(Duration(seconds: r.durationSeconds)),
                '${formatMetersGrouped(r.verticalMeters)} ↑',
              ],
            ),
          ),
    ]..sort((a, b) => a.$1.compareTo(b.$1));
    return Group(children: [for (final r in rows) r.$2]);
  }
}

class _TimelineRow extends StatelessWidget {
  const new({
    required this.title,
    required this.badges,
    required this.details,
    this.onTap,
  });

  final String title;
  final List<RunBadge> badges;
  final List<String> details;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final isRun = onTap != null;
    return Semantics(
      container: true,
      button: isRun,
      label:
          '$title, ${details.join(', ')}'
          '${badges.isEmpty ? '' : ', ${badges.map(snowBadgeLabel).join(', ')}'}',
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: Sizes.tap + Space.xs),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Space.m,
              vertical: Space.s,
            ),
            child: Row(
              children: [
                Icon(
                  isRun ? Icons.downhill_skiing : Icons.cable,
                  size: 20,
                  color: isRun ? AppColors.accent : AppColors.routeLift,
                ),
                const SizedBox(width: Space.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Wrap(
                        spacing: Space.s,
                        runSpacing: Space.xs,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(title, style: text.bodyLarge),
                          for (final b in badges) SnowBadgeChip(badge: b),
                        ],
                      ),
                      Text(
                        details.join(' · '),
                        style: text.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isRun)
                  const Icon(
                    Icons.chevron_right,
                    color: AppColors.textTertiary,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
