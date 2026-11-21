import 'package:fitapp/app/theme/app_icons.dart';
import 'package:fitapp/app/theme/text_styles.dart';
import 'package:fitapp/app/theme/tokens.dart';
import 'package:fitapp/core/format.dart';
import 'package:fitapp/core/haptics.dart';
import 'package:fitapp/widgets/app_button.dart';
import 'package:fitapp/widgets/chip_selector.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

const _presets = [15, 30, 45, 60, 90, 120, 180, 240];

/// Label, -5/+5 buttons around a tappable value, preset chips and a wheel
/// sheet for picking hours and minutes.
class DurationPicker extends ConsumerWidget {
  /// Creates a duration picker.
  const new({
    super.key,
    required this.minutes,
    required this.onChanged,
    required this.max,
    this.min = 5,
    this.label = 'Duration',
  });

  /// Current duration in minutes.
  final int minutes;

  /// Called with the new duration in minutes.
  final ValueChanged<int> onChanged;

  /// Lower bound in minutes.
  final int min;

  /// Upper bound in minutes.
  final int max;

  /// Label above the value.
  final String label;

  void _set(WidgetRef ref, int value) {
    final next = value.clamp(min, max);
    if (next == minutes) return;
    ref.read(hapticsProvider).tick();
    onChanged(next);
  }

  Future<void> _openWheels(BuildContext context, WidgetRef ref) async {
    final result = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (_) => _WheelSheet(minutes: minutes, min: min, max: max),
    );
    if (result != null) _set(ref, result);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final shown = formatActivityMinutes(minutes);
    final canDec = minutes > min;
    final canInc = minutes < max;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: text.labelSmall),
        const SizedBox(height: Space.s),
        Row(
          children: [
            _StepButton(
              icon: AppIcons.remove,
              semanticLabel: 'Decrease $label',
              onPressed: canDec ? () => _set(ref, minutes - 5) : null,
            ),
            Expanded(
              child: Semantics(
                button: true,
                label: '$label, $shown. Tap to choose',
                excludeSemantics: true,
                onTap: () => _openWheels(context, ref),
                child: Tooltip(
                  message: '$label, $shown. Tap to choose',
                  child: InkWell(
                    key: const Key('duration-value'),
                    onTap: () => _openWheels(context, ref),
                    child: SizedBox(
                      height: Sizes.stepperHeight,
                      child: Center(
                        child: Text(
                          shown,
                          textAlign: TextAlign.center,
                          style: context.plate.number(34),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            _StepButton(
              icon: AppIcons.add,
              semanticLabel: 'Increase $label',
              onPressed: canInc ? () => _set(ref, minutes + 5) : null,
            ),
          ],
        ),
        const SizedBox(height: Space.s),
        Align(
          alignment: Alignment.centerLeft,
          child: ChipSelector<int>(
            options: [
              for (final p in _presets)
                if (p >= min && p <= max) p,
            ],
            selected: minutes,
            labelOf: _presetLabel,
            onSelected: (v) => _set(ref, v),
          ),
        ),
      ],
    );
  }
}

String _presetLabel(int m) {
  if (m < 60) return '$m min';
  final h = m ~/ 60;
  final r = m % 60;
  return r == 0 ? '$h h' : '$h h $r';
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
        shape: const RoundedRectangleBorder(),
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

class _WheelSheet extends StatefulWidget {
  const new({required this.minutes, required this.min, required this.max});

  final int minutes;
  final int min;
  final int max;

  @override
  State<_WheelSheet> createState() => _WheelSheetState();
}

class _WheelSheetState extends State<_WheelSheet> {
  static const _itemExtent = 44.0;
  late int _hours = (widget.minutes ~/ 60).clamp(0, widget.max ~/ 60);
  late int _mins = (widget.minutes % 60) ~/ 5 * 5;
  late final FixedExtentScrollController _hoursCtrl =
      FixedExtentScrollController(initialItem: _hours);
  late final FixedExtentScrollController _minsCtrl =
      FixedExtentScrollController(initialItem: _mins ~/ 5);

  @override
  void dispose() {
    _hoursCtrl.dispose();
    _minsCtrl.dispose();
    super.dispose();
  }

  int get _total => (_hours * 60 + _mins).clamp(widget.min, widget.max);

  Widget _wheel({
    required Key key,
    required FixedExtentScrollController controller,
    required int count,
    required String Function(int) text,
    required String unit,
    required ValueChanged<int> onSelected,
  }) {
    final style = context.plate.number(28);
    return Expanded(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 64,
            child: ListWheelScrollView.useDelegate(
              key: key,
              controller: controller,
              itemExtent: _itemExtent,
              physics: const FixedExtentScrollPhysics(),
              onSelectedItemChanged: (i) {
                onSelected(i);
              },
              childDelegate: ListWheelChildBuilderDelegate(
                childCount: count,
                builder: (context, i) =>
                    Center(child: Text(text(i), style: style)),
              ),
            ),
          ),
          const SizedBox(width: Space.s),
          Text(unit, style: Theme.of(context).textTheme.labelLarge),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final maxHours = widget.max ~/ 60;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(Space.l),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 180,
              child: Row(
                children: [
                  _wheel(
                    key: const Key('duration-hours-wheel'),
                    controller: _hoursCtrl,
                    count: maxHours + 1,
                    text: (i) => '$i',
                    unit: 'h',
                    onSelected: (i) => setState(() => _hours = i),
                  ),
                  _wheel(
                    key: const Key('duration-minutes-wheel'),
                    controller: _minsCtrl,
                    count: 12,
                    text: (i) => '${i * 5}',
                    unit: 'min',
                    onSelected: (i) => setState(() => _mins = i * 5),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Space.m),
            AppButton(
              label: 'Done',
              onPressed: () => Navigator.of(context).pop(_total),
            ),
          ],
        ),
      ),
    );
  }
}
