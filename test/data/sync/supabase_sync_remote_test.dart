import 'dart:convert';

import 'package:fitapp/data/sync/supabase_sync_remote.dart';
import 'package:fitapp/data/sync/sync_remote.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  late List<http.Request> requests;
  late http.Response Function(http.Request) respond;
  late SupabaseClient client;
  late SupabaseSyncRemote remote;

  setUp(() {
    requests = [];
    respond = (_) => http.Response('[]', 200);
    client = SupabaseClient(
      'https://example.supabase.co',
      'anon-key',
      httpClient: MockClient((r) async {
        requests.add(r);
        final res = respond(r);
        // postgrest reads response.request, which MockClient leaves unset.
        return http.Response(
          res.body,
          res.statusCode,
          request: r,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    remote = SupabaseSyncRemote(client);
  });
  tearDown(() => client.dispose());

  test('push calls sync_push with the payload and parses the result', () async {
    respond = (_) => http.Response(
      jsonEncode({
        'applied': 2,
        'rejected': [
          {'table': 'sets', 'id': 's1', 'error': '23503: fk'},
          {'table': 'user_settings', 'id': null, 'error': 'x'},
        ],
      }),
      200,
    );
    final result = await remote.push(
      const PushBatch(
        deletes: [('workouts', 'w1')],
        upserts: {
          'sets': [
            {'id': 's1', 'set_no': 1},
          ],
        },
      ),
    );
    final r = requests.single;
    expect(r.method, 'POST');
    expect(r.url.path, '/rest/v1/rpc/sync_push');
    final body = jsonDecode(r.body) as Map<String, Object?>;
    expect(body['payload'], {
      'deletes': [
        {'table': 'workouts', 'id': 'w1'},
      ],
      'upserts': {
        'sets': [
          {'id': 's1', 'set_no': 1},
        ],
      },
    });
    expect(result.applied, 2);
    expect(result.rejected, {('sets', 's1'), ('user_settings', '')});
  });

  test(
    'first pull page filters by cursor and orders by cursor and key',
    () async {
      respond = (_) => http.Response(
        jsonEncode([
          {'id': 'w1', 'server_updated_at': '2026-11-14T10:00:00.123456+00:00'},
        ]),
        200,
      );
      final rows = await remote.pullPage(
        'workouts',
        since: DateTime.utc(2026, 11, 14, 9, 58),
        limit: 500,
      );
      final q = requests.single.url.queryParameters;
      expect(requests.single.url.path, '/rest/v1/workouts');
      expect(q['server_updated_at'], 'gt.2026-11-14T09:58:00.000Z');
      expect(q['order'], 'server_updated_at.asc.nullslast,id.asc.nullslast');
      expect(q['limit'], '500');
      expect(rows.single['id'], 'w1');
    },
  );

  test('next pages use a keyset on (cursor, key)', () async {
    await remote.pullPage(
      'exercise_state',
      since: DateTime.utc(2026, 11, 14, 10),
      afterKey: 'e1',
    );
    final q = requests.single.url.queryParameters;
    expect(
      q['or'],
      '(server_updated_at.gt.2026-11-14T10:00:00.000Z,'
      'and(server_updated_at.eq.2026-11-14T10:00:00.000Z,exercise_id.gt.e1))',
    );
    expect(
      q['order'],
      'server_updated_at.asc.nullslast,exercise_id.asc.nullslast',
    );
  });

  test('hasCloudData probes live rows only', () async {
    respond = (r) => http.Response(
      r.url.path.endsWith('activities') ? '[{"id":"a1"}]' : '[]',
      200,
    );
    expect(await remote.hasCloudData(), isTrue);
    expect(requests.first.url.queryParameters['deleted_at'], 'is.null');
    expect(requests.map((r) => r.url.path.split('/').last), [
      'workouts',
      'activities',
    ]);
  });

  test('backend errors become transport errors', () async {
    respond = (_) => http.Response('{"message":"JWT expired"}', 401);
    expect(
      () => remote.pullPage('workouts', since: DateTime.utc(2026)),
      throwsA(isA<SyncTransportException>()),
    );
  });
}
