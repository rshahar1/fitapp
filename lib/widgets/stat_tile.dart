import 'package:fitapp/app/theme/text_styles.dart';
import 'package:fitapp/app/theme/tokens.dart';
import 'package:material_ui/material_ui.dart';

/// Compact number + label for header bars.
class StatTile extends StatelessWidget {
  /// Creates a tile.
  const new({super.key, required this.value, required this.label, this.color});

  /// Value text.
  final String value;

  /// Label text.
  final String label;

  /// Value color.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Semantics(
      label: '$label: $value',
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: context.plate.number(
              24,
              color: color ?? AppColors.textPrimary,
            ),
          ),
          Text(label, style: text.labelSmall),
        ],
      ),
    );
  }
}
