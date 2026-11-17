import 'package:fitapp/data/repositories/settings_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  late Harness h;
  setUp(() => h = Harness());
  tearDown(() => h.close());

  test('nothing is dirty or stamped initially', () async {
    expect(await h.settings.syncedSettingsDirty(), isFalse);
    expect(await h.settings.syncedSettingsUpdatedAt(), isNull);
    expect(await h.settings.syncedSettings(), isEmpty);
  });

  test('stamps updated_at and dirty when default rest is written', () async {
    await h.settings.setDefaultRestSeconds(90);
    expect(await h.settings.syncedSettingsDirty(), isTrue);
    expect(await h.settings.syncedSettingsUpdatedAt(), h.now);
  });

  test('stamps when alert prefs are written', () async {
    h.advance();
    await h.settings.setAlertPrefs(const RestAlertPrefs(haptic: false));
    expect(await h.settings.syncedSettingsDirty(), isTrue);
    expect(await h.settings.syncedSettingsUpdatedAt(), h.now);
  });

  test('does not stamp for non-whitelisted keys', () async {
    await h.settings.writeActiveRest(
      ActiveRest(startedAt: h.now, targetSeconds: 60, exerciseName: 'Bench'),
    );
    await h.settings.markNotificationPermissionAsked();
    expect(await h.settings.syncedSettingsDirty(), isFalse);
    expect(await h.settings.syncedSettingsUpdatedAt(), isNull);
    expect(await h.settings.syncedSettings(), isEmpty);
  });

  test('syncedSettings returns typed whitelisted values', () async {
    await h.settings.setDefaultRestSeconds(90);
    await h.settings.setAlertPrefs(const RestAlertPrefs(haptic: false));
    await h.settings.markNotificationPermissionAsked();
    expect(await h.settings.syncedSettings(), {
      'default_rest_seconds': 90,
      'rest_alert_haptic': false,
      'rest_alert_sound': true,
    });
  });

  test('syncedSettings only includes keys that exist', () async {
    await h.settings.setDefaultRestSeconds(45);
    expect(await h.settings.syncedSettings(), {'default_rest_seconds': 45});
  });

  test('rest between exercises defaults to 120 and normalizes', () async {
    expect(await h.settings.restBetweenExercises(), 120);
    await h.settings.setRestBetweenExercisesSeconds(93);
    expect(await h.settings.restBetweenExercises(), 95);
    await h.settings.setRestBetweenExercisesSeconds(5000);
    expect(await h.settings.restBetweenExercises(), 600);
    expect(await h.settings.syncedSettingsDirty(), isTrue);
  });

  test('rest between exercises is synced and applied', () async {
    expect(await h.settings.syncedSettings(), isEmpty);
    await h.settings.setRestBetweenExercisesSeconds(150);
    expect(await h.settings.syncedSettings(), {
      'rest_between_exercises_seconds': 150,
    });
    await h.settings.applySyncedSettings({
      'rest_between_exercises_seconds': 203,
    }, h.now.add(const Duration(hours: 1)));
    expect(await h.settings.restBetweenExercises(), 205);
  });

  test('markClean clears dirty when the stamp is unchanged', () async {
    await h.settings.setDefaultRestSeconds(90);
    final sent = (await h.settings.syncedSettingsUpdatedAt())!;
    await h.settings.markSyncedSettingsClean(sent);
    expect(await h.settings.syncedSettingsDirty(), isFalse);
  });

  test('markClean keeps dirty when re-written after the read', () async {
    await h.settings.setDefaultRestSeconds(90);
    final sent = (await h.settings.syncedSettingsUpdatedAt())!;
    h.advance(const Duration(seconds: 5));
    await h.settings.setDefaultRestSeconds(120);
    await h.settings.markSyncedSettingsClean(sent);
    expect(await h.settings.syncedSettingsDirty(), isTrue);
  });

  test('apply writes values without marking dirty', () async {
    final at = h.now.add(const Duration(hours: 1));
    await h.settings.applySyncedSettings({
      'default_rest_seconds': 120,
      'rest_alert_haptic': false,
      'rest_alert_sound': false,
    }, at);
    expect(await h.settings.defaultRest(), 120);
    expect(
      await h.settings.alertPrefs(),
      const RestAlertPrefs(haptic: false, sound: false),
    );
    expect(await h.settings.syncedSettingsDirty(), isFalse);
    expect(await h.settings.syncedSettingsUpdatedAt(), at);
  });

  test('apply is ignored when local is dirty and newer', () async {
    await h.settings.setDefaultRestSeconds(90);
    await h.settings.applySyncedSettings({
      'default_rest_seconds': 200,
    }, h.now.subtract(const Duration(minutes: 1)));
    expect(await h.settings.defaultRest(), 90);
    expect(await h.settings.syncedSettingsDirty(), isTrue);
    expect(await h.settings.syncedSettingsUpdatedAt(), h.now);
  });

  test('apply wins when local is dirty but older', () async {
    await h.settings.setDefaultRestSeconds(90);
    await h.settings.applySyncedSettings({
      'default_rest_seconds': 200,
    }, h.now.add(const Duration(minutes: 1)));
    expect(await h.settings.defaultRest(), 200);
  });

  test('apply wins over clean local state even if remote is older', () async {
    await h.settings.setDefaultRestSeconds(90);
    await h.settings.markSyncedSettingsClean(h.now);
    await h.settings.applySyncedSettings({
      'default_rest_seconds': 200,
    }, h.now.subtract(const Duration(minutes: 1)));
    expect(await h.settings.defaultRest(), 200);
  });
}
