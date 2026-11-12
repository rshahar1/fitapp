import 'package:fitapp/app/theme/app_theme.dart';
import 'package:fitapp/app/theme/tokens.dart';
import 'package:fitapp/domain/stats.dart';
import 'package:material_ui/material_ui.dart';

/// Shows a [MetricDelta] as "▲ 11.1%" / "▼ 5.6%" / "– 0%".
class DeltaBadge extends StatelessWidget {
  /// Creates a badge.
  const new({super.key, required this.delta, required this.color});

  /// The delta, or null when unavailable.
  final MetricDelta? delta;

  /// Color for an increase.
  final Color color;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelMedium
        ?.copyWith(fontWeight: FontWeight.w700, fontFeatures: tabular);
    final d = delta;
    if (d == null) {
      return Text('—', style: style?.copyWith(color: AppColors.textSecondary));
    }
    final pct = d.percent;
    final number = pct == null
        ? ''
        : ' ${pct.abs() == pct.abs().roundToDouble() ? pct.abs().toInt() : pct.abs()}%';
    final (glyph, c) = switch (d.trend) {
      Trend.up => ('▲', color),
      Trend.down => ('▼', AppColors.danger),
      Trend.same => ('–', AppColors.textSecondary),
    };
    final shown = d.trend == Trend.same && pct == null ? ' 0%' : number;
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: glyph,
            style: TextStyle(color: c),
          ),
          TextSpan(
            text: shown,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
      style: style,
    );
  }
}
