import 'package:fitapp/app/router.dart';
import 'package:fitapp/app/theme/tokens.dart';
import 'package:fitapp/data/providers.dart';
import 'package:fitapp/data/sync/account_service.dart';
import 'package:fitapp/data/sync/sync_service.dart';
import 'package:fitapp/widgets/guard.dart';
import 'package:fitapp/widgets/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

/// Settings key set once the backup nudge was shown.
const nudgeShownKey = 'sync.nudge_shown';

/// Finished workouts after which the backup nudge appears.
const nudgeAfterWorkouts = 3;

/// "just now", "5 min ago", "2 h ago", else a date.
String formatBackupTime(DateTime at, DateTime now) {
  final d = now.difference(at);
  if (d.inMinutes < 1) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes} min ago';
  if (d.inHours < 24) return '${d.inHours} h ago';
  return DateFormat('d MMM y').format(at.toLocal());
}

/// Settings group for cloud backup: sign-in, status and account actions.
class AccountSection extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<AccountSection> createState() => _AccountSectionState();
}

class _AccountSectionState extends ConsumerState<AccountSection> {
  bool _signingIn = false;

  void _say(String message) =>
      ScaffoldMessenger.maybeOf(context)
          ?.showSnackBar(SnackBar(content: Text(message)));

  Future<void> _signIn(AccountService service) async {
    setState(() => _signingIn = true);
    try {
      final outcome = await service.signIn(
        chooseMerge: () => chooseMergeDialog(context),
        confirmReplace: (email) => confirmReplaceDialog(context, email),
      );
      if (!mounted) return;
      switch (outcome) {
        case SignInOutcome.failed:
          _say("Couldn't sign in. Try again.");
        case SignInOutcome.restored:
          _say('Your history was restored.');
        case SignInOutcome.merged:
          _say('Histories combined and backed up.');
        case SignInOutcome.backedUp:
          _say('Backup is on.');
        case SignInOutcome.cancelled:
        case SignInOutcome.declined:
          break;
      }
    } on Object {
      if (mounted) _say("Couldn't sign in. Try again.");
    } finally {
      if (mounted) setState(() => _signingIn = false);
    }
  }

  Future<void> _removeData(AccountService service) async {
    final ok = await confirmDestructive(
      context,
      title: 'Remove data from this phone?',
      message:
          'Remove all your workouts, templates and activities from this '
          'phone? Backed-up data stays in your account.',
      confirmLabel: 'Remove',
    );
    if (!ok || !mounted) return;
    await guard(context, service.removeLocalData);
  }

  Future<void> _deleteAccount(AccountService service) async {
    final first = await confirmDestructive(
      context,
      title: 'Delete account?',
      message:
          "Delete your account and all backed-up data? This can't be "
          'undone.',
      confirmLabel: 'Delete',
    );
    if (!first || !mounted) return;
    final second = await confirmDestructive(
      context,
      title: 'Are you sure?',
      message: 'Your backup will be deleted for good.',
      confirmLabel: 'Delete',
    );
    if (!second || !mounted) return;
    await guard(
      context,
      () => service.deleteAccount(keepLocalData: () => keepDataDialog(context)),
      message: "Couldn't delete the account. Try again.",
    );
  }

  Widget _note(String text) {
    final style = Theme.of(context).textTheme.bodyMedium
        ?.copyWith(color: AppColors.textSecondary);
    return Padding(
      padding: const EdgeInsets.all(Space.m),
      child: Text(text, style: style),
    );
  }

  Widget _signInButton(AccountService service) => Padding(
    padding: const EdgeInsets.all(Space.m),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppButton(
          label: _signingIn ? 'Signing in…' : 'Sign in with Google',
          icon: Icons.login,
          expand: true,
          onPressed: _signingIn ? null : () => _signIn(service),
        ),
        if (_signingIn)
          const Padding(
            padding: EdgeInsets.only(top: Space.s),
            child: LinearProgressIndicator(),
          ),
      ],
    ),
  );

  Widget _action(
    String title,
    VoidCallback? onTap, {
    bool danger = false,
    String? subtitle,
  }) {
    return GroupRow(
      title: title,
      subtitle: subtitle,
      onTap: onTap,
      trailing: danger
          ? const Icon(Icons.delete_outline, color: AppColors.danger)
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final service = ref.watch(accountServiceProvider);
    final account = ref.watch(authAccountProvider).value;
    final bound = ref.watch(boundEmailProvider).value;
    final text = Theme.of(context).textTheme;

    final List<Widget> rows;
    if (service == null) {
      rows = [_note("Backup isn't available in this build")];
    } else if (account == null) {
      if (bound == null) {
        rows = [
          _note(
            'Back up your history to your Google account so it survives a '
            'lost or new phone.',
          ),
          _signInButton(service),
        ];
      } else {
        rows = [
          GroupRow(title: bound, subtitle: 'Sign in again to resume backup'),
          _signInButton(service),
          _action(
            'Remove my data from this phone',
            () => _removeData(service),
            danger: true,
          ),
        ];
      }
    } else {
      final status = ref.watch(syncStatusProvider).value ?? const SyncStatus();
      final last = ref.watch(lastBackupProvider).value;
      final syncing = status.phase == SyncPhase.syncing;
      final restoring = status.phase == SyncPhase.restoring;
      final line = switch (status.phase) {
        SyncPhase.syncing => 'Backing up…',
        SyncPhase.restoring => 'Restoring… ${status.restoredRows} items',
        SyncPhase.idle =>
          last == null
              ? 'Not backed up yet'
              : 'Last backed up '
                    '${formatBackupTime(last, ref.watch(clockProvider)())}',
      };
      rows = [
        GroupRow(
          title: account.email ?? account.name ?? 'Signed in',
          subtitle: line,
          trailing: syncing || restoring
              ? const SizedBox(
                  width: Space.l,
                  height: Space.l,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : null,
        ),
        if (!restoring) ...[
          _action(
            'Back up now',
            syncing ? null : () => ref.read(syncServiceProvider)?.syncNow(),
          ),
          _action('Sign out', () => guard(context, service.signOut)),
          _action(
            'Remove my data from this phone',
            () => _removeData(service),
            danger: true,
          ),
          _action(
            'Delete account',
            () => _deleteAccount(service),
            danger: true,
          ),
        ],
      ];
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: Space.m),
      child: DefaultTextStyle.merge(
        style: text.bodyLarge,
        child: Group(header: 'Account & backup', children: rows),
      ),
    );
  }
}

/// "Combine this phone's workouts with your backup, or use the backup?"
/// Dismissing the dialog counts as cancel.
Future<MergeChoice> chooseMergeDialog(BuildContext context) async {
  final result = await showDialog<MergeChoice>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Combine histories?'),
      content: const Text(
        "This phone has workouts that aren't in your account yet. Combine "
        "them with your backup, or replace this phone's data with your "
        'backup?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(MergeChoice.cancel),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(MergeChoice.useBackup),
          child: const Text('Use my backup instead'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(MergeChoice.merge),
          child: const Text('Merge'),
        ),
      ],
    ),
  );
  return result ?? MergeChoice.cancel;
}

/// "Replace this phone's data with the account's backup?" -> true to replace.
Future<bool> confirmReplaceDialog(BuildContext context, String? email) =>
    confirmDestructive(
      context,
      title: 'Replace data on this phone?',
      message:
          'This phone holds data from ${email ?? 'another account'}. Replace '
          "it with this account's backup? That account's backed-up data "
          'stays safe.',
      confirmLabel: 'Replace',
    );

/// "Keep your data on this phone?" -> true to keep.
Future<bool> keepDataDialog(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Keep your data on this phone?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.error,
          ),
          child: const Text('Remove'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Keep'),
        ),
      ],
    ),
  );
  return result ?? true;
}

/// One-time "Back up your history?" nudge after the 3rd finished workout
/// (T041). Safe to call after every finish; does nothing unless due.
Future<void> maybeShowBackupNudge(
  ProviderContainer ref, {
  required ScaffoldMessengerState messenger,
  required GoRouter router,
}) async {
  if (ref.read(accountServiceProvider) == null) return;
  if (ref.read(authAccountProvider).value != null) return;
  final settings = ref.read(settingsRepositoryProvider);
  if (await settings.readFlag(nudgeShownKey) != null) return;
  final stats = await ref
      .read(workoutRepositoryProvider)
      .homeStats(ref.read(clockProvider)());
  if (stats.gymWorkouts < nudgeAfterWorkouts) return;
  await settings.writeFlag(nudgeShownKey, 'true');
  messenger.showSnackBar(
    SnackBar(
      content: const Text('Back up your history?'),
      action: SnackBarAction(
        label: 'Sign in',
        onPressed: () => router.push(Routes.settings),
      ),
    ),
  );
}
