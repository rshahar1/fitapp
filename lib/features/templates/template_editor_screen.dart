import 'dart:async';

import 'package:fitapp/app/router.dart';
import 'package:fitapp/app/theme/tokens.dart';
import 'package:fitapp/data/db/app_database.dart';
import 'package:fitapp/data/providers.dart';
import 'package:fitapp/data/repositories/template_repository.dart';
import 'package:fitapp/widgets/guard.dart';
import 'package:fitapp/widgets/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// Creates ([templateId] null) or edits a workout template.
class TemplateEditorScreen extends ConsumerStatefulWidget {
  const new({this.templateId, super.key});

  final String? templateId;

  @override
  ConsumerState<TemplateEditorScreen> createState() =>
      _TemplateEditorScreenState();
}

class _TemplateEditorScreenState extends ConsumerState<TemplateEditorScreen> {
  final _name = TextEditingController();
  List<ExerciseRow> _exercises = [];
  String _initialName = '';
  List<String> _initialIds = [];
  bool _loading = false;
  bool _missing = false;
  bool _saving = false;
  String? _nameError;

  bool get _isEdit => widget.templateId != null;

  bool get _dirty =>
      _name.text != _initialName ||
      !_sameIds(_exercises.map((e) => e.id).toList(), _initialIds);

  static bool _sameIds(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  void initState() {
    super.initState();
    _name.addListener(() => setState(() => _nameError = null));
    if (_isEdit) {
      _loading = true;
      unawaited(_load());
    }
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final t = await ref
        .read(templateRepositoryProvider)
        .template(widget.templateId!);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (t == null) {
        _missing = true;
        return;
      }
      _initialName = t.name;
      _initialIds = [for (final e in t.exercises) e.id];
      _exercises = [...t.exercises];
      _name.text = t.name;
    });
  }

  void _snack(String text) => ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(SnackBar(content: Text(text)));

  Future<void> _add() async {
    final id = await context.push<String>(Routes.pickExercise);
    if (id == null || !mounted) return;
    if (_exercises.any((e) => e.id == id)) {
      _snack('Already in this template');
      return;
    }
    final row = await ref.read(exerciseRepositoryProvider).exercise(id);
    if (row == null || !mounted) return;
    setState(() => _exercises = [..._exercises, row]);
  }

  void _remove(ExerciseRow e) =>
      setState(() => _exercises = [..._exercises]..remove(e));

  void _reorder(int from, int to) {
    setState(() {
      final list = [..._exercises];
      final target = to > from ? to - 1 : to;
      list.insert(target, list.removeAt(from));
      _exercises = list;
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    final repo = ref.read(templateRepositoryProvider);
    final ids = [for (final e in _exercises) e.id];
    setState(() => _saving = true);
    String? error;
    try {
      if (_isEdit) {
        await repo.update(
          widget.templateId!,
          name: _name.text,
          exerciseIds: ids,
        );
      } else {
        await repo.create(name: _name.text, exerciseIds: ids);
      }
    } on DuplicateTemplateName {
      error = 'Name already used';
      _nameError = error;
      // Repository validation failures are ArgumentErrors by contract.
      // ignore: avoid_catching_errors
    } on ArgumentError catch (e) {
      error = '${e.message}';
      if (error.startsWith('Name')) _nameError = error;
    } on Object {
      error = 'Something went wrong. Please try again.';
    }
    if (!mounted) return;
    setState(() => _saving = false);
    if (error != null) {
      _snack(error);
      return;
    }
    _initialName = _name.text;
    _initialIds = ids;
    _snack('Template saved');
    context.pop();
  }

  Future<void> _delete() async {
    final ok = await confirmDestructive(
      context,
      title: 'Delete template?',
      message: '"$_initialName" will be deleted. This cannot be undone.',
      confirmLabel: 'Delete',
    );
    if (!ok || !mounted) return;
    final done = await guard(
      context,
      () => ref.read(templateRepositoryProvider).delete(widget.templateId!),
    );
    if (done && mounted) {
      _initialName = _name.text;
      _initialIds = [for (final e in _exercises) e.id];
      context.pop();
    }
  }

  Future<void> _confirmDiscard() async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard changes?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep editing'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (discard == true && mounted) {
      _initialName = _name.text;
      _initialIds = [for (final e in _exercises) e.id];
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_confirmDiscard());
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(_isEdit ? 'Edit template' : 'New template'),
          actions: [
            TextButton(
              onPressed: _loading || _missing || _saving ? null : _save,
              child: const Text('Save'),
            ),
            if (_isEdit)
              PopupMenuButton<String>(
                tooltip: 'More',
                onSelected: (_) => _delete(),
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'delete',
                    child: Text('Delete template'),
                  ),
                ],
              ),
          ],
        ),
        body: _loading
            ? const SizedBox.shrink()
            : _missing
            ? const EmptyState(
                icon: Icons.error_outline,
                title: 'Template not found',
              )
            : ReorderableListView.builder(
                buildDefaultDragHandles: false,
                padding: const EdgeInsets.all(Space.m),
                header: Padding(
                  padding: const EdgeInsets.only(bottom: Space.m),
                  child: TextField(
                    controller: _name,
                    autofocus: !_isEdit,
                    maxLength: TemplateRepository.maxNameLength,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                      labelText: 'Name',
                      errorText: _nameError,
                    ),
                  ),
                ),
                footer: Padding(
                  padding: const EdgeInsets.only(top: Space.m),
                  child: AppButton(
                    label: 'Add exercise',
                    icon: Icons.add,
                    variant: AppButtonVariant.secondary,
                    expand: true,
                    onPressed: _add,
                  ),
                ),
                itemCount: _exercises.length,
                onReorderItem: _reorder,
                itemBuilder: (context, i) {
                  final e = _exercises[i];
                  return Semantics(
                    key: ValueKey(e.id),
                    label: 'Move ${e.name}',
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: Sizes.tap),
                      child: Row(
                        children: [
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: Space.s,
                              ),
                              child: Text(e.name, style: text.titleMedium),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Remove ${e.name}',
                            constraints: const BoxConstraints(
                              minWidth: Sizes.tap,
                              minHeight: Sizes.tap,
                            ),
                            icon: const Icon(Icons.close),
                            onPressed: () => _remove(e),
                          ),
                          ReorderableDragStartListener(
                            index: i,
                            child: const SizedBox(
                              width: Sizes.tap,
                              height: Sizes.tap,
                              child: Icon(
                                Icons.drag_handle,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
