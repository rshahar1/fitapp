import 'package:fitapp/app/theme/tokens.dart';
import 'package:material_ui/material_ui.dart';

/// Visual style of an [AppButton].
enum AppButtonVariant {
  /// Green accent: start something.
  primary,

  /// Neutral raised surface.
  secondary,

  /// Destructive.
  danger,

  /// Transparent, accent text.
  ghost,

  /// Amber: continue a session in progress (feature 022).
  live,
}

/// Pill-shaped bold uppercase button.
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

  /// Text (rendered uppercase).
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
      AppButtonVariant.secondary => (
        AppColors.surfaceHigh,
        AppColors.textPrimary,
      ),
      AppButtonVariant.danger => (AppColors.surfaceHigh, AppColors.danger),
      AppButtonVariant.live => (AppColors.live, AppColors.onAccent),
      AppButtonVariant.ghost => (const Color(0x00000000), AppColors.accent),
    };
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
        shape: const StadiumBorder(),
        tapTargetSize: MaterialTapTargetSize.padded,
      ),
      child: Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[Icon(icon), const SizedBox(width: Space.s)],
          Flexible(
            child: Text(
              label.toUpperCase(),
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
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
