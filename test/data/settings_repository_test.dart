import 'package:fitapp/data/repositories/settings_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  late Harness h;
  setUp(() => h = Harness());
  tearDown(() => h.close());

  group('default rest', () {
    test('is 60 when unset', () async {
      expect(await h.settings.defaultRest(), 60);
    });

    for (final (input, expected) in [
      (7, 10),
      (62, 60),
      (63, 65),
      (1000, 600),
      (0, 10),
      (-5, 10),
      (600, 600),
    ]) {
      test('set $input -> $expected', () async {
        await h.settings.setDefaultRestSeconds(input);
        expect(await h.settings.defaultRest(), expected);
      });
    }

    test('watch emits the new value', () async {
      final values = <int>[];
      final sub = h.settings.watchDefaultRestSeconds().listen(values.add);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await h.settings.setDefaultRestSeconds(90);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await sub.cancel();
      expect(values.first, 60);
      expect(values.last, 90);
    });
  });

  group('alert prefs', () {
    test('default to haptic and sound on', () async {
      final p = await h.settings.alertPrefs();
      expect(p.haptic, isTrue);
      expect(p.sound, isTrue);
    });

    test('round-trip', () async {
      await h.settings.setAlertPrefs(const RestAlertPrefs(haptic: false));
      expect(
        await h.settings.alertPrefs(),
        const RestAlertPrefs(haptic: false),
      );
      await h.settings.setAlertPrefs(const RestAlertPrefs(sound: false));
      expect(await h.settings.alertPrefs(), const RestAlertPrefs(sound: false));
    });
  });

  group('active rest', () {
    test('null when unset', () async {
      expect(await h.settings.readActiveRest(), isNull);
    });

    test('round-trip and clear', () async {
      final rest = ActiveRest(startedAt: h.now, targetSeconds: 90);
      await h.settings.writeActiveRest(rest);
      expect(await h.settings.readActiveRest(), rest);
      await h.settings.writeActiveRest(null);
      expect(await h.settings.readActiveRest(), isNull);
    });
  });
}
