import 'package:fitapp/core/platform_rest_alerts.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('channelFor maps sound/vibrate to channel ids', () {
    expect(channelFor(sound: true, vibrate: true), 'rest_sound_vibrate');
    expect(channelFor(sound: true, vibrate: false), 'rest_sound');
    expect(channelFor(sound: false, vibrate: true), 'rest_vibrate');
    expect(channelFor(sound: false, vibrate: false), 'rest_silent');
  });

  test('restBodyFor includes the exercise name', () {
    expect(restBodyFor('Squat'), 'Time for your next set · Squat');
  });
}
