import 'package:fitapp/app/theme/text_styles.dart';
import 'package:fitapp/app/theme/tokens.dart';
import 'package:material_ui/material_ui.dart';

/// Wrap of tape-label chips with a single selection.
class ChipSelector<T> extends StatelessWidget {
  /// Creates a selector.
  const new({
    super.key,
    required this.options,
    required this.selected,
    required this.labelOf,
    required this.onSelected,
  });

  /// Choices.
  final List<T> options;

  /// Currently selected option.
  final T? selected;

  /// Label for an option.
  final String Function(T) labelOf;

  /// Called when an option is tapped.
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: Space.s,
      runSpacing: Space.s,
      children: [
        for (final o in options)
          _Chip(
            label: labelOf(o),
            isSelected: o == selected,
            onTap: () => onSelected(o),
          ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const new({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: isSelected,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: isSelected ? AppColors.accent : Colors.transparent,
        shape: RoundedRectangleBorder(
          side: isSelected
              ? BorderSide.none
              : const BorderSide(
                  color: AppColors.textTertiary,
                  width: Strokes.outline,
                ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: Sizes.tap,
              minWidth: Sizes.tap,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.m),
              child: Center(
                widthFactor: 1,
                child: Text(
                  label,
                  style: context.plate.tag(
                    color: isSelected
                        ? AppColors.onAccent
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
