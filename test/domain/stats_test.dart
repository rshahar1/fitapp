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

  group('ISO weeks', () {
    test('9 Nov 2026 -> 2026-W46', () {
      expect(isoWeekKey(DateTime(2026, 11, 9)), '2026-W46');
    });
    test('1 Jan 2027 -> 2026-W53', () {
      expect(isoWeekKey(DateTime(2027)), '2026-W53');
    });
    test('other boundaries', () {
      expect(isoWeekKey(DateTime(2026, 12, 31)), '2026-W53');
      expect(isoWeekKey(DateTime(2027, 1, 4)), '2027-W01');
      expect(isoWeekKey(DateTime(2026)), '2026-W01');
      expect(isoWeekKey(DateTime(2024, 12, 30)), '2025-W01');
    });
    test('monday', () {
      expect(
        isoWeekMonday(DateTime(2026, 11, 15, 23)),
        DateTime.utc(2026, 11, 9),
      );
    });
  });

  group('workoutsPerWeek', () {
    test('last 8 weeks, zero-filled, oldest first', () {
      final now = DateTime(2026, 11, 12);
      final m = workoutsPerWeek([
        DateTime(2026, 11, 9),
        DateTime(2026, 11, 11),
        DateTime(2026, 10),
        DateTime(2025), // out of range
      ], now: now);
      expect(m.length, 8);
      expect(m.keys.first, '2026-W39');
      expect(m.keys.last, '2026-W46');
      expect(m['2026-W46'], 2);
      expect(m['2026-W40'], 1);
      expect(m.values.reduce((a, b) => a + b), 3);
    });
  });

  group('weeklyStreak', () {
    test('in-progress current week does not break the streak', () {
      final now = DateTime(2026, 11, 12); // W46, nothing yet this week
      final dates = [DateTime(2026, 11, 3), DateTime(2026, 10, 28)]; // W45,W44
      expect(weeklyStreak(dates, now: now), 2);
    });
    test('current week counts', () {
      final now = DateTime(2026, 11, 12);
      final dates = [DateTime(2026, 11, 10), DateTime(2026, 11, 3)];
      expect(weeklyStreak(dates, now: now), 2);
    });
    test('gap breaks the streak', () {
      final now = DateTime(2026, 11, 12);
      final dates = [
        DateTime(2026, 11, 10), // W46
        DateTime(2026, 10, 27), // W44 (W45 missing)
      ];
      expect(weeklyStreak(dates, now: now), 1);
    });
    test('nothing this or last week -> 0', () {
      final now = DateTime(2026, 11, 12);
      expect(weeklyStreak([DateTime(2026, 10, 20)], now: now), 0);
      expect(weeklyStreak(const [], now: now), 0);
    });
    test('across the year boundary with ISO week 53', () {
      final now = DateTime(2027, 1, 6); // 2027-W01
      final dates = [
        DateTime(2027, 1, 5), // 2027-W01
        DateTime(2027), // 2026-W53
        DateTime(2026, 12, 22), // 2026-W52
      ];
      expect(weeklyStreak(dates, now: now), 3);
    });
  });
}
