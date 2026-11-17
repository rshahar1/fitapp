import 'package:fitapp/app/theme/app_theme.dart';
import 'package:fitapp/app/theme/tokens.dart';
import 'package:fitapp/core/format.dart';
import 'package:fitapp/data/db/app_database.dart';
import 'package:material_ui/material_ui.dart';

/// One row of the set table (prescribed and/or logged).
class SetLine {
  const new({
    required this.setNo,
    required this.weight,
    required this.reps,
    required this.isOverload,
    required this.isWorking,
    required this.targetReps,
    this.logged,
    this.previous,
  });

  final int setNo;

  /// Prescribed weight/reps (what one tap logs).
  final double weight;
  final int reps;
  final bool isOverload;

  /// Working sets (1..N-1) are judged against [targetReps].
  final bool isWorking;
  final int? targetReps;
  final SetRow? logged;
  final SetRow? previous;

  bool get isLogged => logged != null;

  bool get missedReps =>
      isWorking &&
      targetReps != null &&
      logged != null &&
      logged!.reps < targetReps!;
}

const _colSet = 44.0;
const _colCheck = Sizes.tap;

class SetTableHeader extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall;
    return ExcludeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Space.xs),
        child: Row(
          children: [
            SizedBox(
              width: _colSet,
              child: Text('SET', style: style, textAlign: TextAlign.center),
            ),
            Expanded(flex: 3, child: Text('PREVIOUS', style: style)),
            Expanded(
              flex: 2,
              child: Text('KG', style: style, textAlign: TextAlign.center),
            ),
            Expanded(
              flex: 2,
              child: Text('REPS', style: style, textAlign: TextAlign.center),
            ),
            const SizedBox(
              width: _colCheck,
              child: Icon(
                Icons.check,
                size: 16,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A set row: tap the check box to log as prescribed, tap the row to edit.
class SetRowView extends StatelessWidget {
  const new({
    required this.line,
    required this.onCheck,
    required this.onTap,
    super.key,
  });

  final SetLine line;

  /// Null makes the row read-only (history review, feature 020).
  final VoidCallback? onCheck;
  final VoidCallback? onTap;

  String get _semantics {
    final opens = onTap == null ? '' : ' Opens editor.';
    final kind = line.isOverload ? ', overload' : '';
    if (line.logged case final s?) {
      final target = line.targetReps;
      final reps = target != null && line.isWorking
          ? '${s.reps} of $target reps'
          : '${s.reps} reps';
      return 'Set ${line.setNo}$kind, logged: $reps at '
          '${formatKg(s.weight)}.$opens';
    }
    return 'Set ${line.setNo}$kind: ${line.reps} reps at '
        '${formatKg(line.weight)}.$opens';
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme.titleMedium!
        .copyWith(fontFeatures: tabular);
    final logged = line.logged;
    final dim = logged == null;
    final valueColor = dim ? AppColors.textTertiary : AppColors.textPrimary;
    final weight = logged?.weight ?? line.weight;
    final reps = logged?.reps ?? line.reps;
    final prev = line.previous;

    return AnimatedContainer(
      duration: Motion.fast,
      margin: const EdgeInsets.symmetric(vertical: Space.xxs),
      decoration: BoxDecoration(
        color: logged != null ? AppColors.accentSoft : null,
        borderRadius: BorderRadius.circular(Radii.chip),
        border: Border.all(
          color: line.isOverload
              ? AppColors.accent.withValues(alpha: dim ? 0.5 : 1)
              : const Color(0x00000000),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              button: onTap != null,
              label: _semantics,
              excludeSemantics: true,
              child: InkWell(
                borderRadius: BorderRadius.circular(Radii.chip),
                onTap: onTap,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: Sizes.tap),
                  child: Row(
                    children: [
                      SizedBox(
                        width: _colSet,
                        child: Center(child: _SetBadge(line: line)),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          prev == null
                              ? '—'
                              : '${formatKg(prev.weight)} × ${prev.reps}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: AppColors.textSecondary,
                                fontFeatures: tabular,
                              ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          formatWeight(weight),
                          textAlign: TextAlign.center,
                          style: text.copyWith(color: valueColor),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          line.missedReps
                              ? '$reps / ${line.targetReps}'
                              : '$reps',
                          textAlign: TextAlign.center,
                          style: text.copyWith(
                            color: line.missedReps
                                ? AppColors.danger
                                : valueColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          _CheckBox(line: line, onCheck: onCheck),
        ],
      ),
    );
  }
}

class _SetBadge extends StatelessWidget {
  const new({required this.line});

  final SetLine line;

  @override
  Widget build(BuildContext context) {
    if (!line.isOverload) {
      return Text(
        '${line.setNo}',
        style: Theme.of(context).textTheme.titleSmall
            ?.copyWith(color: AppColors.textSecondary, fontFeatures: tabular),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Space.s, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.accentSoft,
        borderRadius: BorderRadius.circular(Radii.pill),
      ),
      child: const Text(
        '↑',
        style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _CheckBox extends StatelessWidget {
  const new({required this.line, required this.onCheck});

  final SetLine line;
  final VoidCallback? onCheck;

  @override
  Widget build(BuildContext context) {
    final logged = line.isLogged;
    final readOnly = onCheck == null;
    return Semantics(
      button: !readOnly,
      checked: logged,
      label: readOnly
          ? 'Set ${line.setNo} ${logged ? 'logged' : 'not logged'}'
          : logged
          ? 'Set ${line.setNo} logged. Opens editor.'
          : 'Log set ${line.setNo} as prescribed',
      excludeSemantics: true,
      child: InkResponse(
        onTap: onCheck,
        radius: Sizes.tap / 2,
        child: SizedBox.square(
          dimension: Sizes.tap,
          child: Center(
            child: AnimatedContainer(
              duration: Motion.fast,
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: logged ? AppColors.accent : null,
                border: logged
                    ? null
                    : Border.all(color: AppColors.textTertiary, width: 2),
              ),
              child: logged
                  ? const Icon(Icons.check, size: 18, color: AppColors.onAccent)
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}
