/// Google sign-in for cloud backup (feature 013, research R11).
library;

import 'dart:async';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:meta/meta.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The signed-in account.
@immutable
class AuthAccount {
  const new({required this.userId, this.email, this.name});

  final String userId;
  final String? email;
  final String? name;

  @override
  bool operator ==(Object other) =>
      other is AuthAccount &&
      other.userId == userId &&
      other.email == email &&
      other.name == name;

  @override
  int get hashCode => Object.hash(userId, email, name);
}

sealed class SignInResult {
  const new();
}

final class SignInCancelled extends SignInResult {
  const new();
}

final class SignInFailed extends SignInResult {
  const new(this.message);

  final String message;
}

final class SignedIn extends SignInResult {
  const new(this.account);

  final AuthAccount account;
}

/// Tokens from the native Google account picker.
typedef GoogleTokens = ({String idToken, String? accessToken});

/// The native Google sign-in, behind a seam for tests.
abstract interface class GoogleTokenSource {
  /// Null when the user cancelled.
  Future<GoogleTokens?> signIn();

  Future<void> signOut();
}

/// [GoogleTokenSource] using `google_sign_in` 7.x.
class NativeGoogleTokenSource implements GoogleTokenSource {
  new({required this._serverClientId});

  final String _serverClientId;
  Future<void>? _init;

  static const _scopes = ['email', 'profile'];

  @override
  Future<GoogleTokens?> signIn() async {
    final google = GoogleSignIn.instance;
    await (_init ??= google.initialize(serverClientId: _serverClientId));
    try {
      final account = await google.authenticate(scopeHint: _scopes);
      final idToken = account.authentication.idToken;
      if (idToken == null) throw StateError('Google returned no ID token');
      final authz = await account.authorizationClient.authorizationForScopes(
        _scopes,
      );
      return (idToken: idToken, accessToken: authz?.accessToken);
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return null;
      rethrow;
    }
  }

  @override
  Future<void> signOut() async {
    if (_init == null) return;
    await GoogleSignIn.instance.signOut();
  }
}

class AuthRepository {
  /// `client` is null when the build has no backend configured
  /// (`Env.isSyncConfigured` false): every action is then a no-op.
  new({required this._client, required this._google});

  final SupabaseClient? _client;
  final GoogleTokenSource _google;

  bool get isConfigured => _client != null;

  AuthAccount? get current => _account(_client?.auth.currentUser);

  Stream<AuthAccount?> watchAccount() async* {
    final client = _client;
    yield current;
    if (client == null) return;
    yield* client.auth.onAuthStateChange
        .map((s) => _account(s.session?.user))
        .distinct();
  }

  Future<SignInResult> signInWithGoogle() async {
    final client = _client;
    if (client == null) return const SignInFailed('Backup is not configured');
    try {
      final tokens = await _google.signIn();
      if (tokens == null) return const SignInCancelled();
      final res = await client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: tokens.idToken,
        accessToken: tokens.accessToken,
      );
      final account = _account(res.user);
      if (account == null) return const SignInFailed('No user returned');
      return SignedIn(account);
    } on Object catch (e) {
      return SignInFailed(e.toString());
    }
  }

  Future<void> signOut() async {
    try {
      await _client?.auth.signOut();
    } finally {
      await _google.signOut();
    }
  }

  /// Deletes the account and all backed-up data on the server (FR-007),
  /// then signs out. Throws when the server call fails (the user stays
  /// signed in and sees an error).
  Future<void> deleteAccount() async {
    final client = _client;
    if (client == null) return;
    await client.functions.invoke('delete-account');
    await signOut();
  }

  static AuthAccount? _account(User? user) => user == null
      ? null
      : AuthAccount(
          userId: user.id,
          email: user.email,
          name: user.userMetadata?['full_name'] as String?,
        );
}
