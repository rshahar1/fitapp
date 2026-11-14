import 'package:fitapp/app/router.dart';
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

  @override
  Widget build(BuildContext context) {
    final exercises = ref.watch(exercisesProvider(_query.trim()));
    final trimmed = _query.trim();
    return Scaffold(
      backgroundColor: const Color(0x00000000),
      appBar: AppBar(
        title: const Text('Exercises'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
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
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: exercises.when(
              loading: () => const SizedBox.shrink(),
              error: (e, _) => const EmptyState(
                icon: Icons.error_outline,
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
                                Icons.add_circle_outline,
                                color: AppColors.accent,
                              ),
                              onTap: _create,
                            ),
                          ],
                        ),
                      ),
                    if (list.isEmpty && exact)
                      const EmptyState(
                        icon: Icons.fitness_center,
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
                              showChevron: !e.isCustom,
                              trailing: e.isCustom
                                  ? IconButton(
                                      icon: const Icon(Icons.edit_outlined),
                                      tooltip: 'Edit ${e.name}',
                                      onPressed: () => _edit(e),
                                    )
                                  : null,
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
