import 'package:fitapp/app/theme/app_theme.dart';
import 'package:fitapp/app/theme/tokens.dart';
import 'package:fitapp/core/format.dart';
import 'package:fitapp/core/haptics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// Label, big value and minus/plus buttons.
class AppStepper extends ConsumerWidget {
  /// Creates a stepper.
  const new({
    super.key,
    required this.label,
    required this.value,
    required this.step,
    required this.onChanged,
    this.format,
    this.min = 0,
    this.max,
    this.unit,
  });

  /// Label above the value.
  final String label;

  /// Current value.
  final double value;

  /// Increment per tap.
  final double step;

  /// Called with the new value.
  final ValueChanged<double> onChanged;

  /// Value formatter (defaults to [formatWeight]).
  final String Function(double)? format;

  /// Lower bound.
  final double min;

  /// Optional upper bound.
  final double? max;

  /// Optional unit shown after the value.
  final String? unit;

  void _change(WidgetRef ref, double delta) {
    var next = value + delta;
    if (next < min) next = min;
    if (max != null && next > max!) next = max!;
    if (next == value) return;
    ref.read(hapticsProvider).tick();
    onChanged(next);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final shown = (format ?? formatWeight)(value);
    final canDec = value > min;
    final canInc = max == null || value < max!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label.toUpperCase(), style: text.labelSmall),
        const SizedBox(height: Space.s),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _StepButton(
              icon: Icons.remove,
              semanticLabel: 'Decrease $label',
              onPressed: canDec ? () => _change(ref, -step) : null,
            ),
            Expanded(
              child: Semantics(
                label: label,
                value: unit == null ? shown : '$shown $unit',
                excludeSemantics: true,
                child: Text(
                  unit == null ? shown : '$shown $unit',
                  textAlign: TextAlign.center,
                  style: text.headlineMedium?.copyWith(fontFeatures: tabular),
                ),
              ),
            ),
            _StepButton(
              icon: Icons.add,
              semanticLabel: 'Increase $label',
              onPressed: canInc ? () => _change(ref, step) : null,
            ),
          ],
        ),
      ],
    );
  }
}

class _StepButton extends StatelessWidget {
  const new({
    required this.icon,
    required this.semanticLabel,
    required this.onPressed,
  });

  final IconData icon;
  final String semanticLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: semanticLabel,
      excludeSemantics: true,
      onTap: onPressed,
      child: Material(
        color: AppColors.surfaceHigh,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(Radii.chip)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: SizedBox(
            width: Sizes.stepperWidth,
            height: Sizes.stepperHeight,
            child: Icon(
              icon,
              color: onPressed == null
                  ? AppColors.textTertiary
                  : AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
