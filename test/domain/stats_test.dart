import 'package:fitapp/domain/progression.dart';
import 'package:fitapp/domain/stats.dart';
import 'package:flutter_test/flutter_test.dart';

LoggedSet s(int no, double w, int r) =>
    LoggedSet(setNo: no, weight: w, reps: r);

void main() {
  group('volume', () {
    final session1 = [s(1, 20, 10), s(2, 20, 10), s(3, 22.5, 6)];
    test('per hand doubles (PRD §11 scenario 3 = 1070)', () {
      expect(volume(session1, perHand: true), 1070);
    });
    test('not per hand', () {
      expect(volume(session1, perHand: false), 535);
    });
    test('empty is 0', () {
      expect(volume(const [], perHand: true), 0);
    });
  });

  group('epley1RM', () {
    test('100 x 10 -> 133.3', () => expect(epley1RM(100, 10), 133.3));
    test('100 x 1 -> 100', () => expect(epley1RM(100, 1), 100));
    test('100 x 0 -> 0', () => expect(epley1RM(100, 0), 0));
  });

  group('personal records', () {
    final history = [s(1, 100, 5), s(2, 90, 10), s(3, 105, 1)];
    test('computes bests', () {
      final pr = personalRecords(history, perHand: false);
      expect(pr.heaviestWeight, 105);
      expect(pr.best1RM, 120); // 90 x 10 -> 120.0
      expect(pr.bestSetVolume, 900);
    });
    test('per hand doubles set volume', () {
      expect(personalRecords(history, perHand: true).bestSetVolume, 1800);
    });
    test('empty history', () {
      final pr = personalRecords(const [], perHand: false);
      expect(pr.heaviestWeight, 0);
      expect(PersonalRecords.empty.best1RM, 0);
    });
    test('newPRTypes: strictly greater only', () {
      final pr = personalRecords(history, perHand: false);
      expect(newPRTypes(s(1, 105, 1), pr, perHand: false), isEmpty);
      expect(newPRTypes(s(1, 107.5, 1), pr, perHand: false), {
        PrType.heaviestWeight,
      });
      expect(newPRTypes(s(1, 95, 10), pr, perHand: false), {
        PrType.best1RM,
        PrType.bestSetVolume,
      });
    });
    test('newPRTypes: zero reps is never a PR', () {
      expect(
        newPRTypes(s(1, 200, 0), PersonalRecords.empty, perHand: false),
        isEmpty,
      );
    });
    test('newPRTypes: first ever set beats empty history', () {
      expect(
        newPRTypes(s(1, 20, 10), PersonalRecords.empty, perHand: true),
        PrType.values.toSet(),
      );
    });
  });

  group('summarizeSession and diffSummary', () {
    final prev = summarizeSession(
      [s(1, 20, 10), s(2, 20, 10), s(3, 22.5, 6)],
      perHand: true,
      overloadSetNo: 3,
    );
    final cur = summarizeSession(
      [s(1, 22.5, 10), s(2, 22.5, 8), s(3, 25, 4)],
      perHand: true,
      overloadSetNo: 3,
    );
    test('summary', () {
      expect(prev.sets, 3);
      expect(prev.reps, 26);
      expect(prev.volume, 1070);
      expect(prev.topWeight, 22.5);
      expect(prev.workingWeight, 20);
      expect(prev.best1RM, 27); // 22.5 x 6 -> 27.0 beats 20 x 10 -> 26.7
    });
    test('working weight without overload set number uses all sets', () {
      final sum = summarizeSession([s(1, 20, 10), s(2, 25, 3)], perHand: false);
      expect(sum.workingWeight, 25);
    });
    test('diff values', () {
      final d = diffSummary(cur, prev)!;
      expect(d.sets.trend, Trend.same);
      expect(d.sets.percent, 0);
      // reps 22 vs 26 -> -15.4 %
      expect(d.reps.trend, Trend.down);
      expect(d.reps.percent, -15.4);
      // volume (225+180+100)*2 = 1010 vs 1070 -> -5.6 %
      expect(cur.volume, 1010);
      expect(d.volume.trend, Trend.down);
      expect(d.volume.percent, -5.6);
      // top 25 vs 22.5 -> +11.1 %
      expect(d.topWeight.trend, Trend.up);
      expect(d.topWeight.percent, 11.1);
    });
    test('first session -> null', () {
      expect(diffSummary(cur, null), isNull);
    });
    test('percent is null when previous is 0', () {
      final d = MetricDelta.of(5, 0);
      expect(d.trend, Trend.up);
      expect(d.percent, isNull);
    });
  });

  group('workoutsPerWeek (Sunday-based weeks)', () {
    test('last 8 weeks keyed by Sunday, zero-filled, oldest first', () {
      final now = DateTime(2026, 11, 12); // week of Sun 8 Nov
      final m = workoutsPerWeek([
        DateTime(2026, 11, 8), // Sunday: this week
        DateTime(2026, 11, 11),
        DateTime(2026, 11, 7, 23), // Saturday: last week
        DateTime(2026, 9, 20), // first bar's Sunday
        DateTime(2026, 9, 19), // out of range
      ], now: now);
      expect(m.length, 8);
      expect(m.keys.first, DateTime(2026, 9, 20));
      expect(m.keys.last, DateTime(2026, 11, 8));
      expect(m[DateTime(2026, 11, 8)], 2);
      expect(m[DateTime(2026, 11)], 1);
      expect(m[DateTime(2026, 9, 20)], 1);
      expect(m.values.reduce((a, b) => a + b), 4);
    });
    test('across the year boundary', () {
      final m = workoutsPerWeek([DateTime(2027)], now: DateTime(2027, 1, 6));
      expect(m.keys.last, DateTime(2027, 1, 3));
      expect(m[DateTime(2026, 12, 27)], 1);
    });
  });

  test('weekBarLabels: day, with the month on the first bar and on change', () {
    expect(
      weekBarLabels([
        DateTime(2026, 10, 18),
        DateTime(2026, 10, 25),
        DateTime(2026, 11),
        DateTime(2026, 11, 8),
      ]),
      ['18 Oct', '25', '1 Nov', '8'],
    );
    expect(weekBarLabels(const []), isEmpty);
  });

  group('weeklyStreak (Sunday-based weeks)', () {
    // Thu 12 Nov 2026; its week runs Sun 8 Nov to Sat 14 Nov.
    final now = DateTime(2026, 11, 12);
    test('in-progress current week does not break the streak', () {
      final dates = [DateTime(2026, 11, 3), DateTime(2026, 10, 28)];
      expect(weeklyStreak(dates, now: now), 2);
    });
    test('current week counts', () {
      final dates = [DateTime(2026, 11, 10), DateTime(2026, 11, 3)];
      expect(weeklyStreak(dates, now: now), 2);
    });
    test('Sunday belongs to the week it starts', () {
      // Sun 8 Nov is this week; Sat 7 Nov is last week.
      expect(weeklyStreak([DateTime(2026, 11, 8)], now: now), 1);
      expect(
        weeklyStreak([DateTime(2026, 11, 8), DateTime(2026, 11, 7)], now: now),
        2,
      );
    });
    test('gap breaks the streak', () {
      final dates = [
        DateTime(2026, 11, 10), // week of 8 Nov
        DateTime(2026, 10, 27), // week of 25 Oct (week of 1 Nov missing)
      ];
      expect(weeklyStreak(dates, now: now), 1);
    });
    test('nothing this or last week -> 0', () {
      expect(weeklyStreak([DateTime(2026, 10, 20)], now: now), 0);
      expect(weeklyStreak(const [], now: now), 0);
    });
    test('across the year boundary', () {
      final now = DateTime(2027, 1, 6); // week of Sun 3 Jan
      final dates = [
        DateTime(2027, 1, 5), // week of 3 Jan
        DateTime(2027), // week of 27 Dec
        DateTime(2026, 12, 22), // week of 20 Dec
      ];
      expect(weeklyStreak(dates, now: now), 3);
    });
  });
}
