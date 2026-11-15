# Contract: App-side interfaces and UI (013)

Dart signatures are indicative; names follow the existing repositories.

## `SyncRemote` (`lib/data/sync/sync_remote.dart`)

The only code that talks to the backend for data. Two implementations: `SupabaseSyncRemote` and `FakeSyncRemote`
(tests; implements LWW, delete-wins, tombstone cascade and cursors in memory, mirroring the server triggers).

```dart
abstract interface class SyncRemote {
  Future<PushResult> push(PushBatch batch);               // sync_push
  Future<List<Map<String, Object?>>> pullPage(            // ordered by server_updated_at, pk
      SyncTable table, DateTime since, {Object? afterPk, int limit = 1000});
  Future<bool> hasCloudData();
}
```

## `SyncService` (`lib/data/sync/sync_service.dart`)

```dart
class SyncService {
  Future<SyncOutcome> syncNow({SyncReason reason});       // single-flight; coalesces calls within 5 s
  Future<void> restore({void Function(RestoreProgress)? onProgress}); // full pull from epoch
  Stream<SyncStatus> watchStatus();                        // idle | syncing | restoring | error(silent) | signedOut
}
```

- `SyncOutcome`: `ok`, `partial` (some rows rejected), `failed` (transport), `skipped` (not signed in / not bound).
- Never throws to callers; never shows UI by itself (FR-002).
- Triggers wired in `app.dart`: app start, `AppLifecycleState.resumed`, after `WorkoutRepository.finish`, after
  sign-in decision completes, Settings "Back up now".

## `AuthRepository` (`lib/data/repositories/auth_repository.dart`)

```dart
class AuthRepository {
  Stream<AuthAccount?> watchAccount();        // email, display name, user id; null when signed out
  Future<SignInResult> signInWithGoogle();     // cancelled | failed | signedIn(AuthAccount)
  Future<void> signOut();                      // keeps local data and binding
  Future<void> deleteAccount();                // edge function, then signOut
  bool get isConfigured;                       // false when env keys are empty
}
```

## `DeviceBinding` (`lib/data/sync/device_binding.dart`)

```dart
enum SignInDecision { firstBackup, restore, askMerge, askReplace, nothingToDo }
class DeviceBinding {
  Future<SignInDecision> decide(String userId);   // data-model §5
  Future<void> bind(String userId);
  Future<void> wipeUserData();                    // keeps built-in library; clears sync_state, pending_deletes
}
```

## UI: Settings → "Account & backup" section

| State | Shows | Actions |
|---|---|---|
| Not configured (empty env) | "Backup not available in this build" | none |
| Signed out, unbound | "Back up your history to your Google account" | **Sign in with Google** |
| Signed out, bound (session expired or signed out) | account email, "Sign in again to resume backup" | **Sign in with Google**, Remove my data from this phone |
| Signed in, syncing/idle | account email, "Last backed up 5 min ago" / "Backing up…" / "Not backed up yet" | Back up now, Sign out, Remove my data from this phone, Delete account |
| Restoring | progress ("Restoring 1,240 of ~15,000 items") | none (screen stays usable) |

Dialogs (all destructive ones use the existing confirm pattern, constitution V):

- **Merge**: "This phone has workouts that aren't in your account yet. Combine them with your backup?" → Merge / Cancel.
- **Replace**: "This phone holds data from <email X>. Replace it with <email Y>'s backup? Data of X stays in X's
  account." → Replace / Cancel.
- **Remove data**: "Remove all your workouts, templates and activities from this phone? Backed-up data stays in your
  account." → Remove / Cancel.
- **Delete account**: two-step confirm; then "Keep data on this phone?" → Keep / Remove.

One-time nudge (dismissible, never repeated): after the 3rd finished workout while signed out and configured, a
SnackBar "Back up your history?" with action "Sign in". Stored as setting `sync.nudge_shown`.

Sign-in failures: cancelled → nothing; failed → SnackBar "Couldn't sign in. Try again." Sync failures → silent.
