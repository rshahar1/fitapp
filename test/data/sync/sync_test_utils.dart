import 'package:fitapp/data/repositories/activity_repository.dart';
import 'package:fitapp/data/repositories/template_repository.dart';
import 'package:fitapp/data/sync/device_binding.dart';
import 'package:fitapp/data/sync/sync_service.dart';
import 'package:fitapp/data/sync/sync_table.dart';

import '../helpers.dart';
import 'fake_sync_remote.dart';

/// One phone: an in-memory database bound to the fake account.
class Device {
  new(this.remote, {bool bound = true, int pullPageSize = 1000}) {
    binding = DeviceBinding(h.db);
    sync = SyncService(
      db: h.db,
      remote: remote,
      settings: h.settings,
      binding: binding,
      currentUserId: () => signedInAs,
      pullPageSize: pullPageSize,
    );
    _bound = bound;
  }

  final FakeSyncRemote remote;
  final h = Harness();
  late final TemplateRepository templates = TemplateRepository(h.db);
  late final ActivityRepository activities = ActivityRepository(h.db);
  late final DeviceBinding binding;
  late final SyncService sync;
  late final bool _bound;
  String? signedInAs;

  Future<void> init() async {
    if (_bound) {
      signedInAs = remote.userId;
      await binding.bind(remote.userId);
    }
  }

  Future<void> close() async {
    await sync.dispose();
    await h.close();
  }

  /// Synced content (without bookkeeping), for comparing devices.
  Future<Map<String, List<Map<String, Object?>>>> snapshot() async => {
    for (final t in syncTables)
      t.server: [
        for (final r
            in await h.db
                .customSelect(
                  'SELECT ${t.columns.map((c) => c.local).join(', ')}, updated_at '
                  'FROM ${t.local} WHERE 1 = 1${t.where} '
                  'ORDER BY ${t.localKey}',
                )
                .get())
          {
            for (final c in t.columns) c.server: c.toJson(r.data[c.local]),
            'updated_at': parseUtc(r.data['updated_at'] as Object),
          },
      ],
  };

  Future<int> count(String sql) async =>
      (await h.db.customSelect(sql).getSingle()).data.values.first! as int;

  Future<int> dirtyCount() async {
    var n = 0;
    for (final t in syncTables) {
      n += await count(
        'SELECT COUNT(*) FROM ${t.local} WHERE dirty = 1${t.where}',
      );
    }
    return n + await count('SELECT COUNT(*) FROM pending_deletes');
  }
}
