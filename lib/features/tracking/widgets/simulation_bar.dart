import 'package:fitapp/app/theme/tokens.dart';
import 'package:fitapp/core/format.dart';
import 'package:fitapp/data/providers.dart';
import 'package:fitapp/data/tracking/sim/track_simulation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// Dev-only strip (feature 019) shown while the GPS is simulated: what is
/// replayed, how far, and the replay speed. Nothing when not simulating.
class SimulationBar extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sim = ref.watch(simulationProvider);
    if (sim == null) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: sim,
      builder: (context, _) => _Bar(sim: sim),
    );
  }
}

class _Bar extends StatelessWidget {
  const new({required this.sim});

  final TrackSimulation sim;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final status = switch (sim.phase) {
      SimPhase.parked => 'Val Thorens · at the base',
      SimPhase.replaying =>
        'Val Thorens · ${formatClock(sim.position)} / '
            '${formatClock(sim.duration)}',
      SimPhase.holding => 'Val Thorens · session over',
    };
    return Container(
      margin: const EdgeInsets.only(bottom: Space.s),
      padding: const EdgeInsets.symmetric(
        horizontal: Space.s,
        vertical: Space.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(Radii.chip),
        border: Border.all(color: AppColors.metricWeight),
      ),
      child: Row(
        children: [
          const Icon(Icons.science_outlined, color: AppColors.metricWeight),
          const SizedBox(width: Space.s),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SIMULATED GPS',
                  style: text.labelSmall?.copyWith(
                    color: AppColors.metricWeight,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  status,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          for (final s in TrackSimulation.speeds)
            Semantics(
              button: true,
              selected: s == sim.speed,
              label: 'Replay at $s times speed',
              excludeSemantics: true,
              child: InkWell(
                borderRadius: BorderRadius.circular(Radii.chip),
                onTap: () => sim.setSpeed(s),
                child: Container(
                  constraints: const BoxConstraints(
                    minWidth: Sizes.tap - Space.s,
                    minHeight: Sizes.tap,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$s×',
                    style: text.labelLarge?.copyWith(
                      color: s == sim.speed
                          ? AppColors.metricWeight
                          : AppColors.textSecondary,
                      fontWeight: s == sim.speed
                          ? FontWeight.w800
                          : FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
