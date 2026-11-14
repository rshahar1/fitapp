/// Calendar helpers for the History calendar view: local-day keys, Monday-
/// based weeks and month grids.
///
/// Pure Dart. No Flutter, database or I/O imports (constitution principle II).
/// All dates are built with the `DateTime(y, m, d)` constructor (never by
/// adding `Duration`s) so results are daylight-saving safe.
library;

/// Local calendar day (time stripped).
DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// `yyyy-MM-dd` key of the local day of [d] (zero padded).
String dayKey(DateTime d) {
  final y = d.year.toString().padLeft(4, '0');
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '$y-$m-$day';
}

/// The Monday on or before [d] (date only).
DateTime startOfWeek(DateTime d) =>
    DateTime(d.year, d.month, d.day - (d.weekday - 1));

/// The 7 days (Monday to Sunday, date only) of the week containing [d].
List<DateTime> weekDays(DateTime d) {
  final start = startOfWeek(d);
  return [
    for (var i = 0; i < 7; i++)
      DateTime(start.year, start.month, start.day + i),
  ];
}

/// Weeks shown for a month: each a list of 7 date-only days, Monday first,
/// from the week containing the 1st to the week containing the last day.
/// Days outside the month are included.
List<List<DateTime>> monthGrid(int year, int month) {
  final last = DateTime(year, month + 1, 0);
  final weeks = <List<DateTime>>[];
  var start = startOfWeek(DateTime(year, month));
  while (!start.isAfter(last)) {
    weeks.add(weekDays(start));
    start = DateTime(start.year, start.month, start.day + 7);
  }
  return weeks;
}

/// First day of the month [months] (may be negative) away from [d]'s month.
DateTime addMonths(DateTime d, int months) =>
    DateTime(d.year, d.month + months);
