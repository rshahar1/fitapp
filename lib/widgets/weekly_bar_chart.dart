import 'dart:math' as math;

import 'package:fitapp/app/theme/tokens.dart';
import 'package:fitapp/domain/stats.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:material_ui/material_ui.dart';

/// Bar chart of workouts per Sunday-to-Saturday week. [counts] is keyed by
/// each week's Sunday, ordered oldest to current week; the last bar is
/// highlighted.
class WeeklyBarChart extends StatelessWidget {
  /// Creates the chart.
  const new({super.key, required this.counts});

  /// Workouts per week, keyed by the week's Sunday, oldest first.
  final Map<DateTime, int> counts;

  static const _height = 160.0;
  static const _barWidth = 16.0;

  @override
  Widget build(BuildContext context) {
    final entries = counts.entries.toList();
    final labels = weekBarLabels([for (final e in entries) e.key]);
    final maxCount = entries.fold<int>(0, (m, e) => math.max(m, e.value));
    final maxY = math.max(maxCount, 3) + 1;
    final interval = math.max(1, (maxY / 4).ceil()).toDouble();
    final text = Theme.of(context).textTheme.labelSmall;
    final summary = [
      for (var i = 0; i < entries.length; i++)
        '${labels[i]}: ${entries[i].value}',
    ].join(', ');

    return Semantics(
      container: true,
      label: 'Workouts per week, by week starting: $summary',
      child: ExcludeSemantics(
        child: SizedBox(
          height: _height,
          child: BarChart(
            BarChartData(
              maxY: maxY.toDouble(),
              minY: 0,
              alignment: BarChartAlignment.spaceAround,
              borderData: FlBorderData(show: false),
              gridData: FlGridData(
                drawVerticalLine: false,
                horizontalInterval: interval,
                getDrawingHorizontalLine: (_) => const FlLine(
                  color: AppColors.surfaceHigh,
                  strokeWidth: Sizes.hairline,
                ),
              ),
              barTouchData: const BarTouchData(enabled: false),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(),
                rightTitles: const AxisTitles(),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: interval,
                    reservedSize: Space.l,
                    getTitlesWidget: (v, meta) {
                      if (v != v.roundToDouble() || v > maxY - 1) {
                        return const SizedBox.shrink();
                      }
                      return SideTitleWidget(
                        meta: meta,
                        child: Text('${v.toInt()}', style: text),
                      );
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: Space.l,
                    getTitlesWidget: (v, meta) {
                      final i = v.toInt();
                      if (i < 0 || i >= labels.length) {
                        return const SizedBox.shrink();
                      }
                      return SideTitleWidget(
                        meta: meta,
                        child: Text(labels[i], style: text),
                      );
                    },
                  ),
                ),
              ),
              barGroups: [
                for (var i = 0; i < entries.length; i++)
                  BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: entries[i].value.toDouble(),
                        width: _barWidth,
                        color: i == entries.length - 1
                            ? AppColors.accent
                            : AppColors.surfaceHigh,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(Radii.chip),
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
