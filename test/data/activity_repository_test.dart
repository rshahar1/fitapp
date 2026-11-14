import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:fitapp/data/db/app_database.dart';
import 'package:fitapp/data/repositories/activity_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  late Harness h;
  late ActivityRepository activities;

  setUp(() {
    h = Harness();
    activities = ActivityRepository(h.db);
  });
  tearDown(() => h.close());

  test('create stores a dirty row with a UUID and clean note', () async {
    final id = await activities.create(
      typeId: 'running',
      startedAt: h.now,
      durationMinutes: 30,
      notes: '  easy 5k ',
    );
    expect(id, hasLength(36));
    final a = (await activities.activity(id))!;
    expect(a.typeId, 'running');
    expect(a.startedAt, h.now);
    expect(a.durationMinutes, 30);
    expect(a.notes, 'easy 5k');
    expect(a.dirty, isTrue);
  });

  test('create validates', () async {
    expect(
      () => activities.create(typeId: 'curling', startedAt: h.now),
      throwsArgumentError,
    );
    expect(
      () => activities.create(
        typeId: 'running',
        startedAt: h.now.add(const Duration(days: 2)),
      ),
      throwsArgumentError,
    );
    expect(
      () => activities.create(
        typeId: 'running',
        startedAt: h.now,
        durationMinutes: 0,
      ),
      throwsArgumentError,
    );
    expect(await activities.list(), isEmpty);
  });

  test('update changes every field; null clears optional ones', () async {
    final id = await activities.create(
      typeId: 'running',
      startedAt: h.now,
      durationMinutes: 30,
      notes: 'x',
    );
    final yesterday = h.now.subtract(const Duration(days: 1));
    h.advance(const Duration(minutes: 5));
    await activities.update(id, typeId: 'cycling', startedAt: yesterday);
    final a = (await activities.activity(id))!;
    expect(a.typeId, 'cycling');
    expect(a.startedAt, yesterday);
    expect(a.durationMinutes, isNull);
    expect(a.notes, isNull);
    expect(a.updatedAt, h.now);
  });

  test('editing an entry of an unknown (retired) type keeps it', () async {
    final id = await activities.create(typeId: 'running', startedAt: h.now);
    await (h.db.update(h.db.activities)..where((t) => t.id.equals(id))).write(
      const ActivitiesCompanion(typeId: Value('retired')),
    );
    await activities.update(
      id,
      typeId: 'retired',
      startedAt: h.now,
      durationMinutes: 10,
    );
    expect((await activities.activity(id))!.durationMinutes, 10);
    expect(
      () => activities.update(id, typeId: 'other-unknown', startedAt: h.now),
      throwsArgumentError,
    );
  });

  test('delete removes and queues for sync', () async {
    final id = await activities.create(typeId: 'running', startedAt: h.now);
    await activities.delete(id);
    expect(await activities.activity(id), isNull);
    final queued = await h.db.select(h.db.pendingDeletes).get();
    expect(queued.map((q) => (q.tableNameValue, q.rowId)), [
      ('activities', id),
    ]);
  });

  test('list is newest first', () async {
    final older = await activities.create(
      typeId: 'running',
      startedAt: h.now.subtract(const Duration(days: 3)),
    );
    final newer = await activities.create(typeId: 'cycling', startedAt: h.now);
    expect((await activities.list()).map((a) => a.id), [newer, older]);
    expect((await activities.watchActivities().first).map((a) => a.id), [
      newer,
      older,
    ]);
  });

  test('create and update store distance; update can clear it', () async {
    final id = await activities.create(
      typeId: 'running',
      startedAt: h.now,
      durationMinutes: 28,
      distanceMeters: 5200,
    );
    expect((await activities.activity(id))!.distanceMeters, 5200);
    await activities.update(
      id,
      typeId: 'cycling',
      startedAt: h.now,
      distanceMeters: 36750,
    );
    expect((await activities.activity(id))!.distanceMeters, 36750);
    await activities.update(id, typeId: 'cycling', startedAt: h.now);
    expect((await activities.activity(id))!.distanceMeters, isNull);
  });

  test('distance is rejected for types without distance', () async {
    expect(
      () => activities.create(
        typeId: 'snowboarding',
        startedAt: h.now,
        distanceMeters: 1000,
      ),
      throwsArgumentError,
    );
    expect(
      () => activities.create(
        typeId: 'running',
        startedAt: h.now,
        distanceMeters: 0,
      ),
      throwsArgumentError,
    );
    final id = await activities.create(typeId: 'running', startedAt: h.now);
    expect(
      () => activities.update(
        id,
        typeId: 'pilates',
        startedAt: h.now,
        distanceMeters: 1000,
      ),
      throwsArgumentError,
    );
    expect(await activities.list(), hasLength(1));
  });
}
