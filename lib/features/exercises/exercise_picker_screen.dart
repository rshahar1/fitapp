import 'package:fitapp/app/theme/tokens.dart';
import 'package:fitapp/core/format.dart';
import 'package:fitapp/core/haptics.dart';
import 'package:fitapp/data/db/app_database.dart';
import 'package:fitapp/data/db/seed_library.dart';
import 'package:fitapp/data/providers.dart';
import 'package:fitapp/features/exercises/custom_exercise_sheet.dart';
import 'package:fitapp/widgets/guard.dart';
import 'package:fitapp/widgets/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

const _customGroup = 'Custom';

/// Fullscreen picker that adds an exercise to a workout (PRD §5.1).
class ExercisePickerScreen extends ConsumerStatefulWidget {
  const new({required this.workoutId, super.key});

  final String workoutId;

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
    final ok = await guard(
      context,
      () => ref
          .read(workoutRepositoryProvider)
          .addExercise(widget.workoutId, exercise.id),
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

  String _subtitle(ExerciseRow e) {
    final inc = '+${formatKg(e.defaultIncrement)}';
    return e.isPerHand ? 'per hand · $inc' : inc;
  }

  @override
  Widget build(BuildContext context) {
    final exercises = ref.watch(exercisesProvider(_query.trim()));
    final trimmed = _query.trim();
    return Scaffold(
      backgroundColor: const Color(0x00000000),
      appBar: AppBar(
        title: const Text('Add exercise'),
        leading: IconButton(
          icon: const Icon(Icons.close),
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
                final grouped = <String, List<ExerciseRow>>{};
                for (final e in list) {
                  (grouped[e.muscleGroup ?? _customGroup] ??= []).add(e);
                }
                final order = [
                  ...muscleGroups.where(grouped.containsKey),
                  ...grouped.keys.where((g) => !muscleGroups.contains(g)),
                ];
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
                    for (final g in order) ...[
                      SectionHeader(g),
                      Group(
                        children: [
                          for (final e in grouped[g]!)
                            GroupRow(
                              title: e.name,
                              subtitle: _subtitle(e),
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
