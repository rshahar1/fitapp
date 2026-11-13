import 'package:fitapp/data/models.dart';
import 'package:fitapp/data/repositories/activity_repository.dart';
import 'package:fitapp/domain/stats.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  late Harness h;
  late ActivityRepository activities;

  setUp(() {
    h = Harness(); // 2 Nov 2026 is a Monday
    activities = ActivityRepository(h.db);
  });
  tearDown(() => h.close());

  test(
    'This week and weekly bars include activities; Total does not',
    () async {
      await h.plan();
      await h.session(const [(20, 10)]); // Tue 3 Nov
      await activities.create(typeId: 'cycling', startedAt: h.now);
      await activities.create(typeId: 'running', startedAt: h.now);
      final stats = await h.workouts.homeStats(h.now);
      expect(stats.thisWeek, 3);
      expect(stats.total, 1);
      final bars = await h.workouts.watchWorkoutsPerWeek(() => h.now).first;
      expect(bars[isoWeekKey(h.now)], 3);
    },
  );

  test('a week with only an activity keeps the streak', () async {
    await h.plan();
    await h.session(const [(20, 10)]); // week of 2 Nov
    h.advance(const Duration(days: 7)); // week of 9 Nov
    await activities.create(typeId: 'snowboarding', startedAt: h.now);
    h.advance(const Duration(days: 7)); // week of 16 Nov
    await h.session(const [(20, 10)]);
    expect((await h.workouts.homeStats(h.now)).streak, 3);
  });

  test('history entries merge workouts and activities newest first', () async {
    await h.plan();
    final (w, _) = await h.session(const [(20, 10)]);
    final a = await activities.create(
      typeId: 'running',
      startedAt: h.now.add(const Duration(hours: 1)),
    );
    final old = await activities.create(
      typeId: 'cycling',
      startedAt: h.now.subtract(const Duration(days: 5)),
    );
    final entries = await h.workouts.historyEntries();
    expect(entries.map((e) => e.id), [a, w, old]);
    expect(entries[0], isA<ActivityHistoryEntry>());
    expect(entries[1], isA<WorkoutHistoryEntry>());
    expect((await h.workouts.watchHistoryEntries().first).map((e) => e.id), [
      a,
      w,
      old,
    ]);
  });

  test('only activities: history is not empty', () async {
    await activities.create(typeId: 'running', startedAt: h.now);
    expect(await h.workouts.historyEntries(), hasLength(1));
    expect((await h.workouts.homeStats(h.now)).total, 0);
  });
}
