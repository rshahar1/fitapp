import 'package:fitapp/domain/calendar.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('dateOnly', () {
    test('strips time', () {
      expect(dateOnly(DateTime(2026, 3, 5, 18, 30)), DateTime(2026, 3, 5));
    });
  });

  group('dayKey', () {
    test('zero pads month and day', () {
      expect(dayKey(DateTime(2026, 3, 5, 23, 59)), '2026-03-05');
    });
    test('two digit parts', () {
      expect(dayKey(DateTime(2026, 11, 3)), '2026-11-03');
    });
  });

  group('startOfWeek', () {
    test('Monday is itself', () {
      expect(startOfWeek(DateTime(2026, 11, 2, 10)), DateTime(2026, 11, 2));
    });
    test('Sunday goes back six days', () {
      expect(startOfWeek(DateTime(2026, 11)), DateTime(2026, 10, 26));
    });
    test('across year boundary', () {
      expect(startOfWeek(DateTime(2026)), DateTime(2025, 12, 29));
    });
    test('across month boundary', () {
      expect(startOfWeek(DateTime(2026, 4, 2)), DateTime(2026, 3, 30));
    });
  });

  group('weekDays', () {
    test('seven days Monday to Sunday', () {
      final days = weekDays(DateTime(2026, 11, 4, 9));
      expect(days, hasLength(7));
      expect(days.first, DateTime(2026, 11, 2));
      expect(days.last, DateTime(2026, 11, 8));
      expect(days.first.weekday, DateTime.monday);
      expect(days.last.weekday, DateTime.sunday);
    });
  });

  group('monthGrid', () {
    void expectConsecutive(List<List<DateTime>> grid) {
      for (final week in grid) {
        expect(week, hasLength(7));
        expect(week.first.weekday, DateTime.monday);
        for (var i = 1; i < 7; i++) {
          expect(
            week[i],
            DateTime(week[0].year, week[0].month, week[0].day + i),
          );
        }
      }
      for (var w = 1; w < grid.length; w++) {
        final prev = grid[w - 1].first;
        expect(grid[w].first, DateTime(prev.year, prev.month, prev.day + 7));
      }
    }

    test('Feb 2021 starts Monday and has exactly 4 weeks', () {
      final grid = monthGrid(2021, 2);
      expect(grid, hasLength(4));
      expect(grid.first.first, DateTime(2021, 2));
      expect(grid.last.last, DateTime(2021, 2, 28));
      expectConsecutive(grid);
    });

    test('Nov 2026 starts on Sunday and has 6 weeks', () {
      final grid = monthGrid(2026, 11);
      expect(grid, hasLength(6));
      expect(grid.first.first, DateTime(2026, 10, 26));
      expect(grid.last.last, DateTime(2026, 12, 6));
      expectConsecutive(grid);
    });

    test('regular month (Jun 2026)', () {
      final grid = monthGrid(2026, 6);
      expect(grid, hasLength(5));
      expect(grid.first.first, DateTime(2026, 6));
      expect(grid.last.last, DateTime(2026, 7, 5));
      expectConsecutive(grid);
    });

    test('all months of 2026 give 4..6 consecutive weeks', () {
      for (var m = 1; m <= 12; m++) {
        final grid = monthGrid(2026, m);
        expect(grid.length, inInclusiveRange(4, 6));
        expectConsecutive(grid);
      }
    });
  });

  group('addMonths', () {
    test('returns first of month', () {
      expect(addMonths(DateTime(2026, 5, 17), 0), DateTime(2026, 5));
    });
    test('January minus one is December of previous year', () {
      expect(addMonths(DateTime(2026, 1, 20), -1), DateTime(2025, 12));
    });
    test('December plus one is January of next year', () {
      expect(addMonths(DateTime(2026, 12, 31), 1), DateTime(2027));
    });
    test('plus 13', () {
      expect(addMonths(DateTime(2026, 1, 15), 13), DateTime(2027, 2));
    });
    test('minus 13', () {
      expect(addMonths(DateTime(2026, 1, 15), -13), DateTime(2024, 12));
    });
  });
}
