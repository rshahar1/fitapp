// Two phones on one account converge (US2, US3, SC-007).
import 'package:fitapp/data/repositories/settings_repository.dart';
import 'package:fitapp/data/sync/sync_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';
import 'fake_sync_remote.dart';
import 'sync_test_utils.dart';

void main() {
  late FakeSyncRemote remote;
  late Device a;
  late Device b;

  setUp(() async {
    remote = FakeSyncRemote();
    a = Device(remote);
    b = Device(remote);
    await a.init();
    await b.init();
  });
  tearDown(() async {
    await a.close();
    await b.close();
  });

  Future<void> syncBoth() async {
    expect(await a.sync.syncNow(), SyncOutcome.ok);
    expect(await b.sync.syncNow(), SyncOutcome.ok);
    expect(await a.sync.syncNow(), SyncOutcome.ok);
  }

  Future<void> expectConverged() async {
    expect(await b.snapshot(), await a.snapshot());
    expect(await a.dirtyCount(), 0);
    expect(await b.dirtyCount(), 0);
  }

  test('restore: a fresh phone gets the full history (SC-001)', () async {
    await a.h.plan();
    await a.h.session([(20, 10), (20, 10), (20, 10)]);
    await a.h.session([(22.5, 10), (22.5, 10), (22.5, 10)]);
    await a.templates.create(name: 'Push', exerciseIds: [inclineId, latId]);
    await a.activities.create(
      typeId: 'running',
      startedAt: a.h.now,
      durationMinutes: 30,
      distanceMeters: 5000,
    );
    await a.h.exercises.createCustom(
      name: 'Zercher squat',
      perHand: false,
      increment: 2.5,
    );
    await a.h.exercises.delete(latId);
    await a.h.settings.setDefaultRestSeconds(120);
    await a.sync.syncNow();

    expect(await b.sync.restore(), SyncOutcome.ok);

    await expectConverged();
    expect(await b.h.settings.defaultRest(), 120);
    // Progression continues from the restored plan (US2 scenario 3).
    expect(await b.h.base(), await a.h.base());
    final lat = await b.h.exercises.exercise(latId);
    expect(lat!.deletedAt, isNotNull, reason: 'hidden built-in stays hidden');
  });

  test('restore is paged', () async {
    for (var i = 0; i < 5; i++) {
      await a.h.session([(20, 10), (20, 10)]);
    }
    await a.sync.syncNow();

    final small = Device(remote, pullPageSize: 3);
    await small.init();
    expect(await small.sync.restore(), SyncOutcome.ok);
    expect(await small.count('SELECT COUNT(*) FROM sets'), 10);
    expect(await small.snapshot(), await a.snapshot());
    await small.close();
  });

  test('interrupted restore continues without duplicates (US2 s2)', () async {
    for (var i = 0; i < 3; i++) {
      await a.h.session([(20, 10)]);
    }
    await a.sync.syncNow();
    remote.failNext = true;
    expect(await b.sync.restore(), SyncOutcome.failed);
    expect(await b.sync.syncNow(), SyncOutcome.ok);
    await expectConverged();
  });

  test('changes on one phone reach the other (FR-016)', () async {
    final (w, _) = await a.h.session([(20, 10)]);
    await syncBoth();
    await expectConverged();

    b.h.advance(const Duration(hours: 1));
    await b.h.workouts.setWorkoutDay(w, b.h.now);
    await b.activities.create(typeId: 'cycling', startedAt: b.h.now);
    await syncBoth();
    await expectConverged();
  });

  test(
    'conflicting plan edits: the most recent wins on both (FR-017)',
    () async {
      await a.h.plan(base: 20);
      await syncBoth();

      a.h.advance(const Duration(minutes: 1));
      await a.h.plan(base: 25);
      b.h.advance(const Duration(minutes: 2));
      await b.h.plan(base: 30); // later edit, synced first or second
      await a.sync.syncNow();
      await b.sync.syncNow();
      await a.sync.syncNow();

      expect(await a.h.base(), 30);
      expect(await b.h.base(), 30);
      await expectConverged();
    },
  );

  test('delete beats an offline edit and never comes back', () async {
    final (w, _) = await a.h.session([(20, 10)]);
    await syncBoth();

    await a.h.workouts.deleteWorkout(w);
    b.h.advance(); // B's edit is "newer"
    await b.h.workouts.setWorkoutDay(w, b.h.now);
    await a.sync.syncNow();
    await b.sync.syncNow();
    await a.sync.syncNow();
    await b.sync.syncNow();

    expect(await a.count('SELECT COUNT(*) FROM workouts'), 0);
    expect(await b.count('SELECT COUNT(*) FROM workouts'), 0);
    expect(await b.count('SELECT COUNT(*) FROM sets'), 0);
    await expectConverged();
  });

  test('template deleted on one phone while used on the other', () async {
    final t = await a.templates.create(name: 'Push', exerciseIds: [inclineId]);
    await syncBoth();

    await a.templates.delete(t);
    final w = await b.templates.startWorkout(t);
    final we =
        (await b.h.db
                .customSelect(
                  "SELECT id FROM workout_exercises WHERE workout_id = '$w'",
                )
                .getSingle())
            .read<String>('id');
    await b.h.workouts.logSet(we, setNo: 1, weight: 20, reps: 10);
    await b.h.workouts.finishWorkout(w);
    await syncBoth();

    expect(await b.count('SELECT COUNT(*) FROM templates'), 0);
    expect(await a.count('SELECT COUNT(*) FROM workouts'), 1);
    await expectConverged();
  });

  test('same set number logged on both phones keeps one set', () async {
    final w = await a.h.workouts.startWorkout();
    final we = await a.h.workouts.addExercise(w.id, inclineId);
    await syncBoth();

    await a.h.workouts.logSet(we.id, setNo: 1, weight: 20, reps: 10);
    b.h.advance(const Duration(minutes: 1));
    await b.h.workouts.logSet(we.id, setNo: 1, weight: 22.5, reps: 8);
    await syncBoth();
    await b.sync.syncNow();

    expect(await a.count('SELECT COUNT(*) FROM sets'), 1);
    expect(await b.count('SELECT COUNT(*) FROM sets'), 1);
    expect(remote.live('sets'), hasLength(1));
    expect(remote.live('sets').single['weight'], 22.5);
    await expectConverged();
  });

  test('merge: template name clash keeps both, one renamed (FR-023)', () async {
    await a.templates.create(name: 'Push', exerciseIds: [inclineId]);
    await b.templates.create(name: 'push', exerciseIds: [latId]);
    await syncBoth();
    await b.sync.syncNow();

    final names =
        (await a.h.db
                .customSelect('SELECT name FROM templates ORDER BY name')
                .get())
            .map((r) => r.read<String>('name'))
            .toList();
    expect(names, hasLength(2));
    expect(names.map((n) => n.toLowerCase()).toSet(), hasLength(2));
    expect(names.any((n) => n.endsWith(' (2)')), isTrue);
    await expectConverged();
  });

  test('merge: custom exercise name clash keeps both', () async {
    await a.h.exercises.createCustom(
      name: 'Zercher squat',
      perHand: false,
      increment: 2.5,
    );
    await b.h.exercises.createCustom(
      name: 'Zercher Squat',
      perHand: false,
      increment: 5,
    );
    await syncBoth();
    await b.sync.syncNow();

    expect(
      await a.count('SELECT COUNT(*) FROM exercises WHERE is_custom = 1'),
      2,
    );
    await expectConverged();
  });

  test(
    'a newer local unsynced edit is not overwritten by a pull (FR-019)',
    () async {
      await a.h.settings.setDefaultRestSeconds(90);
      await a.sync.syncNow();
      b.h.advance(const Duration(hours: 1));
      await b.h.settings.setDefaultRestSeconds(150);
      await b.sync.syncNow();
      await a.sync.syncNow();
      expect(await a.h.settings.defaultRest(), 150);
      expect(await b.h.settings.defaultRest(), 150);
    },
  );

  test('settings defaults are left alone when nothing was synced', () async {
    await b.sync.restore();
    expect(
      await b.h.settings.defaultRest(),
      SettingsRepository.defaultRestSeconds,
    );
  });

  test('pull notifies watchers so screens refresh', () async {
    await a.h.session([(20, 10)]);
    await a.sync.syncNow();
    final counts = <int>[];
    final sub = b.h.db
        .customSelect(
          'SELECT COUNT(*) AS n FROM workouts',
          readsFrom: {b.h.db.workouts},
        )
        .watchSingle()
        .listen((r) => counts.add(r.read<int>('n')));
    await Future<void>.delayed(Duration.zero);
    await b.sync.syncNow();
    await Future<void>.delayed(const Duration(milliseconds: 10));
    await sub.cancel();
    expect(counts.last, 1);
  });

  test('a row this phone cannot apply yet is retried, not lost', () async {
    // A built-in exercise from a newer app version, unknown on B.
    const newBuiltIn = '00000000-0000-4000-8000-0000000000ff';
    await a.h.db.customStatement(
      'INSERT INTO exercises (id, name, is_per_hand, default_increment, '
      "is_custom, updated_at, dirty) VALUES (?, 'Future lift', 0, 2.5, 0, ?, 0)",
      [newBuiltIn, a.h.now.toIso8601String()],
    );
    await a.h.session([(20, 10)], exerciseId: newBuiltIn);
    await a.h.session([(20, 10)]);
    await a.sync.syncNow();

    await b.sync.syncNow();
    expect(await b.count('SELECT COUNT(*) FROM workouts'), 2);
    expect(await b.count('SELECT COUNT(*) FROM workout_exercises'), 1);
    expect(await b.count('SELECT COUNT(*) FROM sets'), 1);

    // B's app update ships the exercise: the held rows now apply.
    await b.h.db.customStatement(
      'INSERT INTO exercises (id, name, is_per_hand, default_increment, '
      "is_custom, updated_at, dirty) VALUES (?, 'Future lift', 0, 2.5, 0, ?, 0)",
      [newBuiltIn, b.h.now.toIso8601String()],
    );
    await b.sync.syncNow();
    expect(await b.count('SELECT COUNT(*) FROM workout_exercises'), 2);
    expect(await b.count('SELECT COUNT(*) FROM sets'), 2);
  });
}
