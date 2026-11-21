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

  @override
  Widget build(BuildContext context) {
    const radius = BorderRadius.all(Radius.circular(Radii.card));
    final card = Material(
      color: AppColors.surface,
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
    if (!topRule) return card;
    return DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: topRuleColor, width: Strokes.cardTop),
        ),
      ),
      child: card,
    );
  }
}
