import 'package:fitapp/domain/workout_dates.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('shiftToDay', () {
    test('moves to the chosen local day, keeping the local time of day', () {
      final start = DateTime(2026, 11, 10, 18, 30, 15).toUtc();
      final moved = shiftToDay(start, DateTime(2026, 11, 8));
      expect(moved.isUtc, isTrue);
      final local = moved.toLocal();
      expect([local.year, local.month, local.day], [2026, 11, 8]);
      expect([local.hour, local.minute, local.second], [18, 30, 15]);
    });

    test('same day is a no-op', () {
      final start = DateTime(2026, 11, 10, 7, 5).toUtc();
      expect(shiftToDay(start, DateTime(2026, 11, 10, 23)), start);
    });

    test('works across month and year boundaries', () {
      final start = DateTime(2026, 1, 2, 9).toUtc();
      final local = shiftToDay(start, DateTime(2025, 12, 31)).toLocal();
      expect(
        [local.year, local.month, local.day, local.hour],
        [2025, 12, 31, 9],
      );
    });
  });

  group('liveDuration', () {
    final since = DateTime.utc(2026, 11, 10, 18);

    test('adds the live time to the earlier duration', () {
      expect(
        liveDuration(
          priorSeconds: 3000,
          liveSince: since,
          now: since.add(const Duration(minutes: 10)),
        ),
        const Duration(minutes: 60),
      );
    });

    test('never negative when the clock went backwards', () {
      expect(
        liveDuration(
          priorSeconds: 60,
          liveSince: since,
          now: since.subtract(const Duration(hours: 1)),
        ),
        const Duration(seconds: 60),
      );
    });
  });

  group('checkWorkoutDay', () {
    final now = DateTime(2026, 11, 13, 9);

    test('accepts today and past days', () {
      expect(
        () => checkWorkoutDay(DateTime(2026, 11, 13, 23), now),
        returnsNormally,
      );
      expect(
        () => checkWorkoutDay(DateTime(2021, 11, 13), now),
        returnsNormally,
      );
    });

    test('rejects future days', () {
      expect(
        () => checkWorkoutDay(DateTime(2026, 11, 14), now),
        throwsArgumentError,
      );
    });
  });
}
