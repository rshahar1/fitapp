import 'package:fitapp/app/theme/tokens.dart';
import 'package:fitapp/core/format.dart';
import 'package:fitapp/core/haptics.dart';
import 'package:fitapp/data/db/app_database.dart';
import 'package:fitapp/data/models.dart';
import 'package:fitapp/data/providers.dart';
import 'package:fitapp/data/repositories/settings_repository.dart';
import 'package:fitapp/widgets/guard.dart';
import 'package:fitapp/widgets/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

const incrementOptions = [1.0, 2.0, 2.5, 5.0];

/// Saves a plan wherever it lives (an exercise's own plan, a template plan,
/// or a template editor draft).
typedef PlanSubmit = Future<void> Function(StoredPlan plan);

/// Plan editor used by the inline plan setup card, the Edit plan sheet and
/// the template editor (PRD §5.2, §5.7). Storage-agnostic: [onSubmit] saves.
class PlanForm extends ConsumerStatefulWidget {
  const new({
    required this.exercise,
    required this.submitLabel,
    required this.onSubmit,
    this.initial,
    this.onSaved,
    super.key,
  });

  final ExerciseRow exercise;
  final StoredPlan? initial;
  final String submitLabel;
  final PlanSubmit onSubmit;
  final VoidCallback? onSaved;

  @override
  ConsumerState<PlanForm> createState() => _PlanFormState();
}

class _PlanFormState extends ConsumerState<PlanForm> {
  late double _base = widget.initial?.baseWeight ?? 0;
  late int _reps = widget.initial?.targetReps ?? 10;
  late int _sets = widget.initial?.targetSets ?? 3;
  late double _inc =
      widget.initial?.increment ?? widget.exercise.defaultIncrement;
  late int? _rest = widget.initial?.restSeconds;
  bool _saving = false;

  Future<void> _save() async {
    setState(() => _saving = true);
    final ok = await guard(
      context,
      () => widget.onSubmit(
        StoredPlan(
          baseWeight: _base,
          targetReps: _reps,
          targetSets: _sets,
          increment: _inc,
          restSeconds: _rest,
        ),
      ),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      ref.read(hapticsProvider).success();
      widget.onSaved?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final defaultRest =
        ref.watch(defaultRestProvider).value ??
        SettingsRepository.defaultRestSeconds;
    final incOptions = {...incrementOptions, _inc}.toList()..sort();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppStepper(
          label: widget.exercise.isPerHand
              ? 'Base weight (per hand)'
              : 'Base weight',
          value: _base,
          step: _inc,
          unit: 'kg',
          format: formatWeight,
          onChanged: (v) => setState(() => _base = v),
        ),
        const SizedBox(height: Space.m),
        Row(
          children: [
            Expanded(
              child: AppStepper(
                label: 'Target reps',
                value: _reps.toDouble(),
                step: 1,
                min: 1,
                format: (v) => v.toInt().toString(),
                onChanged: (v) => setState(() => _reps = v.toInt()),
              ),
            ),
            const SizedBox(width: Space.m),
            Expanded(
              child: AppStepper(
                label: 'Sets',
                value: _sets.toDouble(),
                step: 1,
                min: 2,
                max: 10,
                format: (v) => v.toInt().toString(),
                onChanged: (v) => setState(() => _sets = v.toInt()),
              ),
            ),
          ],
        ),
        const SizedBox(height: Space.m),
        Text(
          'OVERLOAD INCREMENT',
          style: Theme.of(context).textTheme.labelSmall,
        ),
        const SizedBox(height: Space.s),
        ChipSelector<double>(
          options: incOptions,
          selected: _inc,
          labelOf: (v) => '+${formatWeight(v)}',
          onSelected: (v) => setState(() => _inc = v),
        ),
        const SizedBox(height: Space.m),
        RestTimeField(
          value: _rest,
          defaultSeconds: defaultRest,
          onChanged: (v) => setState(() => _rest = v),
        ),
        const SizedBox(height: Space.l),
        AppButton(
          label: widget.submitLabel,
          expand: true,
          onPressed: _saving ? null : _save,
        ),
      ],
    );
  }
}

/// "Rest time: Default (60 s) | custom" row (PRD §5.7).
class RestTimeField extends StatelessWidget {
  const new({
    required this.value,
    required this.defaultSeconds,
    required this.onChanged,
    super.key,
  });

  /// null = use the default.
  final int? value;
  final int defaultSeconds;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    final custom = value != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('REST TIME', style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: Space.s),
        ChipSelector<bool>(
          options: const [false, true],
          selected: custom,
          labelOf: (c) => c
              ? 'Custom'
              : 'Default (${formatClock(Duration(seconds: defaultSeconds))})',
          onSelected: (c) => onChanged(c ? (value ?? defaultSeconds) : null),
        ),
        if (custom) ...[
          const SizedBox(height: Space.s),
          AppStepper(
            label: 'Rest time',
            value: value!.toDouble(),
            step: SettingsRepository.restStepSeconds.toDouble(),
            min: SettingsRepository.minRestSeconds.toDouble(),
            max: SettingsRepository.maxRestSeconds.toDouble(),
            format: (v) => formatClock(Duration(seconds: v.toInt())),
            onChanged: (v) => onChanged(v.toInt()),
          ),
        ],
      ],
    );
  }
}

/// Inline card shown the first time an exercise without a plan appears.
class PlanSetupCard extends StatelessWidget {
  const new({required this.exercise, required this.onSubmit, super.key});

  final ExerciseRow exercise;
  final PlanSubmit onSubmit;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        'Set up your plan. The weight goes up by the increment when every '
        'set before the last hits the target reps.',
        style: Theme.of(context).textTheme.bodySmall
            ?.copyWith(color: AppColors.textSecondary),
      ),
      const SizedBox(height: Space.m),
      PlanForm(
        exercise: exercise,
        submitLabel: 'Start with this plan',
        onSubmit: onSubmit,
      ),
    ],
  );
}

/// Opens the Edit plan bottom sheet. [title] defaults to
/// "Edit plan · `exercise`".
Future<void> showEditPlanSheet(
  BuildContext context, {
  required ExerciseRow exercise,
  required StoredPlan? plan,
  required PlanSubmit onSubmit,
  String? title,
  String submitLabel = 'Save plan',
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (context) => Padding(
    padding: EdgeInsets.fromLTRB(
      Space.m,
      0,
      Space.m,
      Space.m + MediaQuery.viewInsetsOf(context).bottom,
    ),
    child: SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title ?? 'Edit plan · ${exercise.name}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: Space.m),
          PlanForm(
            exercise: exercise,
            initial: plan,
            submitLabel: submitLabel,
            onSubmit: onSubmit,
            onSaved: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    ),
  ),
);
