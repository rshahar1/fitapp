import 'package:fitapp/data/sync/sync_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';
import 'fake_sync_remote.dart';
import 'sync_test_utils.dart';

void main() {
  late FakeSyncRemote remote;
  late Device a;

  setUp(() async {
    remote = FakeSyncRemote();
    a = Device(remote);
    await a.init();
  });
  tearDown(() => a.close());

  group('push', () {
    test('first sync uploads the whole existing history (FR-015)', () async {
      await a.h.plan();
      await a.h.session([(20, 10), (20, 10), (20, 10)]);
      await a.h.session([(22.5, 10)]);
      await a.activities.create(typeId: 'running', startedAt: a.h.now);
      await a.templates.create(name: 'Push', exerciseIds: [inclineId]);

      expect(await a.sync.syncNow(), SyncOutcome.ok);

      expect(remote.live('workouts'), hasLength(2));
      expect(remote.live('workout_exercises'), hasLength(2));
      expect(remote.live('sets'), hasLength(4));
      expect(remote.live('activities'), hasLength(1));
      expect(remote.live('templates'), hasLength(1));
      expect(remote.live('template_exercises'), hasLength(1));
      expect(remote.live('exercise_state'), hasLength(1));
      expect(await a.dirtyCount(), 0);
      expect(await a.binding.lastSuccessAt(), a.h.now);
    });

    test('built-in library is not uploaded (FR-012)', () async {
      await a.sync.syncNow();
      expect(remote.live('custom_exercises'), isEmpty);
      expect(remote.live('exercise_overrides'), isEmpty);
    });

    test('custom and hidden built-in exercises are uploaded', () async {
      final custom = await a.h.exercises.createCustom(
        name: 'Zercher squat',
        perHand: false,
        increment: 2.5,
      );
      await a.h.exercises.delete(latId);
      await a.sync.syncNow();
      expect(remote.live('custom_exercises').single['id'], custom.id);
      final override = remote.live('exercise_overrides').single;
      expect(override['exercise_id'], latId);
      expect(override['archived_at'], isNotNull);
    });

    test('deletes are pushed as tombstones and cascade', () async {
      final (w, _) = await a.h.session([(20, 10)]);
      await a.sync.syncNow();
      await a.h.workouts.deleteWorkout(w);
      await a.sync.syncNow();
      expect(remote.live('workouts'), isEmpty);
      expect(remote.live('sets'), isEmpty);
      expect(remote.tables['sets'], hasLength(1));
      expect(await a.dirtyCount(), 0);
    });

    test(
      'an edit made while the push is in flight stays dirty (FR-018)',
      () async {
        final (w, _) = await a.h.session([(20, 10)]);
        remote.beforePush = () async {
          remote.beforePush = null;
          a.h.advance(const Duration(minutes: 1));
          await a.h.workouts.setWorkoutDay(w, a.h.now);
        };
        await a.sync.syncNow();
        expect(await a.count("SELECT dirty FROM workouts WHERE id = '$w'"), 1);
        await a.sync.syncNow();
        expect(await a.dirtyCount(), 0);
      },
    );

    test('transport failure changes nothing and is retried (FR-002)', () async {
      await a.h.session([(20, 10)]);
      final dirty = await a.dirtyCount();
      remote.failNext = true;
      expect(await a.sync.syncNow(), SyncOutcome.failed);
      expect(await a.dirtyCount(), dirty);
      expect(await a.binding.lastSuccessAt(), isNull);
      expect(await a.sync.syncNow(), SyncOutcome.ok);
      expect(await a.dirtyCount(), 0);
    });

    test('rejected rows stay pending, the rest is acknowledged', () async {
      final id = await a.activities.create(
        typeId: 'running',
        startedAt: a.h.now,
      );
      await a.h.session([(20, 10)]);
      remote.rejectKeys.add(('activities', id));
      expect(await a.sync.syncNow(), SyncOutcome.partial);
      expect(await a.dirtyCount(), 1);
      remote.rejectKeys.clear();
      expect(await a.sync.syncNow(), SyncOutcome.ok);
      expect(await a.dirtyCount(), 0);
    });

    test('pages larger batches', () async {
      for (var i = 0; i < 4; i++) {
        await a.h.session([(20, 10), (20, 10)]);
      }
      final small = Device(remote);
      await small.init();
      // 4 workouts + 4 workout exercises + 8 sets + plan rows in pages of 5.
      final service = SyncService(
        db: a.h.db,
        remote: remote,
        settings: a.h.settings,
        binding: a.binding,
        currentUserId: () => remote.userId,
        pushPageSize: 5,
      );
      await service.syncNow();
      expect(remote.pushCalls, greaterThan(3));
      expect(remote.live('sets'), hasLength(8));
      await service.dispose();
      await small.close();
    });

    test('settings are pushed and marked clean', () async {
      await a.h.settings.setDefaultRestSeconds(120);
      await a.sync.syncNow();
      final row = remote.live('user_settings').single;
      expect((row['data']! as Map)['default_rest_seconds'], 120);
      expect(await a.h.settings.syncedSettingsDirty(), isFalse);
    });
  });

  group('guards', () {
    test('signed out: nothing leaves the device (FR-003)', () async {
      a.signedInAs = null;
      await a.h.session([(20, 10)]);
      expect(await a.sync.syncNow(), SyncOutcome.skipped);
      expect(remote.pushCalls, 0);
    });

    test('bound to another account: skipped', () async {
      a.signedInAs = 'user-b';
      expect(await a.sync.syncNow(), SyncOutcome.skipped);
    });

    test('concurrent triggers share one run and re-run once', () async {
      await a.h.session([(20, 10)]);
      final first = a.sync.syncNow();
      final second = a.sync.syncNow();
      expect(identical(first, second), isTrue);
      expect(await first, SyncOutcome.ok);
      expect(await a.dirtyCount(), 0);
    });

    test('status stream reports syncing then the outcome', () async {
      final seen = <SyncStatus>[];
      final sub = a.sync.watchStatus().listen(seen.add);
      await a.sync.syncNow();
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();
      expect(seen.first.phase, SyncPhase.syncing);
      expect(seen.last.lastOutcome, SyncOutcome.ok);
    });
  });
}
