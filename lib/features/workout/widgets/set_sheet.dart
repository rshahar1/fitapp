import 'package:fitapp/app/theme/tokens.dart';
import 'package:fitapp/core/format.dart';
import 'package:fitapp/widgets/widgets.dart';
import 'package:material_ui/material_ui.dart';

/// What the set editor sheet returns.
sealed class SetSheetResult {
  const new();
}

class LogSetResult extends SetSheetResult {
  const new(this.weight, this.reps);
  final double weight;
  final int reps;
}

class ClearSetResult extends SetSheetResult {
  const new();
}

/// Bottom-sheet editor with big weight and reps steppers (PRD §2.3 rule 2).
Future<SetSheetResult?> showSetSheet(
  BuildContext context, {
  required String title,
  required double weight,
  required int reps,
  required double step,
  required bool isLogged,
  required bool perHand,
}) => showModalBottomSheet<SetSheetResult>(
  context: context,
  useSafeArea: true,
  isScrollControlled: true,
  builder: (_) => _SetSheet(
    title: title,
    weight: weight,
    reps: reps,
    step: step,
    isLogged: isLogged,
    perHand: perHand,
  ),
);

class _SetSheet extends StatefulWidget {
  const new({
    required this.title,
    required this.weight,
    required this.reps,
    required this.step,
    required this.isLogged,
    required this.perHand,
  });

  final String title;
  final double weight;
  final int reps;
  final double step;
  final bool isLogged;
  final bool perHand;

  @override
  State<_SetSheet> createState() => _SetSheetState();
}

class _SetSheetState extends State<_SetSheet> {
  late double _weight = widget.weight;
  late int _reps = widget.reps;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(Space.m, 0, Space.m, Space.l),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: Space.m),
        AppStepper(
          label: widget.perHand ? 'Weight (per hand)' : 'Weight',
          value: _weight,
          step: widget.step,
          unit: 'kg',
          format: formatWeight,
          onChanged: (v) => setState(() => _weight = v),
        ),
        const SizedBox(height: Space.m),
        AppStepper(
          label: 'Reps',
          value: _reps.toDouble(),
          step: 1,
          format: (v) => v.toInt().toString(),
          onChanged: (v) => setState(() => _reps = v.toInt()),
        ),
        const SizedBox(height: Space.l),
        AppButton(
          label: widget.isLogged ? 'Update' : 'Log set',
          expand: true,
          onPressed: () =>
              Navigator.of(context).pop(LogSetResult(_weight, _reps)),
        ),
        if (widget.isLogged) ...[
          const SizedBox(height: Space.s),
          AppButton(
            label: 'Clear set',
            variant: AppButtonVariant.danger,
            expand: true,
            onPressed: () => Navigator.of(context).pop(const ClearSetResult()),
          ),
        ],
      ],
    ),
  );
}
