import 'package:fitapp/app/router.dart';
import 'package:fitapp/app/theme/app_icons.dart';
import 'package:fitapp/app/theme/tokens.dart';
import 'package:fitapp/data/db/app_database.dart';
import 'package:fitapp/data/providers.dart';
import 'package:fitapp/features/exercises/custom_exercise_sheet.dart';
import 'package:fitapp/features/exercises/exercise_groups.dart';
import 'package:fitapp/widgets/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// All exercises grouped by category, usable without a running workout.
class ExerciseLibraryScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<ExerciseLibraryScreen> createState() =>
      _ExerciseLibraryScreenState();
}

class _ExerciseLibraryScreenState extends ConsumerState<ExerciseLibraryScreen> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final created = await showCustomExerciseSheet(
      context,
      initialName: _query.trim(),
    );
    if (created != null && mounted) {
      _search.clear();
      setState(() => _query = '');
    }
  }

  Future<void> _edit(ExerciseRow e) =>
      showCustomExerciseSheet(context, existing: e);

  Future<void> _delete(ExerciseRow e) async {
    final repo = ref.read(exerciseRepositoryProvider);
    final usage = await repo.templatesUsing(e.id);
    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "${e.name}"?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'It will no longer appear in your library, templates or '
              'Progress. Past workouts keep it.',
            ),
            if (usage.isNotEmpty) ...[
              const SizedBox(height: Space.s),
              Text('Removed from: ${usage.map((t) => t.name).join(', ')}.'),
            ],
            for (final t in usage.where((t) => t.wouldBeEmpty)) ...[
              const SizedBox(height: Space.s),
              Text('"${t.name}" has no other exercises and will be deleted.'),
            ],
            const SizedBox(height: Space.s),
            const Text(
              'To bring it back, create an exercise with the same name.',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await repo.delete(e.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Deleted ${e.name}')));
  }

  @override
  Widget build(BuildContext context) {
    final exercises = ref.watch(exercisesProvider(_query.trim()));
    final trimmed = _query.trim();
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Gym Exercise Library'),
        actions: [
          IconButton(
            icon: const Icon(AppIcons.add),
            tooltip: 'New exercise',
            onPressed: _create,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.m, Space.s, Space.m, 0),
            child: TextField(
              controller: _search,
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                hintText: 'Search exercises',
                prefixIcon: Icon(AppIcons.search),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: exercises.when(
              loading: () => const SizedBox.shrink(),
              error: (e, _) => const EmptyState(
                icon: AppIcons.error,
                title: 'Could not load exercises',
              ),
              data: (list) {
                final exact =
                    trimmed.isEmpty ||
                    list.any(
                      (e) => e.name.toLowerCase() == trimmed.toLowerCase(),
                    );
                return ListView(
                  padding: const EdgeInsets.only(
                    left: Space.m,
                    right: Space.m,
                    bottom: Space.l,
                  ),
                  children: [
                    if (!exact)
                      Padding(
                        padding: const EdgeInsets.only(top: Space.m),
                        child: Group(
                          children: [
                            GroupRow(
                              title: 'Create "$trimmed"',
                              leading: const Icon(
                                AppIcons.addBox,
                                color: AppColors.accent,
                              ),
                              onTap: _create,
                            ),
                          ],
                        ),
                      ),
                    if (list.isEmpty && exact)
                      const EmptyState(
                        icon: AppIcons.gym,
                        title: 'No exercises',
                      ),
                    for (final (g, items) in groupExercises(list)) ...[
                      SectionHeader(g),
                      Group(
                        children: [
                          for (final e in items)
                            GroupRow(
                              title: e.name,
                              subtitle: exerciseSubtitle(e),
                              trailing: PopupMenuButton<String>(
                                tooltip: 'Options for ${e.name}',
                                icon: const Icon(AppIcons.more),
                                onSelected: (v) =>
                                    v == 'edit' ? _edit(e) : _delete(e),
                                itemBuilder: (_) => [
                                  if (e.isCustom)
                                    const PopupMenuItem(
                                      value: 'edit',
                                      child: Text('Edit'),
                                    ),
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Text('Delete'),
                                  ),
                                ],
                              ),
                              onTap: () => context.push(Routes.exercise(e.id)),
                            ),
                        ],
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
