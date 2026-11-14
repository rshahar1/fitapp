/// Decisions the cloud sync makes when a server row meets the local database
/// (feature 013, specs/013-cloud-sync/data-model.md §6).
///
/// Pure Dart. No Flutter, database or I/O imports (constitution principle II).
library;

import 'package:meta/meta.dart';

/// What to do with one pulled row.
enum IncomingAction {
  /// No local row: insert it, marked clean.
  insert,

  /// Replace the local row with the server copy, marked clean.
  overwrite,

  /// Keep the local row: it is unsynced and newer, and will win on push.
  keepLocal,

  /// The server row is a tombstone: hard-delete the local row.
  deleteLocal,

  /// Nothing to do.
  ignore,
}

/// The local copy of a row, as far as conflict resolution cares.
@immutable
class LocalRowState {
  const new({required this.dirty, required this.updatedAt});

  /// Changed locally and not yet pushed.
  final bool dirty;

  /// Client time of the last local change.
  final DateTime updatedAt;
}

/// Resolves one pulled row against the local state.
///
/// Deletes always win (FR-017); a local change that is unsynced and newer is
/// never overwritten (FR-019); a row the user deleted locally stays deleted
/// until the queued delete is pushed.
IncomingAction resolveIncoming({
  required bool incomingDeleted,
  required DateTime incomingUpdatedAt,
  required LocalRowState? local,
  required bool locallyPendingDelete,
}) {
  if (incomingDeleted) {
    return local == null ? IncomingAction.ignore : IncomingAction.deleteLocal;
  }
  if (locallyPendingDelete) return IncomingAction.ignore;
  if (local == null) return IncomingAction.insert;
  if (local.dirty && local.updatedAt.isAfter(incomingUpdatedAt)) {
    return IncomingAction.keepLocal;
  }
  return IncomingAction.overwrite;
}

/// A free variant of [name] such as "Push (2)", given the [takenLower] names
/// (lower case). The base is shortened so the result fits [maxLength].
String suffixName(String name, Set<String> takenLower, {int maxLength = 40}) {
  for (var n = 2; ; n++) {
    final suffix = ' ($n)';
    final room = maxLength - suffix.length;
    final base = (name.length > room ? name.substring(0, room) : name)
        .trimRight();
    final candidate = '$base$suffix';
    if (!takenLower.contains(candidate.toLowerCase())) return candidate;
  }
}

/// Two different rows claim the same unique slot (e.g. the same set number of
/// a workout exercise). True when the incoming row should be kept. Newer wins;
/// ties go to the larger id so every device makes the same choice.
bool incomingWinsCollision({
  required DateTime incomingUpdatedAt,
  required String incomingId,
  required DateTime localUpdatedAt,
  required String localId,
}) {
  if (incomingUpdatedAt.isAfter(localUpdatedAt)) return true;
  if (incomingUpdatedAt.isBefore(localUpdatedAt)) return false;
  return incomingId.compareTo(localId) > 0;
}

/// Pulls re-read this window before the stored cursor, so transactions that
/// committed out of timestamp order are not missed (research R5).
const pullOverlap = Duration(minutes: 2);

/// Lower bound for the next pull of a table whose cursor is [cursor].
DateTime pullSince(DateTime? cursor) =>
    cursor == null ? DateTime.utc(1970) : cursor.subtract(pullOverlap);
