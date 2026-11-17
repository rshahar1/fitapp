import 'package:fitapp/core/format.dart';
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

  group('stepWindow', () {
    final now = DateTime(2026, 11, 15, 17, 30);

    test('today runs from midnight to now', () {
      final w = stepWindow(DateTime(2026, 11, 15), now)!;
      expect(w.start, DateTime(2026, 11, 15));
      expect(w.end, now);
    });

    test('past day is the full local day', () {
      final w = stepWindow(DateTime(2026, 11, 10), now)!;
      expect(w.start, DateTime(2026, 11, 10));
      expect(w.end, DateTime(2026, 11, 11));
    });

    test('future day is null', () {
      expect(stepWindow(DateTime(2026, 11, 16), now), isNull);
    });

    test('31 days ago is null, 30 days ago is a window', () {
      expect(stepWindow(DateTime(2026, 10, 15), now), isNull);
      final w = stepWindow(DateTime(2026, 10, 16), now)!;
      expect(w.start, DateTime(2026, 10, 16));
      expect(w.end, DateTime(2026, 10, 17));
    });

    test('day end uses calendar arithmetic across month ends', () {
      final w = stepWindow(DateTime(2026, 10, 31), now)!;
      expect(w.end, DateTime(2026, 11));
    });

    test('a time of day in the key still maps to that local day', () {
      final w = stepWindow(DateTime(2026, 11, 10, 13), now)!;
      expect(w.start, DateTime(2026, 11, 10));
    });

    test('DST day is bounded by local midnights', () {
      // Whatever the machine zone, end is the next local midnight.
      final w = stepWindow(DateTime(2026, 3, 29), DateTime(2026, 4, 5, 12))!;
      expect(w.start, DateTime(2026, 3, 29));
      expect(w.end, DateTime(2026, 3, 30));
    });
  });

  test('distance is unavailable on Noop and off Android', () async {
    final t = DateTime(2026);
    expect(await const NoopStepSource().distanceBetween(t, t), isNull);
    final s = HealthConnectStepSource(isAndroid: false);
    expect(await s.distanceAccess(), isFalse);
    expect(await s.distanceBetween(t, t), isNull);
  });

  test('formatKm shows kilometres with two decimals', () {
    expect(formatKm(0), '0.00 km');
    expect(formatKm(6213), '6.21 km');
  });
}
