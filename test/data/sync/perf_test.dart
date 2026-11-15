// Restore of ~2 years of training stays fast (SC-002, task T043).
import 'package:fitapp/data/sync/sync_remote.dart';
import 'package:fitapp/data/sync/sync_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';

import 'fake_sync_remote.dart';
import 'sync_test_utils.dart';

const _uuid = Uuid();

String _exerciseId(int n) =>
    '00000000-0000-4000-8000-${n.toRadixString(16).padLeft(12, '0')}';

Future<void> _pushChunked(
  FakeSyncRemote remote,
  String table,
  List<RemoteRow> rows,
) async {
  for (var i = 0; i < rows.length; i += 1000) {
    final end = i + 1000 > rows.length ? rows.length : i + 1000;
    await remote.push(PushBatch(upserts: {table: rows.sublist(i, end)}));
  }
}

void main() {
  test('restoring ~2 years of training is fast (SC-002)', () async {
    final remote = FakeSyncRemote();
    final base = DateTime.utc(2026, 11, 2);
    String at(DateTime d) => d.toUtc().toIso8601String();
    final stamp = at(base);

    final workouts = <RemoteRow>[];
    final workoutExercises = <RemoteRow>[];
    final sets = <RemoteRow>[];
    for (var w = 0; w < 300; w++) {
      final start = base.subtract(Duration(hours: w * 584 + 1)); // ~2 years
      final wid = _uuid.v4();
      workouts.add({
        'id': wid,
        'name': 'Workout $w',
        'started_at': at(start),
        'ended_at': at(start.add(const Duration(hours: 1))),
        'notes': null,
        'updated_at': stamp,
      });
      for (var e = 0; e < 5; e++) {
        final weid = _uuid.v4();
        workoutExercises.add({
          'id': weid,
          'workout_id': wid,
          'exercise_id': _exerciseId(1 + (w + e) % 16),
          'position': e,
          'notes': null,
          'template_exercise_id': null,
          'plan_base_weight': 20.0,
          'plan_target_reps': 10,
          'plan_target_sets': 10,
          'plan_increment': 2.5,
          'result_base_weight': 20.0,
          'updated_at': stamp,
        });
        for (var s = 1; s <= 10; s++) {
          sets.add({
            'id': _uuid.v4(),
            'workout_exercise_id': weid,
            'set_no': s,
            'weight': 20.0,
            'reps': 10,
            'is_overload': false,
            'completed_at': at(start.add(Duration(minutes: s))),
            'updated_at': stamp,
          });
        }
      }
    }
    final route = List.filled(2048, 'a').join();
    final splits = '[${List.generate(10, (i) => 300 + i).join(',')}]';
    final activities = [
      for (var i = 0; i < 100; i++)
        {
          'id': _uuid.v4(),
          'type_id': 'running',
          'started_at': at(base.subtract(Duration(days: i * 7 + 1))),
          'duration_minutes': 30,
          'distance_meters': 5000,
          'notes': null,
          'source': 'gps',
          'moving_seconds': 1700,
          'elevation_gain_meters': 20,
          'route': route,
          'splits': splits,
          'updated_at': stamp,
        },
    ];
    final exerciseState = [
      for (var i = 1; i <= 16; i++)
        {
          'exercise_id': _exerciseId(i),
          'base_weight': 20.0,
          'target_reps': 10,
          'target_sets': 3,
          'increment': 2.5,
          'rest_seconds': 90,
          'updated_at': stamp,
        },
    ];
    final templates = <RemoteRow>[];
    final templateExercises = <RemoteRow>[];
    for (var t = 0; t < 5; t++) {
      final tid = _uuid.v4();
      templates.add({
        'id': tid,
        'name': 'Template $t',
        'created_at': stamp,
        'last_used_at': null,
        'updated_at': stamp,
      });
      for (var e = 0; e < 4; e++) {
        templateExercises.add({
          'id': _uuid.v4(),
          'template_id': tid,
          'exercise_id': _exerciseId(1 + (t * 4 + e) % 16),
          'position': e,
          'base_weight': 20.0,
          'target_reps': 10,
          'target_sets': 3,
          'increment': 2.5,
          'rest_seconds': 90,
          'updated_at': stamp,
        });
      }
    }

    await _pushChunked(remote, 'exercise_state', exerciseState);
    await _pushChunked(remote, 'templates', templates);
    await _pushChunked(remote, 'template_exercises', templateExercises);
    await _pushChunked(remote, 'workouts', workouts);
    await _pushChunked(remote, 'workout_exercises', workoutExercises);
    await _pushChunked(remote, 'sets', sets);
    await _pushChunked(remote, 'activities', activities);
    expect(remote.live('sets'), hasLength(15000));

    final device = Device(remote);
    addTearDown(device.close);
    await device.init();

    final watch = Stopwatch()..start();
    final outcome = await device.sync.restore();
    watch.stop();
    // Timing output is the point of this test.
    // ignore: avoid_print
    print('restore of 15000 sets took ${watch.elapsedMilliseconds} ms');

    expect(outcome, SyncOutcome.ok);
    expect(await device.count('SELECT COUNT(*) FROM workouts'), 300);
    expect(await device.count('SELECT COUNT(*) FROM workout_exercises'), 1500);
    expect(await device.count('SELECT COUNT(*) FROM sets'), 15000);
    expect(await device.count('SELECT COUNT(*) FROM activities'), 100);
    expect(watch.elapsed, lessThan(const Duration(seconds: 20)));

    final pushes = remote.pushCalls;
    expect(await device.sync.syncNow(), SyncOutcome.ok);
    expect(remote.pushCalls, pushes);
    expect(await device.dirtyCount(), 0);
  }, timeout: const Timeout(Duration(seconds: 90)));
}
