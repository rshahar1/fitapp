import 'package:fitapp/app/theme/text_styles.dart';
import 'package:fitapp/app/theme/tokens.dart';
import 'package:material_ui/material_ui.dart';

/// Visual style of an [AppButton].
enum AppButtonVariant {
  /// Plate-yellow fill: start something.
  primary,

  /// Outlined chalk rectangle.
  secondary,

  /// Destructive.
  danger,

  /// Transparent, accent text.
  ghost,

  /// Deep plate-red fill: continue a session in progress (feature 022).
  live,
}

/// Rectangular button with a capitals display label (Iron plate).
class AppButton extends StatelessWidget {
  /// Creates a button.
  const new({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.variant = AppButtonVariant.primary,
    this.expand = false,
  });

  /// Text (the display face draws capitals).
  final String label;

  /// Tap callback; null disables the button.
  final VoidCallback? onPressed;

  /// Optional leading icon.
  final IconData? icon;

  /// Style.
  final AppButtonVariant variant;

  /// Fill the available width.
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (variant) {
      AppButtonVariant.primary => (AppColors.accent, AppColors.onAccent),
      AppButtonVariant.secondary => (Colors.transparent, AppColors.textPrimary),
      AppButtonVariant.danger => (Colors.transparent, AppColors.danger),
      AppButtonVariant.live => (AppColors.liveFill, AppColors.onLive),
      AppButtonVariant.ghost => (Colors.transparent, AppColors.accent),
    };
    final outlined =
        variant == AppButtonVariant.secondary ||
        variant == AppButtonVariant.danger;
    final enabled = onPressed != null;
    final button = TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        backgroundColor: bg,
        foregroundColor: fg,
        disabledBackgroundColor: bg,
        disabledForegroundColor: fg,
        minimumSize: const Size(Sizes.tap, Sizes.stepperHeight - Space.s),
        padding: const EdgeInsets.symmetric(horizontal: Space.l),
        shape: RoundedRectangleBorder(
          side: outlined
              ? BorderSide(
                  color: variant == AppButtonVariant.danger
                      ? AppColors.danger
                      : AppColors.textSecondary,
                  width: Strokes.outline,
                )
              : BorderSide.none,
        ),
        tapTargetSize: MaterialTapTargetSize.padded,
      ),
      child: Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[Icon(icon), const SizedBox(width: Space.s)],
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: context.plate.display(17, color: fg),
            ),
          ),
        ],
      ),
    );
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      onTap: onPressed,
      child: Opacity(
        opacity: enabled ? 1 : 0.4,
        child: expand
            ? SizedBox(width: double.infinity, child: button)
            : button,
      ),
    );
  }
}
