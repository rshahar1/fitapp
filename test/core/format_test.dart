import 'package:fitapp/core/format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formatSteps', () {
    expect(formatSteps(0), '0 steps');
    expect(formatSteps(1), '1 step');
    expect(formatSteps(8432), '8,432 steps');
  });
  test('formatWeight', () {
    expect(formatWeight(20), '20');
    expect(formatWeight(22.5), '22.5');
    expect(formatWeight(22.25), '22.25');
  });
  test('formatKg', () => expect(formatKg(22.5), '22.5 kg'));
  test('formatVolume', () {
    expect(formatVolume(1070), '1,070 kg');
    expect(formatVolume(1070.54), '1,070.5 kg');
    expect(formatVolume(0), '0 kg');
  });
  test('formatClock', () {
    expect(formatClock(const Duration(seconds: 42)), '0:42');
    expect(formatClock(const Duration(minutes: 12, seconds: 5)), '12:05');
    expect(
      formatClock(const Duration(hours: 1, minutes: 2, seconds: 5)),
      '1:02:05',
    );
  });
  test('formatShortDuration', () {
    expect(formatShortDuration(const Duration(seconds: 30)), '<1m');
    expect(formatShortDuration(const Duration(minutes: 45)), '45m');
    expect(formatShortDuration(const Duration(hours: 1, minutes: 5)), '1h 5m');
  });
  test('formatRest', () {
    expect(formatRest(const Duration(minutes: 1)), '1:00');
    expect(formatRest(const Duration(seconds: 5)), '0:05');
    expect(formatRest(const Duration(seconds: -12)), '+0:12');
  });
  test('formatPercent', () {
    expect(formatPercent(11.1), '+11.1%');
    expect(formatPercent(-5.6), '-5.6%');
    expect(formatPercent(0), '0%');
    expect(formatPercent(null), '—');
  });
  test('dates', () {
    expect(formatDateShort(DateTime(2026, 11, 12)), 'Thu, 12 Nov');
    expect(formatMonth(DateTime(2026, 11, 12)), 'November 2026');
  });
}
