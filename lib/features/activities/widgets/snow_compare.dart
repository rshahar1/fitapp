import 'package:fitapp/app/theme/app_theme.dart';
import 'package:fitapp/app/theme/tokens.dart';
import 'package:fitapp/core/format.dart' show formatClock;
import 'package:fitapp/domain/activity_types.dart'
    show formatDistanceKm, formatMetersGrouped, formatSpeedKmh;
import 'package:fitapp/domain/tracking/snow_review.dart';
import 'package:fitapp/domain/tracking/snow_summary.dart';
import 'package:fitapp/features/activities/widgets/snow_timeline.dart';
import 'package:fitapp/widgets/widgets.dart';
import 'package:material_ui/material_ui.dart';

/// Compares the runs of a day by one metric as bars (feature 017). Shown
/// for two or more runs.
class SnowCompare extends StatefulWidget {
  const new({required this.descents, required this.onReplay, super.key});

  final List<SnowDescent> descents;

  /// Called when a run row is tapped.
  final ValueChanged<SnowDescent> onReplay;

  @override
  State<SnowCompare> createState() => _SnowCompareState();
}

class _SnowCompareState extends State<SnowCompare> {
  RunMetric _metric = RunMetric.maxSpeed;
  bool _bestFirst = true;

  static String _metricLabel(RunMetric m) => switch (m) {
    RunMetric.maxSpeed => 'Max speed',
    RunMetric.avgSpeed => 'Avg speed',
    RunMetric.vertical => 'Vertical',
    RunMetric.distance => 'Distance',
    RunMetric.duration => 'Duration',
  };

  String _format(SnowDescent d) => switch (_metric) {
    RunMetric.maxSpeed => formatSpeedKmh(d.maxSpeedMps),
    RunMetric.avgSpeed => formatSpeedKmh(d.avgSpeedMps),
    RunMetric.vertical => formatMetersGrouped(d.dropMeters),
    RunMetric.distance => formatDistanceKm(d.distanceMeters),
    RunMetric.duration => formatClock(Duration(seconds: d.durationSeconds)),
  };

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final ordered = compareRuns(widget.descents, _metric, byMetric: _bestFirst);
    final badges = snowBadges(widget.descents);
    var max = 0.0;
    for (final d in widget.descents) {
      final v = runMetricValue(d, _metric);
      if (v > max) max = v;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Compare runs', style: text.titleMedium),
        const SizedBox(height: Space.s),
        ChipSelector<RunMetric>(
          options: RunMetric.values,
          selected: _metric,
          labelOf: _metricLabel,
          onSelected: (m) => setState(() => _metric = m),
        ),
        const SizedBox(height: Space.s),
        ChipSelector<bool>(
          options: const [true, false],
          selected: _bestFirst,
          labelOf: (b) => b ? 'Best first' : 'By time',
          onSelected: (b) => setState(() => _bestFirst = b),
        ),
        const SizedBox(height: Space.s),
        Group(
          children: [
            for (final d in ordered)
              _CompareRow(
                descent: d,
                fraction: max > 0 ? runMetricValue(d, _metric) / max : 0,
                value: _format(d),
                badges: sortedBadges(badges[d.number]),
                onTap: () => widget.onReplay(d),
              ),
          ],
        ),
      ],
    );
  }
}

class _CompareRow extends StatelessWidget {
  const new({
    required this.descent,
    required this.fraction,
    required this.value,
    required this.badges,
    required this.onTap,
  });

  final SnowDescent descent;
  final double fraction;
  final String value;
  final List<RunBadge> badges;
  final VoidCallback onTap;

  /// Narrowest visible bar.
  static const _minBar = Space.s;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Semantics(
      container: true,
      button: true,
      label:
          'Run ${descent.number}, $value'
          '${badges.isEmpty ? '' : ', ${badges.map(snowBadgeLabel).join(', ')}'}',
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: Sizes.tap),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Space.m,
              vertical: Space.s,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    SizedBox(
                      width: Space.xxl,
                      child: Text(
                        'Run ${descent.number}',
                        style: text.bodyMedium,
                      ),
                    ),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, c) => Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            height: Space.m,
                            width: (c.maxWidth * fraction).clamp(
                              _minBar,
                              c.maxWidth,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.accent,
                              borderRadius: BorderRadius.circular(Radii.chip),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: Space.m),
                    Text(
                      value,
                      style: text.bodyLarge?.copyWith(fontFeatures: tabular),
                    ),
                  ],
                ),
                if (badges.isNotEmpty) ...[
                  const SizedBox(height: Space.xs),
                  Wrap(
                    spacing: Space.s,
                    children: [for (final b in badges) SnowBadgeChip(badge: b)],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
