import 'package:fitapp/app/theme/tokens.dart';
import 'package:fitapp/core/format.dart';
import 'package:fitapp/core/rest_alerts.dart';
import 'package:fitapp/data/providers.dart';
import 'package:fitapp/data/repositories/settings_repository.dart';
import 'package:fitapp/widgets/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// Current notification / exact-alarm status; invalidated on app resume.
final alertStatusProvider = FutureProvider.autoDispose<AlertStatus>(
  (ref) => ref.watch(restAlertsProvider).status(),
);

/// Rest timer, alert and unit preferences. Values persist immediately.
class SettingsScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  static const _presets = [30, 60, 90, 120, 180];

  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onResume: () => ref.invalidate(alertStatusProvider),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _open(Future<void> Function() open) async {
    await open();
    if (mounted) ref.invalidate(alertStatusProvider);
  }

  Widget _statusRow(
    TextTheme text, {
    required String title,
    required bool on,
    required String offText,
    required Future<void> Function() open,
  }) {
    return GroupRow(
      title: title,
      trailing: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 180),
        child: Text(
          on ? 'On' : offText,
          textAlign: TextAlign.end,
          style: text.bodyLarge?.copyWith(
            color: on ? AppColors.accent : AppColors.textSecondary,
          ),
        ),
      ),
      onTap: on ? null : () => _open(open),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final repo = ref.read(settingsRepositoryProvider);
    final rest =
        ref.watch(defaultRestProvider).value ??
        SettingsRepository.defaultRestSeconds;
    final prefs = ref.watch(alertPrefsProvider).value ?? const RestAlertPrefs();

    final alerts = ref.read(restAlertsProvider);
    final status = ref.watch(alertStatusProvider).value;

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
              if (status != null) ...[
                _statusRow(
                  text,
                  title: 'Notifications',
                  on: status.notifications == AlertPermission.granted,
                  offText: 'Off — tap to enable',
                  open: alerts.openNotificationSettings,
                ),
                _statusRow(
                  text,
                  title: 'Precise timing',
                  on: status.exactAlarms,
                  offText: 'Off — alerts may be late while the phone is idle',
                  open: alerts.openExactAlarmSettings,
                ),
              ],
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: Space.m),
            child: Text(
              'Background alerts need notifications. Precise timing makes '
              'them arrive on time.',
              style: text.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
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
