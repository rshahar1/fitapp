import 'package:fitapp/app/theme/tokens.dart';
import 'package:fitapp/core/format.dart';
import 'package:fitapp/data/models.dart';
import 'package:fitapp/widgets/widgets.dart';
import 'package:material_ui/material_ui.dart';

/// Text for one finish outcome (PRD §4.3).
String outcomeText(FinishOutcome o) => o.toBase > o.fromBase
    ? '${o.exerciseName}: ${formatKg(o.fromBase)} → ${formatKg(o.toBase)}'
    : '${o.exerciseName}: stays at ${formatKg(o.toBase)}';

/// What the user chose on the finish summary.
enum FinishChoice {
  /// Leave the workout.
  done,

  /// Reopen the workout.
  resume,

  /// Open the share preview (feature 027).
  share,
}

/// Shows the summary; resolves to the user's [FinishChoice]
/// ([FinishChoice.done] when dismissed).
Future<FinishChoice> showFinishSummary(
  BuildContext context,
  FinishResult result,
) async {
  final choice = await showModalBottomSheet<FinishChoice>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (context) => Padding(
      padding: const EdgeInsets.fromLTRB(Space.m, 0, Space.m, Space.l),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Workout complete',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: Space.m),
          if (result.outcomes.isEmpty)
            const Text('No planned exercises to progress.'),
          for (final o in result.outcomes)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Space.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    o.toBase > o.fromBase ? '⬆' : '•',
                    style: TextStyle(
                      color: o.toBase > o.fromBase
                          ? AppColors.accent
                          : AppColors.textSecondary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: Space.s),
                  Expanded(child: Text(outcomeText(o))),
                ],
              ),
            ),
          const SizedBox(height: Space.l),
          AppButton(
            label: 'Done',
            expand: true,
            onPressed: () => Navigator.of(context).pop(FinishChoice.done),
          ),
          const SizedBox(height: Space.s),
          AppButton(
            label: 'Share workout',
            icon: Icons.ios_share,
            expand: true,
            variant: AppButtonVariant.secondary,
            onPressed: () => Navigator.of(context).pop(FinishChoice.share),
          ),
          const SizedBox(height: Space.s),
          AppButton(
            label: 'Resume workout',
            expand: true,
            variant: AppButtonVariant.secondary,
            onPressed: () => Navigator.of(context).pop(FinishChoice.resume),
          ),
        ],
      ),
    ),
  );
  return choice ?? FinishChoice.done;
}
