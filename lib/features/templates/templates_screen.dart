import 'package:fitapp/app/router.dart';
import 'package:fitapp/app/theme/tokens.dart';
import 'package:fitapp/data/providers.dart';
import 'package:fitapp/widgets/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// Gym templates list (feature 028), reachable from the You tab.
class TemplatesScreen extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templates = ref.watch(templatesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Gym Templates')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(Routes.newTemplate),
        icon: const Icon(Icons.add),
        label: const Text('New template'),
      ),
      body: templates.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(child: Text('Could not load templates.')),
        data: (items) => items.isEmpty
            ? const EmptyState(
                icon: Icons.fitness_center,
                title: 'No templates yet',
                message: 'Create a template to start a routine in one tap.',
              )
            : ListView(
                // Bottom room so the FAB never covers the last row.
                padding: const EdgeInsets.fromLTRB(
                  Space.m,
                  Space.m,
                  Space.m,
                  Space.m + 80,
                ),
                children: [
                  Group(
                    children: [
                      for (final t in items)
                        GroupRow(
                          title: t.name,
                          subtitle: t.exercises.map((e) => e.name).join(' · '),
                          showChevron: true,
                          onTap: () => context.push(Routes.template(t.id)),
                        ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}
