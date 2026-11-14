import 'package:fitapp/domain/sync_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final t0 = DateTime.utc(2026, 11, 14, 10);
  final t1 = DateTime.utc(2026, 11, 14, 11);

  group('resolveIncoming', () {
    IncomingAction resolve({
      bool deleted = false,
      LocalRowState? local,
      DateTime? incomingAt,
      bool pendingDelete = false,
    }) => resolveIncoming(
      incomingDeleted: deleted,
      incomingUpdatedAt: incomingAt ?? t1,
      local: local,
      locallyPendingDelete: pendingDelete,
    );

    test('tombstone deletes an existing local row', () {
      expect(
        resolve(
          deleted: true,
          local: LocalRowState(dirty: false, updatedAt: t0),
        ),
        IncomingAction.deleteLocal,
      );
    });

    test('tombstone wins even over a newer dirty local edit', () {
      expect(
        resolve(
          deleted: true,
          incomingAt: t0,
          local: LocalRowState(dirty: true, updatedAt: t1),
        ),
        IncomingAction.deleteLocal,
      );
    });

    test('tombstone for a missing row is ignored', () {
      expect(resolve(deleted: true), IncomingAction.ignore);
    });

    test('live row for a missing local row is inserted', () {
      expect(resolve(), IncomingAction.insert);
    });

    test('live row for a row queued for local delete is ignored', () {
      expect(resolve(pendingDelete: true), IncomingAction.ignore);
    });

    test('clean local row is overwritten even if newer', () {
      expect(
        resolve(
          incomingAt: t0,
          local: LocalRowState(dirty: false, updatedAt: t1),
        ),
        IncomingAction.overwrite,
      );
    });

    test('dirty local row that is older or equal is overwritten', () {
      expect(
        resolve(local: LocalRowState(dirty: true, updatedAt: t0)),
        IncomingAction.overwrite,
      );
      expect(
        resolve(local: LocalRowState(dirty: true, updatedAt: t1)),
        IncomingAction.overwrite,
      );
    });

    test('dirty local row that is newer is kept', () {
      expect(
        resolve(
          incomingAt: t0,
          local: LocalRowState(dirty: true, updatedAt: t1),
        ),
        IncomingAction.keepLocal,
      );
    });
  });

  group('suffixName', () {
    test('appends (2) when free', () {
      expect(suffixName('Push', {'push'}), 'Push (2)');
    });

    test('skips taken suffixes, case-insensitively', () {
      expect(
        suffixName('Push', {'push', 'PUSH (2)'.toLowerCase()}),
        'Push (3)',
      );
    });

    test('trims the base so the result fits maxLength', () {
      final long = 'A' * 40;
      final result = suffixName(long, {long.toLowerCase()});
      expect(result.length, 40);
      expect(result, endsWith(' (2)'));
    });

    test('trims trailing spaces left by cutting the base', () {
      final name = '${'A' * 35} BBBB';
      expect(suffixName(name, {name.toLowerCase()}), '${'A' * 35} (2)');
    });
  });

  group('incomingWinsCollision', () {
    test('newer row wins', () {
      expect(
        incomingWinsCollision(
          incomingUpdatedAt: t1,
          incomingId: 'a',
          localUpdatedAt: t0,
          localId: 'b',
        ),
        isTrue,
      );
      expect(
        incomingWinsCollision(
          incomingUpdatedAt: t0,
          incomingId: 'b',
          localUpdatedAt: t1,
          localId: 'a',
        ),
        isFalse,
      );
    });

    test('ties break on the larger id so every device picks the same row', () {
      expect(
        incomingWinsCollision(
          incomingUpdatedAt: t0,
          incomingId: 'b',
          localUpdatedAt: t0,
          localId: 'a',
        ),
        isTrue,
      );
      expect(
        incomingWinsCollision(
          incomingUpdatedAt: t0,
          incomingId: 'a',
          localUpdatedAt: t0,
          localId: 'b',
        ),
        isFalse,
      );
    });
  });

  group('pullSince', () {
    test('steps back by the overlap window', () {
      expect(pullSince(t1), t1.subtract(pullOverlap));
    });

    test('never-synced tables start at the epoch', () {
      expect(pullSince(null), DateTime.utc(1970));
    });
  });
}
