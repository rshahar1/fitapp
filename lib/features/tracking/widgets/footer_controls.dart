import 'package:fitapp/app/theme/text_styles.dart';
import 'package:fitapp/app/theme/tokens.dart';
import 'package:material_ui/material_ui.dart';

/// How long a [HoldButton] must be pressed.
const holdDuration = Duration(seconds: 1);

/// A 56 dp square button of the live footer.
class FooterButton extends StatelessWidget {
  const new({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.primary = false,
    this.iconOnly = false,
    super.key,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool primary;

  /// Square button without text.
  final bool iconOnly;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final fg = primary ? AppColors.onAccent : AppColors.textPrimary;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      onTap: onPressed,
      child: Opacity(
        opacity: enabled ? 1 : 0.4,
        child: Material(
          color: primary ? AppColors.accent : AppColors.surfaceHigh,
          shape: const RoundedRectangleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: SizedBox(
              height: Sizes.control,
              width: iconOnly ? Sizes.control : null,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: fg),
                  if (!iconOnly) ...[
                    const SizedBox(width: Space.s),
                    Flexible(
                      child: Text(
                        label,
                        overflow: TextOverflow.ellipsis,
                        style: context.plate.display(16, color: fg),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A footer button that fires [onCompleted] after being held for
/// [holdDuration], showing the progress as a fill. A short press only calls
/// [onShortPress] (the "hold to ..." hint).
class HoldButton extends StatefulWidget {
  const new({
    required this.label,
    required this.icon,
    required this.onCompleted,
    required this.onShortPress,
    this.iconOnly = false,
    this.color = AppColors.accent,
    super.key,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onCompleted;
  final VoidCallback onShortPress;

  /// Square button without text (the Lock toggle).
  final bool iconOnly;

  /// Colour of the icon and text.
  final Color color;

  @override
  State<HoldButton> createState() => _HoldButtonState();
}

class _HoldButtonState extends State<HoldButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _progress;
  bool _fired = false;

  @override
  void initState() {
    super.initState();
    _progress = AnimationController(vsync: this, duration: holdDuration)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed && !_fired) {
          _fired = true;
          widget.onCompleted?.call();
        }
      });
  }

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  void _down() {
    if (!mounted || widget.onCompleted == null) return;
    _fired = false;
    _progress.forward(from: 0);
  }

  void _up({required bool cancelled}) {
    // The button may have been replaced when the hold completed.
    if (!mounted || widget.onCompleted == null) return;
    final wasFired = _fired;
    _progress.reset();
    if (!wasFired && !cancelled) widget.onShortPress();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onCompleted != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      hint: 'Press and hold',
      excludeSemantics: true,
      onTap: enabled ? widget.onShortPress : null,
      onLongPress: widget.onCompleted,
      child: Opacity(
        opacity: enabled ? 1 : 0.4,
        child: Listener(
          onPointerDown: (_) => _down(),
          onPointerUp: (_) => _up(cancelled: false),
          onPointerCancel: (_) => _up(cancelled: true),
          child: Material(
            color: AppColors.surfaceHigh,
            shape: const RoundedRectangleBorder(),
            clipBehavior: Clip.antiAlias,
            child: SizedBox(
              height: Sizes.control,
              width: widget.iconOnly ? Sizes.control : null,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned.fill(
                    child: AnimatedBuilder(
                      animation: _progress,
                      builder: (_, _) => Align(
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: _progress.value,
                          heightFactor: 1,
                          child: const ColoredBox(color: AppColors.accentSoft),
                        ),
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(widget.icon, color: widget.color),
                      if (!widget.iconOnly) ...[
                        const SizedBox(width: Space.s),
                        Flexible(
                          child: Text(
                            widget.label,
                            overflow: TextOverflow.ellipsis,
                            style: context.plate.display(
                              16,
                              color: widget.color,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
