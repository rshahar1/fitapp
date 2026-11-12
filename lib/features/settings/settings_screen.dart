import 'package:fitapp/app/theme/tokens.dart';
import 'package:fitapp/core/format.dart';
import 'package:fitapp/data/providers.dart';
import 'package:fitapp/data/repositories/settings_repository.dart';
import 'package:fitapp/widgets/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// Rest timer, alert and unit preferences. Values persist immediately.
class SettingsScreen extends ConsumerWidget {
  const new({super.key});

  static const _presets = [30, 60, 90, 120, 180];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final repo = ref.read(settingsRepositoryProvider);
    final rest =
        ref.watch(defaultRestProvider).value ??
        SettingsRepository.defaultRestSeconds;
    final prefs = ref.watch(alertPrefsProvider).value ?? const RestAlertPrefs();

    String clock(int s) => formatClock(Duration(seconds: s));

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(Space.m),
        children: [
          Group(
            header: 'Rest timer',
            children: [
              Padding(
                padding: const EdgeInsets.all(Space.m),
                child: AppStepper(
                  label: 'Default rest time',
                  value: rest.toDouble(),
                  step: SettingsRepository.restStepSeconds.toDouble(),
                  min: SettingsRepository.minRestSeconds.toDouble(),
                  max: SettingsRepository.maxRestSeconds.toDouble(),
                  format: (v) => clock(v.round()),
                  onChanged: (v) => repo.setDefaultRestSeconds(v.round()),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(Space.m),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ChipSelector<int>(
                      options: _presets,
                      selected: rest,
                      labelOf: clock,
                      onSelected: repo.setDefaultRestSeconds,
                    ),
                    const SizedBox(height: Space.s),
                    Text(
                      'Applies to the next logged set. Exercises with their '
                      'own rest time keep it.',
                      style: text.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Group(
            header: 'Rest timer alert',
            children: [
              SwitchListTile(
                title: const Text('Vibrate'),
                value: prefs.haptic,
                onChanged: (v) => repo.setAlertPrefs(prefs.copyWith(haptic: v)),
              ),
              SwitchListTile(
                title: const Text('Sound'),
                value: prefs.sound,
                onChanged: (v) => repo.setAlertPrefs(prefs.copyWith(sound: v)),
              ),
            ],
          ),
          Group(
            header: 'Units',
            children: [
              GroupRow(
                title: 'Weight unit',
                trailing: Text(
                  'kg',
                  style: text.bodyLarge?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
