import 'package:fitapp/app/theme/tokens.dart';
import 'package:material_ui/material_ui.dart';

/// Opaque square surface card (feature 034). Primary cards carry a 4 dp
/// plate-yellow top rule ([topRule]).
class AppCard extends StatelessWidget {
  /// Creates a card.
  const new({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(Space.m),
    this.onTap,
    this.borderColor,
    this.topRule = false,
    this.topRuleColor = AppColors.accent,
    this.color = AppColors.surface,
    this.leftRule = false,
  });

  /// Content.
  final Widget child;

  /// Inner padding.
  final EdgeInsetsGeometry padding;

  /// Optional tap handler.
  final VoidCallback? onTap;

  /// Optional outline color.
  final Color? borderColor;

  /// Draws the 4 dp top rule of a primary card.
  final bool topRule;

  /// Color of the top rule.
  final Color topRuleColor;

  /// Fill.
  final Color color;

  /// Also draws the rule down the left edge (session in progress).
  final bool leftRule;

  @override
  Widget build(BuildContext context) {
    const radius = BorderRadius.all(Radius.circular(Radii.card));
    final card = Material(
      color: color,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: borderColor == null
            ? BorderSide.none
            : BorderSide(color: borderColor!, width: Strokes.outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
    if (!topRule && !leftRule) return card;
    final rule = BorderSide(color: topRuleColor, width: Strokes.cardTop);
    return DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        border: Border(
          top: topRule ? rule : BorderSide.none,
          left: leftRule ? rule : BorderSide.none,
        ),
      ),
      child: card,
    );
  }
}
