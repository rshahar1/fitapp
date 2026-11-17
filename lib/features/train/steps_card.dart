import 'dart:async';

import 'package:fitapp/app/theme/app_theme.dart';
import 'package:fitapp/app/theme/tokens.dart';
import 'package:fitapp/core/format.dart';
import 'package:fitapp/core/step_source.dart';
import 'package:fitapp/data/providers.dart';
import 'package:fitapp/widgets/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

/// Today's step count on Train (feature 014). Hidden when the setting is off,
/// steps are unavailable, or the first read has not finished.
class StepsCard extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<StepsCard> createState() => _StepsCardState();
}

class _StepsCardState extends ConsumerState<StepsCard> {
  late final AppLifecycleListener _lifecycle;
  bool _introChecked = false;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _refresh);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  void _refresh() {
    ref
      ..invalidate(stepAccessProvider)
      ..invalidate(distanceAccessProvider)
      ..invalidate(todayStepsProvider)
      ..invalidate(todayDistanceProvider);
  }

  Future<void> _connect() async {
    await ref.read(stepSourceProvider).requestAccess();
    if (mounted) _refresh();
  }

  Future<void> _connectDistance() async {
    await ref.read(stepSourceProvider).requestDistanceAccess();
    if (mounted) _refresh();
  }

  Future<void> _install() async {
    await ref.read(stepSourceProvider).installHealthConnect();
    if (mounted) _refresh();
  }

  void _maybeShowIntro() {
    if (_introChecked) return;
    _introChecked = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _showIntro());
  }

  Future<void> _showIntro() async {
    if (!mounted) return;
    final repo = ref.read(settingsRepositoryProvider);
    if (await repo.stepsIntroShown() || !mounted) return;
    final connect = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const StepsIntroSheet(),
    );
    await repo.markStepsIntroShown();
    if (connect == true && mounted) await _connect();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = ref.watch(stepsEnabledProvider).value ?? false;
    final access = ref.watch(stepAccessProvider).value;
    if (!enabled || access == null || access == StepAccess.unavailable) {
      return const SizedBox.shrink();
    }
    if (access == StepAccess.notGranted) _maybeShowIntro();

    final text = Theme.of(context).textTheme;
    final secondary = text.bodyMedium?.copyWith(color: AppColors.textSecondary);

    final Widget body;
    switch (access) {
      case StepAccess.granted:
        final steps = ref.watch(todayStepsProvider).value;
        final value = steps == null
            ? '—'
            : NumberFormat.decimalPattern().format(steps);
        final meters = ref.watch(todayDistanceProvider).value;
        final distanceOk = ref.watch(distanceAccessProvider).value;
        final km = meters == null ? null : formatKm(meters);
        body = Semantics(
          container: true,
          label: 'Steps today: $value${km == null ? '' : ', $km'}',
          excludeSemantics: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Steps today', style: text.labelSmall),
              const SizedBox(height: Space.xs),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    value,
                    style: text.headlineMedium?.copyWith(fontFeatures: tabular),
                  ),
                  if (km != null) ...[
                    const SizedBox(width: Space.s),
                    Text(
                      km,
                      style: text.titleMedium?.copyWith(
                        color: AppColors.textSecondary,
                        fontFeatures: tabular,
                      ),
                    ),
                  ],
                ],
              ),
              if (distanceOk == false) ...[
                const SizedBox(height: Space.xs),
                AppButton(
                  label: 'Show km',
                  variant: AppButtonVariant.ghost,
                  onPressed: _connectDistance,
                ),
              ],
              if (steps == 0) ...[
                const SizedBox(height: Space.xs),
                Text(
                  'Turn on Health Connect sharing in Google Fit',
                  style: text.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        );
      case StepAccess.notGranted:
        body = _prompt(
          'See your daily steps from Google Fit',
          secondary,
          AppButton(
            label: 'Connect',
            variant: AppButtonVariant.secondary,
            onPressed: _connect,
          ),
        );
      case StepAccess.needsInstall:
        body = _prompt(
          'Daily steps need Health Connect',
          secondary,
          AppButton(
            label: 'Get Health Connect',
            variant: AppButtonVariant.secondary,
            onPressed: _install,
          ),
        );
      case StepAccess.unavailable:
        return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: Space.s),
      child: AppCard(
        child: SizedBox(width: double.infinity, child: body),
      ),
    );
  }

  Widget _prompt(String message, TextStyle? style, Widget button) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(message, style: style),
      const SizedBox(height: Space.s),
      button,
    ],
  );
}

/// One-time explanation before the Health Connect permission prompt.
/// Pops `true` for Connect, `false` for Not now.
class StepsIntroSheet extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(Space.m, 0, Space.m, Space.m),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Show your daily steps and distance?', style: text.titleLarge),
            const SizedBox(height: Space.s),
            Text(
              'FitApp reads your step count from Health Connect, where Google '
              'Fit and other apps share it. Read-only, steps and distance only, and it '
              'stays on your phone. You can turn this off in Settings.',
              style: text.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: Space.m),
            AppButton(
              label: 'Connect',
              expand: true,
              onPressed: () => Navigator.of(context).pop(true),
            ),
            const SizedBox(height: Space.s),
            AppButton(
              label: 'Not now',
              variant: AppButtonVariant.ghost,
              expand: true,
              onPressed: () => Navigator.of(context).pop(false),
            ),
          ],
        ),
      ),
    );
  }
}
