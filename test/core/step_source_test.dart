import 'package:fitapp/core/health_connect_step_source.dart';
import 'package:fitapp/core/step_source.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('todayStart is local midnight of the same day', () {
    final now = DateTime(2026, 11, 15, 17, 42, 9);
    expect(todayStart(now), DateTime(2026, 11, 15));
  });

  test('todayStart converts UTC instants to the local day', () {
    final now = DateTime.utc(2026, 11, 15, 12);
    final local = now.toLocal();
    expect(todayStart(now), DateTime(local.year, local.month, local.day));
  });

  test('NoopStepSource is unavailable', () async {
    const s = NoopStepSource();
    expect(await s.access(), StepAccess.unavailable);
    expect(await s.requestAccess(), isFalse);
    expect(await s.stepsBetween(DateTime(2026), DateTime(2027)), isNull);
  });

  test('HealthConnectStepSource is unavailable off Android', () async {
    final s = HealthConnectStepSource(isAndroid: false);
    expect(await s.access(), StepAccess.unavailable);
    expect(await s.requestAccess(), isFalse);
    expect(await s.stepsBetween(DateTime(2026), DateTime(2027)), isNull);
  });
}
