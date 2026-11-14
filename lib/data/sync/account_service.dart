/// Account actions of the "Account & backup" section (US1, US2, US4, US5;
/// data-model.md §5). UI-free: questions to the user come in as callbacks.
library;

import 'package:fitapp/data/repositories/auth_repository.dart';
import 'package:fitapp/data/sync/device_binding.dart';
import 'package:fitapp/data/sync/sync_remote.dart';
import 'package:fitapp/data/sync/sync_service.dart';

enum SignInOutcome {
  /// The picker was closed.
  cancelled,

  /// Google, the backend or the network failed; still signed out.
  failed,

  /// Bound and synced (resume, first backup or nothing to do).
  backedUp,

  /// The account's backup was restored onto this phone.
  restored,

  /// Both histories were combined.
  merged,

  /// The user declined merge or replace; signed out again, phone unchanged.
  declined,
}

class AccountService {
  new({
    required this._auth,
    required this._binding,
    required this._sync,
    required this._remote,
  });

  final AuthRepository _auth;
  final DeviceBinding _binding;
  final SyncService _sync;
  final SyncRemote _remote;

  /// Signs in with Google and decides what happens to this phone's data.
  /// [confirmMerge] asks "combine this phone's history with your backup?";
  /// [confirmReplace] gets the email of the account the phone belongs to and
  /// asks before replacing its data.
  Future<SignInOutcome> signIn({
    required Future<bool> Function() confirmMerge,
    required Future<bool> Function(String? boundEmail) confirmReplace,
  }) async {
    final result = await _auth.signInWithGoogle();
    final account = switch (result) {
      SignInCancelled() => null,
      SignInFailed() => null,
      SignedIn(:final account) => account,
    };
    if (account == null) {
      return result is SignInCancelled
          ? SignInOutcome.cancelled
          : SignInOutcome.failed;
    }

    final SignInDecision decision;
    try {
      decision = await _binding.decide(
        account.userId,
        cloudHasData: _remote.hasCloudData,
      );
    } on SyncTransportException {
      // Cannot tell whether the account has data: never guess (FR-006).
      await _auth.signOut();
      return SignInOutcome.failed;
    }

    Future<void> bind() => _binding.bind(account.userId, email: account.email);

    switch (decision) {
      case SignInDecision.resume:
        await bind(); // refreshes the stored email
        await _sync.syncNow();
        return SignInOutcome.backedUp;
      case SignInDecision.nothingToDo:
      case SignInDecision.firstBackup:
        await bind();
        await _sync.syncNow();
        return SignInOutcome.backedUp;
      case SignInDecision.restore:
        await bind();
        await _sync.restore();
        return SignInOutcome.restored;
      case SignInDecision.askMerge:
        if (!await confirmMerge()) {
          await _auth.signOut();
          return SignInOutcome.declined;
        }
        await bind();
        await _sync.syncNow();
        return SignInOutcome.merged;
      case SignInDecision.askReplace:
        if (!await confirmReplace(await _binding.boundEmail())) {
          await _auth.signOut();
          return SignInOutcome.declined;
        }
        await _binding.wipeUserData();
        await bind();
        await _sync.restore();
        return SignInOutcome.restored;
    }
  }

  /// Stops backing up; data and binding stay on the phone (US5 s1).
  Future<void> signOut() => _auth.signOut();

  /// Erases this phone's data and returns to a first-run state (US5 s2).
  Future<void> removeLocalData() async {
    await _binding.wipeUserData();
    if (_auth.current != null) await _auth.signOut();
  }

  /// Deletes the account and its backup (US5 s3). Throws if the server call
  /// fails. Afterwards the phone is unbound; its data is kept unless
  /// [keepLocalData] says otherwise.
  Future<void> deleteAccount({
    required Future<bool> Function() keepLocalData,
  }) async {
    await _auth.deleteAccount();
    if (await keepLocalData()) {
      await _binding.unbind();
    } else {
      await _binding.wipeUserData();
    }
  }
}
