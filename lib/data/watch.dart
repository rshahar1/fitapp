import 'dart:async';

import 'package:drift/drift.dart';

/// Emits [load]'s result now and again after every write to any table.
///
/// Loads are serialized and coalesced: a burst of writes while a load is
/// running triggers exactly one more load.
Stream<T> watchQuery<T>(GeneratedDatabase db, Future<T> Function() load) {
  late StreamController<T> controller;
  StreamSubscription<Set<TableUpdate>>? sub;
  var running = false;
  var pending = false;

  Future<void> run() async {
    if (running) {
      pending = true;
      return;
    }
    running = true;
    try {
      do {
        pending = false;
        final value = await load();
        if (controller.isClosed) return;
        controller.add(value);
      } while (pending);
    } on Object catch (e, st) {
      if (!controller.isClosed) controller.addError(e, st);
    } finally {
      running = false;
    }
  }

  controller = StreamController<T>(
    onListen: () {
      sub = db.tableUpdates().listen((_) => unawaited(run()));
      unawaited(run());
    },
    onCancel: () async {
      await sub?.cancel();
    },
  );
  return controller.stream;
}
