import 'dart:math' as math;

import 'package:fitapp/app/theme/tokens.dart';
import 'package:fitapp/core/format.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:material_ui/material_ui.dart';

/// Smooth line chart with glow, gradient fill and a highlighted last point.
class GlowLineChart extends StatelessWidget {
  /// Creates the chart.
  const new({
    super.key,
    required this.values,
    required this.color,
    this.format,
    this.labels,
  });

  /// Values, oldest first.
  final List<double> values;

  /// Line color.
  final Color color;

  /// Formats a value for tooltips and the semantic summary.
  final String Function(double)? format;

  /// Optional x labels, one per value.
  final List<String>? labels;

  static const _height = 200.0;
  static const _glowBlur = 8.0;
  static const _lineWidth = 3.0;
  static const _dotRadius = 6.0;
  static const _dotRing = 3.0;
  static const _fillAlpha = 0.35;
  static const _glowAlpha = 0.6;

  @override
  Widget build(BuildContext context) {
    final fmt = format ?? formatWeight;
    final text = Theme.of(context).textTheme;
    final n = values.length;
    final summary = n == 0
        ? 'no data'
        : '$n ${n == 1 ? 'point' : 'points'}, latest ${fmt(values.last)}, '
              'min ${fmt(values.reduce(math.min))}, '
              'max ${fmt(values.reduce(math.max))}';
    if (n == 0) {
      return Semantics(
        label: 'Chart: $summary',
        child: const SizedBox(height: _height),
      );
    }
    final lo = values.reduce(math.min);
    final hi = values.reduce(math.max);
    final pad = hi == lo ? math.max(hi.abs() * 0.1, 1) : (hi - lo) * 0.15;
    final lastIndex = n - 1;
    final showLabels = labels != null && labels!.length == n;

    return Semantics(
      container: true,
      label: 'Chart: $summary',
      child: ExcludeSemantics(
        child: SizedBox(
          height: _height,
          child: LineChart(
            LineChartData(
              minX: n == 1 ? -1 : 0,
              maxX: n == 1 ? 1 : lastIndex.toDouble(),
              minY: lo - pad,
              maxY: hi + pad,
              borderData: FlBorderData(show: false),
              gridData: FlGridData(
                drawVerticalLine: false,
                getDrawingHorizontalLine: (_) => const FlLine(
                  color: AppColors.surfaceHigh,
                  strokeWidth: Sizes.hairline,
                ),
              ),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(),
                rightTitles: const AxisTitles(),
                leftTitles: const AxisTitles(),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: showLabels,
                    reservedSize: Space.l,
                    interval: 1,
                    getTitlesWidget: (v, meta) {
                      final i = v.toInt();
                      if (!showLabels ||
                          v != i.toDouble() ||
                          i < 0 ||
                          i >= n ||
                          (n > 6 && i != 0 && i != lastIndex)) {
                        return const SizedBox.shrink();
                      }
                      return SideTitleWidget(
                        meta: meta,
                        child: Text(labels![i], style: text.labelSmall),
                      );
                    },
                  ),
                ),
              ),
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (_) => AppColors.surfaceHigh,
                  getTooltipItems: (spots) => [
                    for (final s in spots)
                      LineTooltipItem(
                        fmt(s.y),
                        TextStyle(color: color, fontWeight: FontWeight.w700),
                      ),
                  ],
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: [
                    for (var i = 0; i < n; i++)
                      FlSpot(n == 1 ? 0 : i.toDouble(), values[i]),
                  ],
                  isCurved: true,
                  preventCurveOverShooting: true,
                  color: color,
                  barWidth: _lineWidth,
                  isStrokeCapRound: true,
                  shadow: Shadow(
                    color: color.withValues(alpha: _glowAlpha),
                    blurRadius: _glowBlur,
                  ),
                  dotData: FlDotData(
                    checkToShowDot: (spot, _) =>
                        spot.x == (n == 1 ? 0 : lastIndex),
                    getDotPainter: (spot, percent, bar, index) =>
                        FlDotCirclePainter(
                          radius: _dotRadius,
                          color: color,
                          strokeWidth: _dotRing,
                          strokeColor: color.withValues(alpha: _fillAlpha),
                        ),
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        color.withValues(alpha: _fillAlpha),
                        color.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
