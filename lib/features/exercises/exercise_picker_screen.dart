import 'package:fitapp/app/theme/app_icons.dart';
import 'package:fitapp/app/theme/tokens.dart';
import 'package:fitapp/core/haptics.dart';
import 'package:fitapp/data/db/app_database.dart';
import 'package:fitapp/data/providers.dart';
import 'package:fitapp/features/exercises/custom_exercise_sheet.dart';
import 'package:fitapp/features/exercises/exercise_groups.dart';
import 'package:fitapp/widgets/guard.dart';
import 'package:fitapp/widgets/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// Fullscreen picker that adds an exercise to a workout (PRD §5.1). Without a
/// [workoutId] it is in select mode and pops with the chosen exercise id.
class ExercisePickerScreen extends ConsumerStatefulWidget {
  const new({this.workoutId, super.key});

  final String? workoutId;

  @override
  ConsumerState<ExercisePickerScreen> createState() =>
      _ExercisePickerScreenState();
}

class _ExercisePickerScreenState extends ConsumerState<ExercisePickerScreen> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _add(ExerciseRow exercise) async {
    final workoutId = widget.workoutId;
    if (workoutId == null) {
      ref.read(hapticsProvider).tick();
      Navigator.of(context).pop(exercise.id);
      return;
    }
    final ok = await guard(
      context,
      () => ref
          .read(workoutRepositoryProvider)
          .addExercise(workoutId, exercise.id),
    );
    if (!ok || !mounted) return;
    ref.read(hapticsProvider).tick();
    Navigator.of(context).pop();
  }

  Future<void> _create() async {
    final created = await showCustomExerciseSheet(
      context,
      initialName: _query.trim(),
    );
    if (created != null && mounted) await _add(created);
  }

  @override
  Widget build(BuildContext context) {
    final exercises = ref.watch(exercisesProvider(_query.trim()));
    final trimmed = _query.trim();
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(
          widget.workoutId == null ? 'Choose exercise' : 'Add exercise',
        ),
        leading: IconButton(
          icon: const Icon(AppIcons.close),
          tooltip: 'Close',
          onPressed: () => Navigator.of(context).pop(),
        ),
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
                final groups = groupExercises(list);
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
                    for (final (g, items) in groups) ...[
                      SectionHeader(g),
                      Group(
                        children: [
                          for (final e in items)
                            GroupRow(
                              title: e.name,
                              subtitle: exerciseSubtitle(e),
                              onTap: () => _add(e),
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
