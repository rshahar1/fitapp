// Sign-in decisions and account actions (US1, US2, US4, US5; FR-006, FR-007).
import 'package:fitapp/data/repositories/auth_repository.dart';
import 'package:fitapp/data/sync/account_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';
import 'fake_sync_remote.dart';
import 'sync_test_utils.dart';

class FakeAuth implements AuthRepository {
  SignInResult next = const SignedIn(
    AuthAccount(userId: 'user-a', email: 'a@example.com'),
  );
  AuthAccount? signedIn;
  int signOuts = 0;
  bool failDelete = false;
  void Function(String userId)? onSignIn;

  @override
  bool get isConfigured => true;

  @override
  AuthAccount? get current => signedIn;

  @override
  Stream<AuthAccount?> watchAccount() => Stream.value(signedIn);

  @override
  Future<SignInResult> signInWithGoogle() async {
    if (next case SignedIn(:final account)) {
      signedIn = account;
      onSignIn?.call(account.userId);
    }
    return next;
  }

  @override
  Future<void> signOut() async {
    signOuts++;
    signedIn = null;
    onSignIn?.call('');
  }

  @override
  Future<void> deleteAccount() async {
    if (failDelete) throw Exception('server error');
    await signOut();
  }
}

void main() {
  late FakeSyncRemote remote;
  late Device phone;
  late FakeAuth auth;
  late AccountService account;
  var mergeAsked = 0;
  String? replaceAskedFor;
  var answer = true;
  MergeChoice? mergeChoice;

  Future<SignInOutcome> signIn() => account.signIn(
    chooseMerge: () async {
      mergeAsked++;
      return mergeChoice ?? (answer ? MergeChoice.merge : MergeChoice.cancel);
    },
    confirmReplace: (email) async {
      replaceAskedFor = email;
      return answer;
    },
  );

  setUp(() async {
    remote = FakeSyncRemote();
    phone = Device(remote, bound: false);
    await phone.init();
    auth = FakeAuth()
      ..onSignIn = (id) => phone.signedInAs = id.isEmpty ? null : id;
    account = AccountService(
      auth: auth,
      binding: phone.binding,
      sync: phone.sync,
      remote: remote,
    );
    mergeAsked = 0;
    replaceAskedFor = null;
    answer = true;
    mergeChoice = null;
  });
  tearDown(() => phone.close());

  Future<void> seedCloud() async {
    final other = Device(remote);
    await other.init();
    await other.h.session([(20, 10)]);
    await other.activities.create(typeId: 'running', startedAt: other.h.now);
    await other.sync.syncNow();
    await other.close();
  }

  test('cancelled or failed sign-in changes nothing', () async {
    auth.next = const SignInCancelled();
    expect(await signIn(), SignInOutcome.cancelled);
    auth.next = const SignInFailed('x');
    expect(await signIn(), SignInOutcome.failed);
    expect(await phone.binding.boundUserId(), isNull);
  });

  test('first backup: history here, empty account', () async {
    await phone.h.session([(20, 10)]);
    expect(await signIn(), SignInOutcome.backedUp);
    expect(await phone.binding.boundUserId(), 'user-a');
    expect(await phone.binding.boundEmail(), 'a@example.com');
    expect(remote.live('workouts'), hasLength(1));
    expect(mergeAsked, 0);
  });

  test('restore: empty phone, account with backup (US2)', () async {
    await seedCloud();
    expect(await signIn(), SignInOutcome.restored);
    expect(await phone.count('SELECT COUNT(*) FROM workouts'), 1);
    expect(await phone.count('SELECT COUNT(*) FROM activities'), 1);
  });

  test('merge when both sides have data, after asking (US4 s1)', () async {
    await seedCloud();
    await phone.h.session([(25, 8)]);
    expect(await signIn(), SignInOutcome.merged);
    expect(mergeAsked, 1);
    expect(await phone.count('SELECT COUNT(*) FROM workouts'), 2);
    expect(remote.live('workouts'), hasLength(2));
  });

  test('declining merge signs out and leaves the phone untouched', () async {
    await seedCloud();
    await phone.h.session([(25, 8)]);
    answer = false;
    expect(await signIn(), SignInOutcome.declined);
    expect(auth.signOuts, 1);
    expect(await phone.binding.boundUserId(), isNull);
    expect(await phone.count('SELECT COUNT(*) FROM workouts'), 1);
    expect(remote.live('workouts'), hasLength(1));
  });

  test(
    'use my backup instead: phone data replaced, nothing uploaded',
    () async {
      await seedCloud();
      // A stale pre-sign-in copy, e.g. restored by Android's own app backup.
      final stale = await phone.activities.create(
        typeId: 'snowboarding',
        startedAt: phone.h.now,
      );
      await phone.templates.create(name: 'Old', exerciseIds: [inclineId]);
      mergeChoice = MergeChoice.useBackup;

      expect(await signIn(), SignInOutcome.restored);

      expect(mergeAsked, 1);
      expect(await phone.binding.boundUserId(), 'user-a');
      expect(await phone.count('SELECT COUNT(*) FROM templates'), 0);
      expect(await phone.count('SELECT COUNT(*) FROM workouts'), 1);
      expect(await phone.count('SELECT COUNT(*) FROM activities'), 1);
      expect(
        await phone.count(
          "SELECT COUNT(*) FROM activities WHERE id = '$stale'",
        ),
        0,
      );
      expect(remote.live('activities'), hasLength(1));
      expect(remote.live('templates'), isEmpty, reason: 'nothing uploaded');
      expect(await phone.dirtyCount(), 0);
    },
  );

  test('another account: asks, then replaces the data (US4 s2)', () async {
    await phone.binding.bind('user-x', email: 'x@example.com');
    await phone.h.session([(25, 8)]);
    await seedCloud();
    expect(await signIn(), SignInOutcome.restored);
    expect(replaceAskedFor, 'x@example.com');
    expect(await phone.binding.boundUserId(), 'user-a');
    // Only the account's workout remains; X's local data was wiped.
    expect(await phone.count('SELECT COUNT(*) FROM workouts'), 1);
    expect(remote.live('workouts'), hasLength(1));
  });

  test('another account, cancelled: phone unchanged and signed out', () async {
    await phone.binding.bind('user-x', email: 'x@example.com');
    await phone.h.session([(25, 8)]);
    answer = false;
    expect(await signIn(), SignInOutcome.declined);
    expect(await phone.binding.boundUserId(), 'user-x');
    expect(await phone.count('SELECT COUNT(*) FROM workouts'), 1);
    expect(auth.current, isNull);
  });

  test('offline during the decision: fails and signs out', () async {
    await phone.h.session([(25, 8)]);
    remote.failNext = true;
    expect(await signIn(), SignInOutcome.failed);
    expect(auth.signOuts, 1);
    expect(await phone.binding.boundUserId(), isNull);
  });

  test('sign out keeps data and binding (US5 s1)', () async {
    await phone.h.session([(20, 10)]);
    await signIn();
    await account.signOut();
    expect(await phone.binding.boundUserId(), 'user-a');
    expect(await phone.count('SELECT COUNT(*) FROM workouts'), 1);
  });

  test('remove data returns to first run, built-ins kept (US5 s2)', () async {
    await phone.h.plan();
    await phone.h.session([(20, 10)]);
    await phone.h.exercises.delete(latId);
    await phone.h.settings.setDefaultRestSeconds(120);
    await signIn();
    await account.removeLocalData();
    expect(await phone.binding.hasLocalHistory(), isFalse);
    expect(await phone.binding.boundUserId(), isNull);
    expect(await phone.count('SELECT COUNT(*) FROM exercises'), greaterThan(0));
    expect((await phone.h.exercises.exercise(latId))!.deletedAt, isNull);
    expect(await phone.h.settings.defaultRest(), 60);
    expect(auth.current, isNull);
    expect(remote.live('workouts'), hasLength(1), reason: 'backup untouched');
  });

  test('delete account: keep or remove local data (US5 s3)', () async {
    await phone.h.session([(20, 10)]);
    await signIn();
    await account.deleteAccount(keepLocalData: () async => true);
    expect(await phone.binding.boundUserId(), isNull);
    expect(await phone.count('SELECT COUNT(*) FROM workouts'), 1);

    await signIn();
    await account.deleteAccount(keepLocalData: () async => false);
    expect(await phone.count('SELECT COUNT(*) FROM workouts'), 0);
  });

  test('delete account failure keeps everything', () async {
    await phone.h.session([(20, 10)]);
    await signIn();
    auth.failDelete = true;
    await expectLater(
      account.deleteAccount(keepLocalData: () async => false),
      throwsException,
    );
    expect(await phone.binding.boundUserId(), 'user-a');
    expect(await phone.count('SELECT COUNT(*) FROM workouts'), 1);
  });
}
