import 'dart:async';

import 'package:fitapp/app/theme/tokens.dart';
import 'package:fitapp/features/start/start_hub_sheet.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// Bottom bar with five slots (PRD §6, feature 011):
/// `Home · History · [Go] · Progress · You`. The centre "Go" is an action that
/// opens the Go hub (Start/Log); it is never a selected destination.
class ShellScaffold extends StatelessWidget {
  const new({required this.shell, super.key});

  final StatefulNavigationShell shell;

  /// Branches in bar order; the "Go" sits between History and Progress.
  static const _tabs = [
    (Icons.fitness_center_outlined, Icons.fitness_center, 'Home'),
    (Icons.history_outlined, Icons.history, 'History'),
    (Icons.show_chart_outlined, Icons.show_chart, 'Progress'),
    (Icons.person_outline, Icons.person, 'You'),
  ];

  @override
  Widget build(BuildContext context) {
    Widget tab(int branch) {
      final (icon, selectedIcon, label) = _tabs[branch];
      final selected = shell.currentIndex == branch;
      return Expanded(
        child: _Tab(
          icon: selected ? selectedIcon : icon,
          label: label,
          selected: selected,
          onTap: () => shell.goBranch(branch, initialLocation: selected),
        ),
      );
    }

    return Scaffold(
      body: shell,
      bottomNavigationBar: Material(
        color: AppColors.background,
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 72,
            child: Row(
              children: [
                tab(0),
                tab(1),
                Expanded(
                  child: Center(
                    child: _GoButton(
                      onTap: () => unawaited(showStartHub(context)),
                    ),
                  ),
                ),
                tab(2),
                tab(3),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const new({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.accent : AppColors.textSecondary;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: InkResponse(
        onTap: onTap,
        highlightShape: BoxShape.rectangle,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: Sizes.tap),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: Space.m,
                  vertical: Space.xs,
                ),
                decoration: BoxDecoration(
                  color: selected ? AppColors.accentSoft : Colors.transparent,
                  borderRadius: const BorderRadius.all(
                    Radius.circular(Radii.pill),
                  ),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(height: Space.xs),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Raised accent circle with a "Go" caption in the centre slot.
class _GoButton extends StatelessWidget {
  const new({required this.onTap});

  final VoidCallback onTap;

  static const label = 'Go';

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    excludeSemantics: true,
    onTap: onTap,
    child: Tooltip(
      message: label,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            color: AppColors.accent,
            shape: const CircleBorder(),
            elevation: 4,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: const SizedBox.square(
                dimension: Sizes.tap,
                child: Icon(
                  Icons.play_arrow_rounded,
                  size: 32,
                  color: AppColors.onAccent,
                ),
              ),
            ),
          ),
          const Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.accent,
            ),
          ),
        ],
      ),
    ),
  );
}
