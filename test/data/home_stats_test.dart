import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  late Harness h;
  setUp(() => h = Harness());
  tearDown(() => h.close());

  test('homeStats: thisWeek, allTime, streak, recent 3', () async {
    await h.plan();
    // h.now starts Mon 2026-11-02 18:00; each session starts a day later.
    h.now = DateTime.utc(
      2026,
      10,
      20,
      12,
    ); // -> Wed Oct 21 (week of Sun Oct 18)
    await h.session([(20, 10)]);
    h.now = DateTime.utc(2026, 10, 27, 12); // -> Wed Oct 28 (week of Oct 25)
    await h.session([(20, 10)]);
    h.now = DateTime.utc(2026, 11, 3, 12); // -> Wed Nov 4 (week of Nov 1)
    await h.session([(20, 10)]);
    h.now = DateTime.utc(2026, 11, 9, 12); // -> Tue Nov 10 (week of Nov 8)
    await h.session([(20, 10)]);
    await h.session([(20, 10)]); // Wed Nov 11 (week of Nov 8)

    final now = DateTime.utc(2026, 11, 12, 12);
    final s = await h.workouts.homeStats(now);
    expect(s.allTime, 5);
    expect(s.thisWeek, 2);
    expect(s.streak, 4);
    expect(s.recent, hasLength(3));
    expect(
      s.recent.map((r) => r.startedAt).toList(),
      [...s.recent.map((r) => r.startedAt)]..sort((a, b) => b.compareTo(a)),
    );
  });

  test('streak across the year boundary (Sunday weeks)', () async {
    await h.plan();
    h.now = DateTime.utc(2026, 12, 21, 12);
    await h.session([(20, 10)]); // 2026-12-22 W52
    h.now = DateTime.utc(2026, 12, 31, 12);
    await h.session([(20, 10)]); // 2027-01-01 W53
    h.now = DateTime.utc(2027, 1, 4, 12);
    await h.session([(20, 10)]); // 2027-01-05 W01
    final s = await h.workouts.homeStats(DateTime.utc(2027, 1, 6, 12));
    expect(s.streak, 3);
    expect(s.allTime, 3);
  });

  test('watchWorkoutsPerWeek has 8 keys', () async {
    final m = await h.workouts
        .watchWorkoutsPerWeek(() => DateTime.utc(2026, 11, 12, 12))
        .first;
    expect(m, hasLength(8));
    expect(m.keys.last, DateTime(2026, 11, 8)); // Thu 12 Nov's Sunday
  });
}
