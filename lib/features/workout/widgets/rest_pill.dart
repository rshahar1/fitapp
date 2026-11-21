import 'package:fitapp/app/theme/app_icons.dart';
import 'package:fitapp/app/theme/text_styles.dart';
import 'package:fitapp/app/theme/tokens.dart';
import 'package:fitapp/core/format.dart';
import 'package:fitapp/features/workout/rest_timer_controller.dart';
import 'package:fitapp/features/workout/widgets/tick.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// Rest countdown pill for the fixed footer. Occupies its slot even when
/// hidden so nothing shifts (PRD §2.3 rule 1).
class RestPill extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rest = ref.watch(restTimerProvider);
    if (rest == null) return const SizedBox(height: Sizes.tap);
    return Tick(
      builder: (context) {
        final left = ref.read(restTimerProvider.notifier).remaining(rest);
        final overtime = left <= Duration.zero;
        final shown = overtime ? -left : left;
        final text = overtime && shown > Duration.zero
            ? formatRest(left)
            : formatRest(shown);
        return Semantics(
          button: true,
          label: overtime
              ? 'Rest over by ${shown.inSeconds} seconds. Tap to dismiss.'
              : 'Rest: ${shown.inSeconds} seconds left. Tap to dismiss.',
          excludeSemantics: true,
          child: Material(
            color: overtime ? AppColors.surfaceHigh : AppColors.accent,
            shape: const RoundedRectangleBorder(),
            child: InkWell(
              customBorder: const RoundedRectangleBorder(),
              onTap: () => ref.read(restTimerProvider.notifier).dismiss(),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: Sizes.tap),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Space.m),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        AppIcons.timer,
                        size: 18,
                        color: overtime
                            ? AppColors.textSecondary
                            : AppColors.onAccent,
                      ),
                      const SizedBox(width: Space.s),
                      Text(
                        text,
                        style: context.plate.number(
                          22,
                          color: overtime
                              ? AppColors.textSecondary
                              : AppColors.onAccent,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
