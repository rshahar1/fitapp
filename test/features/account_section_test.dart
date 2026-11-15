import 'package:drift/drift.dart'
    show DatabaseConnection, Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:fitapp/app/theme/app_theme.dart';
import 'package:fitapp/data/db/app_database.dart';
import 'package:fitapp/data/providers.dart';
import 'package:fitapp/data/repositories/auth_repository.dart';
import 'package:fitapp/data/repositories/settings_repository.dart';
import 'package:fitapp/data/sync/account_service.dart';
import 'package:fitapp/data/sync/sync_service.dart';
import 'package:fitapp/features/settings/account_section.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

class _FakeAccount implements AccountService {
  SignInOutcome outcome = SignInOutcome.backedUp;
  bool askMerge = false;
  bool? mergeAnswer;
  bool? replaceAnswer;
  String? replaceEmail;
  bool? keepAnswer;
  bool deleteThrows = false;
  final calls = <String>[];

  @override
  Future<SignInOutcome> signIn({
    required Future<bool> Function() confirmMerge,
    required Future<bool> Function(String? boundEmail) confirmReplace,
  }) async {
    calls.add('signIn');
    if (askMerge) mergeAnswer = await confirmMerge();
    return outcome;
  }

  @override
  Future<void> signOut() async => calls.add('signOut');

  @override
  Future<void> removeLocalData() async => calls.add('remove');

  @override
  Future<void> deleteAccount({
    required Future<bool> Function() keepLocalData,
  }) async {
    calls.add('delete');
    if (deleteThrows) throw Exception('server');
    keepAnswer = await keepLocalData();
  }
}

class _FakeSync implements SyncService {
  int syncs = 0;

  @override
  Future<SyncOutcome> syncNow() async {
    syncs++;
    return SyncOutcome.ok;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final now = DateTime(2026, 5, 1, 12);
  const account = AuthAccount(userId: 'u1', email: 'me@example.com');

  Future<void> pump(
    WidgetTester tester, {
    _FakeAccount? service,
    AuthAccount? user,
    String? bound,
    DateTime? last,
    SyncStatus status = const SyncStatus(),
    _FakeSync? sync,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accountServiceProvider.overrideWithValue(service),
          authAccountProvider.overrideWith((ref) => Stream.value(user)),
          boundEmailProvider.overrideWith((ref) => Stream.value(bound)),
          lastBackupProvider.overrideWith((ref) => Stream.value(last)),
          syncStatusProvider.overrideWith((ref) => Stream.value(status)),
          syncServiceProvider.overrideWithValue(sync),
          clockProvider.overrideWithValue(() => now),
        ],
        child: MaterialApp(
          theme: buildAppTheme(),
          home: const Scaffold(
            body: SingleChildScrollView(child: AccountSection()),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('not configured shows one line and no actions', (tester) async {
    await pump(tester);
    expect(find.text("Backup isn't available in this build"), findsOneWidget);
    expect(find.bySemanticsLabel('Sign in with Google'), findsNothing);
  });

  testWidgets('signed out and unbound offers sign-in', (tester) async {
    await pump(tester, service: _FakeAccount());
    expect(find.textContaining('survives a lost or new phone'), findsOneWidget);
    expect(find.bySemanticsLabel('Sign in with Google'), findsOneWidget);
    expect(find.text('Remove my data from this phone'), findsNothing);
  });

  testWidgets('signed out but bound shows email and remove', (tester) async {
    await pump(tester, service: _FakeAccount(), bound: 'old@example.com');
    expect(find.text('old@example.com'), findsOneWidget);
    expect(find.text('Sign in again to resume backup'), findsOneWidget);
    expect(find.bySemanticsLabel('Sign in with Google'), findsOneWidget);
    expect(find.text('Remove my data from this phone'), findsOneWidget);
  });

  testWidgets('signed in idle shows last backup and actions', (tester) async {
    await pump(
      tester,
      service: _FakeAccount(),
      user: account,
      last: now.subtract(const Duration(minutes: 5)),
    );
    expect(find.text('me@example.com'), findsOneWidget);
    expect(find.text('Last backed up 5 min ago'), findsOneWidget);
    for (final t in [
      'Back up now',
      'Sign out',
      'Remove my data from this phone',
      'Delete account',
    ]) {
      expect(find.text(t), findsOneWidget);
    }
  });

  testWidgets('never backed up', (tester) async {
    await pump(tester, service: _FakeAccount(), user: account);
    expect(find.text('Not backed up yet'), findsOneWidget);
  });

  test('formatBackupTime', () {
    String f(Duration d) => formatBackupTime(now.subtract(d), now);
    expect(f(const Duration(seconds: 20)), 'just now');
    expect(f(const Duration(hours: 2, minutes: 5)), '2 h ago');
    expect(f(const Duration(days: 3)), '28 Apr 2026');
  });

  testWidgets('syncing disables Back up now', (tester) async {
    final sync = _FakeSync();
    await pump(
      tester,
      service: _FakeAccount(),
      user: account,
      status: const SyncStatus(phase: SyncPhase.syncing),
      sync: sync,
    );
    expect(find.text('Backing up…'), findsOneWidget);
    await tester.tap(find.text('Back up now'));
    await tester.pump();
    expect(sync.syncs, 0);
  });

  testWidgets('Back up now calls syncNow', (tester) async {
    final sync = _FakeSync();
    await pump(tester, service: _FakeAccount(), user: account, sync: sync);
    await tester.tap(find.text('Back up now'));
    await tester.pump();
    expect(sync.syncs, 1);
  });

  testWidgets('restoring shows progress and no actions', (tester) async {
    await pump(
      tester,
      service: _FakeAccount(),
      user: account,
      status: const SyncStatus(phase: SyncPhase.restoring, restoredRows: 1240),
    );
    expect(find.text('Restoring… 1240 items'), findsOneWidget);
    expect(find.text('Sign out'), findsNothing);
    expect(find.text('Delete account'), findsNothing);
  });

  testWidgets('sign-in asks merge, then reports the outcome', (tester) async {
    final svc = _FakeAccount()
      ..askMerge = true
      ..outcome = SignInOutcome.merged;
    await pump(tester, service: svc);
    await tester.tap(find.bySemanticsLabel('Sign in with Google'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(LinearProgressIndicator), findsOneWidget); // busy
    expect(
      find.textContaining("workouts that aren't in your account yet"),
      findsOneWidget,
    );
    await tester.tap(find.text('Merge'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(svc.mergeAnswer, isTrue);
    expect(find.text('Histories combined and backed up.'), findsOneWidget);
  });

  for (final (outcome, message) in [
    (SignInOutcome.failed, "Couldn't sign in. Try again."),
    (SignInOutcome.restored, 'Your history was restored.'),
    (SignInOutcome.backedUp, 'Backup is on.'),
  ]) {
    testWidgets('outcome $outcome -> snackbar', (tester) async {
      await pump(tester, service: _FakeAccount()..outcome = outcome);
      await tester.tap(find.bySemanticsLabel('Sign in with Google'));
      await tester.pumpAndSettle();
      expect(find.text(message), findsOneWidget);
    });
  }

  testWidgets('cancelled and declined show nothing', (tester) async {
    await pump(
      tester,
      service: _FakeAccount()..outcome = SignInOutcome.cancelled,
    );
    await tester.tap(find.bySemanticsLabel('Sign in with Google'));
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('remove data asks first', (tester) async {
    final svc = _FakeAccount();
    await pump(tester, service: svc, bound: 'old@example.com');
    await tester.tap(find.text('Remove my data from this phone'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Backed-up data stays in your account.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(svc.calls, isEmpty);
    await tester.tap(find.text('Remove my data from this phone'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();
    expect(svc.calls, ['remove']);
  });

  testWidgets('delete account: two steps then keep choice', (tester) async {
    final svc = _FakeAccount();
    await pump(tester, service: svc, user: account);
    await tester.tap(find.text('Delete account'));
    await tester.pumpAndSettle();
    expect(find.textContaining("This can't be undone."), findsOneWidget);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(svc.calls, isEmpty);
    expect(find.text('Are you sure?'), findsOneWidget);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Keep your data on this phone?'), findsOneWidget);
    await tester.tap(find.text('Keep'));
    await tester.pumpAndSettle();
    expect(svc.calls, ['delete']);
    expect(svc.keepAnswer, isTrue);
  });

  testWidgets('delete account: choosing Remove', (tester) async {
    final svc = _FakeAccount();
    await pump(tester, service: svc, user: account);
    await tester.tap(find.text('Delete account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();
    expect(svc.keepAnswer, isFalse);
  });

  testWidgets('delete failure shows snackbar', (tester) async {
    final svc = _FakeAccount()..deleteThrows = true;
    await pump(tester, service: svc, user: account);
    await tester.tap(find.text('Delete account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(
      find.text("Couldn't delete the account. Try again."),
      findsOneWidget,
    );
    expect(svc.keepAnswer, isNull);
  });

  group('backup nudge', () {
    late AppDatabase db;
    setUp(() {
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
      db = AppDatabase(DatabaseConnection(NativeDatabase.memory()));
    });
    tearDown(() => db.close());

    Future<void> addFinished(int n) async {
      for (var i = 0; i < n; i++) {
        await db
            .into(db.workouts)
            .insert(
              WorkoutsCompanion.insert(
                id: 'w$i',
                updatedAt: now,
                startedAt: now.subtract(Duration(days: i + 1)),
                endedAt: Value(now.subtract(Duration(days: i + 1))),
              ),
            );
      }
    }

    Future<bool> run(
      WidgetTester tester, {
      required int finished,
      AccountService? service,
      AuthAccount? user,
    }) async {
      await tester.runAsync(() => addFinished(finished));
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          accountServiceProvider.overrideWithValue(service),
          authAccountProvider.overrideWith((ref) => Stream.value(user)),
          clockProvider.overrideWithValue(() => now),
        ],
      );
      addTearDown(container.dispose);
      container.listen(authAccountProvider, (_, _) {});
      await tester.runAsync(() => container.read(authAccountProvider.future));
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const Scaffold(body: Text('home')),
          ),
          GoRoute(
            path: '/settings',
            builder: (_, _) => const Scaffold(body: Text('settings page')),
          ),
        ],
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            theme: buildAppTheme(),
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(
        () => maybeShowBackupNudge(
          container,
          messenger: ScaffoldMessenger.of(tester.element(find.text('home'))),
          router: router,
        ),
      );
      await tester.pump();
      return find.text('Back up your history?').evaluate().isNotEmpty;
    }

    testWidgets('shown after the 3rd workout, once, and routes to settings', (
      tester,
    ) async {
      expect(await run(tester, finished: 3, service: _FakeAccount()), isTrue);
      expect(
        await tester.runAsync(
          () => SettingsRepository(db).readFlag(nudgeShownKey),
        ),
        'true',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();
      expect(find.text('settings page'), findsOneWidget);
    });

    testWidgets('not shown with fewer than 3 workouts', (tester) async {
      expect(await run(tester, finished: 2, service: _FakeAccount()), isFalse);
    });

    testWidgets('not shown when backup is not configured', (tester) async {
      expect(await run(tester, finished: 5), isFalse);
    });

    testWidgets('not shown when signed in', (tester) async {
      expect(
        await run(tester, finished: 5, service: _FakeAccount(), user: account),
        isFalse,
      );
    });
  });
}
