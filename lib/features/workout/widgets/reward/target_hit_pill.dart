import 'package:fitapp/app/theme/tokens.dart';
import 'package:fitapp/features/workout/widgets/reward/muscle_figure.dart';
import 'package:material_ui/material_ui.dart';

/// "Target hit · sets 1–2" pill shown on the Add Set row (feature 008).
///
/// Always occupies its space; [visible] only fades and scales it so the row
/// never shifts.
class TargetHitPill extends StatelessWidget {
  const new({required this.visible, super.key});

  final bool visible;

  static const semanticsLabel = 'Target hit for sets 1 and 2';

  @override
  Widget build(BuildContext context) {
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 350);
    return Semantics(
      container: true,
      liveRegion: true,
      label: visible ? semanticsLabel : null,
      excludeSemantics: true,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: duration,
        child: AnimatedScale(
          scale: visible ? 1 : 0.6,
          duration: duration,
          curve: const Cubic(0.3, 1.5, 0.5, 1),
          child: Container(
            height: 28,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(Radii.pill),
              border: Border.all(
                color: AppColors.accent.withValues(alpha: 0.5),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 19,
                  height: 16,
                  child: CustomPaint(painter: MuscleFigurePainter(icon: true)),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'Target hit · sets 1–2',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelMedium
                        ?.copyWith(color: AppColors.accent, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
