import 'package:fitapp/app/theme/app_theme.dart';
import 'package:fitapp/app/theme/text_styles.dart';
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
    final style = context.plate.tag().copyWith(fontFeatures: tabular);
    final d = delta;
    if (d == null) {
      return Text('—', style: style.copyWith(color: AppColors.textSecondary));
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
    final up = d.trend == Trend.up;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: up ? color : Colors.transparent,
        border: up
            ? null
            : Border.all(
                color: d.trend == Trend.down
                    ? AppColors.danger
                    : AppColors.textTertiary,
              ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Space.xs + Space.xxs,
          vertical: Space.xxs,
        ),
        child: Text(
          '$glyph$shown',
          style: style.copyWith(color: up ? AppColors.onAccent : c),
        ),
      ),
    );
  }
}
