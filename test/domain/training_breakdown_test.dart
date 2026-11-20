import 'package:fitapp/domain/training_breakdown.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Wed 18 Nov 2026; its week runs Sun 15 Nov to Sat 21 Nov.
  final now = DateTime(2026, 11, 18, 12);

  group('isSameWeek (Sunday to Saturday)', () {
    test('Sunday and Saturday of one week match', () {
      expect(isSameWeek(DateTime(2026, 11, 15), now), isTrue);
      expect(isSameWeek(DateTime(2026, 11, 21, 23, 59), now), isTrue);
    });
    test('previous Saturday and next Sunday do not', () {
      expect(isSameWeek(DateTime(2026, 11, 14, 23, 59), now), isFalse);
      expect(isSameWeek(DateTime(2026, 11, 22), now), isFalse);
    });
    test('week across a month and year boundary', () {
      // Sun 27 Dec 2026 to Sat 2 Jan 2027.
      expect(isSameWeek(DateTime(2026, 12, 27), DateTime(2027, 1, 2)), isTrue);
      expect(isSameWeek(DateTime(2026, 12, 26), DateTime(2027, 1, 2)), isFalse);
    });
  });

  group('trainingBreakdown', () {
    test('counts this week and all time per type, sorted', () {
      final b = trainingBreakdown([
        TrainingSession(gymTypeId, DateTime(2026, 11, 16)),
        TrainingSession(gymTypeId, DateTime(2026, 11, 17)),
        TrainingSession('cycling', DateTime(2026, 11, 15)),
        TrainingSession('pilates', DateTime(2026, 11, 14)), // last Saturday
        TrainingSession('pilates', DateTime(2026, 11, 7)),
        TrainingSession('running', DateTime(2026, 11)),
      ], now: now);
      expect(
        [for (final t in b) (t.typeId, t.thisWeek, t.allTime)],
        [
          (gymTypeId, 2, 2),
          ('cycling', 1, 1),
          ('pilates', 0, 2),
          ('running', 0, 1),
        ],
      );
    });

    test('ties: gym first, then registry order', () {
      final b = trainingBreakdown([
        TrainingSession('pilates', DateTime(2026, 11, 16)),
        TrainingSession('cycling', DateTime(2026, 11, 16)),
        TrainingSession(gymTypeId, DateTime(2026, 11, 16)),
      ], now: now);
      expect(b.map((t) => t.typeId), [gymTypeId, 'cycling', 'pilates']);
    });

    test('unknown activity ids group under one "activity" type', () {
      final b = trainingBreakdown([
        TrainingSession('kayak', DateTime(2026, 11, 16)),
        TrainingSession('climbing', DateTime(2026, 11)),
      ], now: now);
      expect(b, hasLength(1));
      expect(b.single.typeId, unknownActivityTypeId);
      expect((b.single.thisWeek, b.single.allTime), (1, 2));
    });

    test('empty input -> empty list', () {
      expect(trainingBreakdown(const [], now: now), isEmpty);
    });
  });

  test('trainingTypeLabel', () {
    expect(trainingTypeLabel(gymTypeId), 'Gym');
    expect(trainingTypeLabel('pilates'), 'Pilates');
    expect(trainingTypeLabel(unknownActivityTypeId), 'Activity');
  });

  test('isSameMonth uses local calendar months', () {
    expect(
      isSameMonth(DateTime(2026, 11, 2), DateTime(2026, 11, 30, 23)),
      isTrue,
    );
    expect(
      isSameMonth(DateTime(2026, 10, 31, 23), DateTime(2026, 11, 2)),
      isFalse,
    );
    expect(isSameMonth(DateTime(2025, 11, 5), DateTime(2026, 11, 5)), isFalse);
  });

  test('activeTypes keeps only types with sessions this week, in order', () {
    const all = [
      TypeCount(gymTypeId, thisWeek: 2, allTime: 9),
      TypeCount('running', thisWeek: 1, allTime: 3),
      TypeCount('cycling', thisWeek: 0, allTime: 7),
    ];
    expect(activeTypes(all).map((t) => t.typeId), [gymTypeId, 'running']);
    expect(
      activeTypes(const [TypeCount('cycling', thisWeek: 0, allTime: 1)]),
      isEmpty,
    );
  });
}
