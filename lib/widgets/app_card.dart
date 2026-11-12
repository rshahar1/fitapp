import 'package:fitapp/app/theme/tokens.dart';
import 'package:material_ui/material_ui.dart';

/// Opaque rounded surface card.
class AppCard extends StatelessWidget {
  /// Creates a card.
  const new({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(Space.m),
    this.onTap,
    this.borderColor,
  });

  /// Content.
  final Widget child;

  /// Inner padding.
  final EdgeInsetsGeometry padding;

  /// Optional tap handler.
  final VoidCallback? onTap;

  /// Optional outline color.
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    const radius = BorderRadius.all(Radius.circular(Radii.card));
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: borderColor == null
            ? BorderSide.none
            : BorderSide(color: borderColor!),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}
