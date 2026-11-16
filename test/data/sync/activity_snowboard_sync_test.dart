// Snowboarding metrics of tracked activities sync both ways (feature 017).
import 'package:fitapp/data/sync/sync_service.dart';
import 'package:flutter_test/flutter_test.dart';

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

  test('snowboarding fields are pushed and pulled', () async {
    final id = await a.activities.create(
      typeId: 'snowboarding',
      startedAt: a.h.now,
      durationMinutes: 240,
    );
    await a.h.db.customStatement(
      'UPDATE activities SET vertical_drop_meters = 3200, run_count = 9, '
      'max_speed_mps = 17.5, lift_seconds = 5400, rest_seconds = 1800, '
      "segments = '[{\"kind\":\"run\"}]' WHERE id = ?",
      [id],
    );

    expect(await a.sync.syncNow(), SyncOutcome.ok);
    final row = remote.live('activities').single;
    expect(row['vertical_drop_meters'], 3200);
    expect(row['run_count'], 9);
    expect(row['max_speed_mps'], 17.5);
    expect(row['lift_seconds'], 5400);
    expect(row['rest_seconds'], 1800);
    expect(row['segments'], '[{"kind":"run"}]');

    expect(await b.sync.syncNow(), SyncOutcome.ok);
    final local = await b.h.db.select(b.h.db.activities).getSingle();
    expect(local.verticalDropMeters, 3200);
    expect(local.runCount, 9);
    expect(local.maxSpeedMps, 17.5);
    expect(local.maxSpeedMps, isA<double>());
    expect(local.liftSeconds, 5400);
    expect(local.restSeconds, 1800);
    expect(local.segments, '[{"kind":"run"}]');
    expect(await b.snapshot(), await a.snapshot());
  });
}
