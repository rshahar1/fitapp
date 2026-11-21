import 'package:fitapp/app/theme/text_styles.dart';
import 'package:fitapp/app/theme/tokens.dart';
import 'package:fitapp/widgets/app_card.dart';
import 'package:material_ui/material_ui.dart';

/// Small card with a label and a big colored value.
class MetricTile extends StatelessWidget {
  /// Creates a tile.
  const new({
    super.key,
    required this.label,
    required this.value,
    this.color,
    this.caption,
  });

  /// Label (the display face draws capitals).
  final String label;

  /// Value text.
  final String value;

  /// Value color.
  final Color? color;

  /// Optional caption under the value.
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Semantics(
      container: true,
      label: '$label: $value${caption == null ? '' : ', $caption'}',
      excludeSemantics: true,
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: text.labelSmall),
            const SizedBox(height: Space.xs),
            Text(
              value,
              style: context.plate.number(
                32,
                color: color ?? AppColors.textPrimary,
              ),
            ),
            if (caption != null)
              Text(
                caption!,
                style: text.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
          ],
        ),
      ),
    );
  }
}
