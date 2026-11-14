import 'dart:convert';

import 'package:fitapp/data/repositories/auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FakeGoogle implements GoogleTokenSource {
  GoogleTokens? tokens = (idToken: 'google-id-token', accessToken: 'g-access');
  Exception? error;
  int signOuts = 0;

  @override
  Future<GoogleTokens?> signIn() async {
    if (error != null) throw error!;
    return tokens;
  }

  @override
  Future<void> signOut() async => signOuts++;
}

String _jwt(String sub) {
  String part(Map<String, Object?> m) =>
      base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
  final exp = DateTime.now().add(const Duration(hours: 1));
  return '${part({'alg': 'HS256', 'typ': 'JWT'})}.'
      '${part({'sub': sub, 'exp': exp.millisecondsSinceEpoch ~/ 1000})}.sig';
}

void main() {
  late List<http.Request> requests;
  late http.Response Function(http.Request) respond;
  late SupabaseClient client;
  late FakeGoogle google;
  late AuthRepository auth;

  const userId = '00000000-0000-0000-0000-00000000000a';

  http.Response session() => http.Response(
    jsonEncode({
      'access_token': _jwt(userId),
      'token_type': 'bearer',
      'expires_in': 3600,
      'refresh_token': 'refresh',
      'user': {
        'id': userId,
        'aud': 'authenticated',
        'email': 'lifter@example.com',
        'app_metadata': {'provider': 'google'},
        'user_metadata': {'full_name': 'Lifter'},
        'created_at': '2026-11-14T10:00:00Z',
      },
    }),
    200,
  );

  setUp(() {
    requests = [];
    respond = (_) => session();
    client = SupabaseClient(
      'https://example.supabase.co',
      'anon-key',
      httpClient: MockClient((r) async {
        requests.add(r);
        final res = respond(r);
        return http.Response(
          res.body,
          res.statusCode,
          request: r,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    google = FakeGoogle();
    auth = AuthRepository(client: client, google: google);
  });
  tearDown(() => client.dispose());

  test('not configured: sign-in fails without touching anything', () async {
    final off = AuthRepository(client: null, google: google);
    expect(off.isConfigured, isFalse);
    expect(off.current, isNull);
    expect(await off.signInWithGoogle(), isA<SignInFailed>());
    expect(await off.watchAccount().toList(), [null]);
  });

  test('exchanges the Google ID token for a Supabase session', () async {
    final result = await auth.signInWithGoogle();

    final r = requests.single;
    expect(r.url.path, '/auth/v1/token');
    expect(r.url.queryParameters['grant_type'], 'id_token');
    final body = jsonDecode(r.body) as Map<String, Object?>;
    expect(body['provider'], 'google');
    expect(body['id_token'], 'google-id-token');
    expect(body['access_token'], 'g-access');

    const account = AuthAccount(
      userId: userId,
      email: 'lifter@example.com',
      name: 'Lifter',
    );
    expect(result, isA<SignedIn>());
    expect((result as SignedIn).account, account);
    expect(auth.current, account);
  });

  test('cancelled picker returns cancelled and calls nothing', () async {
    google.tokens = null;
    expect(await auth.signInWithGoogle(), isA<SignInCancelled>());
    expect(requests, isEmpty);
  });

  test('Google or Supabase errors become a failed result', () async {
    google.error = Exception('no network');
    expect(await auth.signInWithGoogle(), isA<SignInFailed>());

    google.error = null;
    respond = (_) => http.Response('{"error":"invalid_grant"}', 400);
    expect(await auth.signInWithGoogle(), isA<SignInFailed>());
    expect(auth.current, isNull);
  });

  test('sign out clears the session and the Google account', () async {
    await auth.signInWithGoogle();
    respond = (_) => http.Response('', 204);
    await auth.signOut();
    expect(auth.current, isNull);
    expect(google.signOuts, 1);
  });

  test('delete account calls the edge function, then signs out', () async {
    await auth.signInWithGoogle();
    respond = (_) => http.Response('', 204);
    await auth.deleteAccount();
    expect(
      requests.map((r) => r.url.path),
      contains('/functions/v1/delete-account'),
    );
    expect(auth.current, isNull);
  });

  test('delete account failure keeps the user signed in', () async {
    await auth.signInWithGoogle();
    respond = (_) => http.Response('{"error":"boom"}', 500);
    await expectLater(auth.deleteAccount(), throwsA(anything));
    expect(auth.current, isNotNull);
  });
}
