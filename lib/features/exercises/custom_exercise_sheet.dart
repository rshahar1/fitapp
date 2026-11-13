import 'package:fitapp/app/theme/tokens.dart';
import 'package:fitapp/core/format.dart';
import 'package:fitapp/data/db/app_database.dart';
import 'package:fitapp/data/db/seed_library.dart';
import 'package:fitapp/data/providers.dart';
import 'package:fitapp/data/repositories/exercise_repository.dart';
import 'package:fitapp/features/exercises/exercise_groups.dart';
import 'package:fitapp/widgets/guard.dart';
import 'package:fitapp/widgets/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

const _increments = [1.0, 2.0, 2.5, 5.0];

/// Bottom sheet to create a custom exercise, or edit [existing]. Returns the
/// saved row, or null when dismissed.
Future<ExerciseRow?> showCustomExerciseSheet(
  BuildContext context, {
  String initialName = '',
  ExerciseRow? existing,
}) => showModalBottomSheet<ExerciseRow>(
  context: context,
  useSafeArea: true,
  isScrollControlled: true,
  builder: (_) =>
      _CustomExerciseSheet(initialName: initialName, existing: existing),
);

class _CustomExerciseSheet extends ConsumerStatefulWidget {
  const new({required this.initialName, this.existing});

  final String initialName;
  final ExerciseRow? existing;

  @override
  ConsumerState<_CustomExerciseSheet> createState() =>
      _CustomExerciseSheetState();
}

class _CustomExerciseSheetState extends ConsumerState<_CustomExerciseSheet> {
  late final _name = TextEditingController(
    text: widget.existing?.name ?? widget.initialName,
  );
  late bool _perHand = widget.existing?.isPerHand ?? false;
  late double _increment = widget.existing?.defaultIncrement ?? 2.5;
  late String? _category = widget.existing?.muscleGroup;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'Enter a name');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    ExerciseRow? created;
    try {
      final repo = ref.read(exerciseRepositoryProvider);
      final existing = widget.existing;
      created = existing == null
          ? await repo.createCustom(
              name: _name.text,
              perHand: _perHand,
              increment: _increment,
              muscleGroup: _category,
            )
          : await repo.updateCustom(
              existing.id,
              name: _name.text,
              muscleGroup: _category,
              perHand: _perHand,
              increment: _increment,
            );
    } on DuplicateExerciseName catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'An exercise named "${e.name}" already exists';
      });
      return;
    } on Object {
      if (!mounted) return;
      setState(() => _busy = false);
      await guard(context, () async => throw StateError('save failed'));
      return;
    }
    if (mounted) Navigator.of(context).pop(created);
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.existing != null;
    final increments = {..._increments, _increment}.toList()..sort();
    return Padding(
      padding: EdgeInsets.fromLTRB(
        Space.m,
        Space.m,
        Space.m,
        Space.m + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              editing ? 'Edit exercise' : 'New exercise',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: Space.m),
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: 'Name', errorText: _error),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
            ),
            const SizedBox(height: Space.m),
            Text('Category', style: Theme.of(context).textTheme.labelSmall),
            const SizedBox(height: Space.s),
            ChipSelector<String?>(
              options: const [...muscleGroups, null],
              selected: _category,
              labelOf: (v) => v ?? customGroup,
              onSelected: (v) => setState(() => _category = v),
            ),
            const SizedBox(height: Space.s),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Per hand (dumbbells)'),
              value: _perHand,
              onChanged: (v) => setState(() => _perHand = v),
            ),
            const SizedBox(height: Space.s),
            Text(
              'Weight increment',
              style: Theme.of(context).textTheme.labelSmall,
            ),
            const SizedBox(height: Space.s),
            ChipSelector<double>(
              options: increments,
              selected: _increment,
              labelOf: (v) => '+${formatWeight(v)}',
              onSelected: (v) => setState(() => _increment = v),
            ),
            const SizedBox(height: Space.l),
            AppButton(
              label: editing ? 'Save' : 'Create exercise',
              expand: true,
              onPressed: _busy ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }
}
