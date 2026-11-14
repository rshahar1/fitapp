# Feature Specification: Cloud Backup and Sync

**Feature Branch**: `013-cloud-sync`

**Created**: 2026-11-14

**Status**: Draft

**Input**: User description: "Cloud data synchronization and persistence for fitapp so user data isn't lost if a device is lost or upgraded. Currently all data is stored locally on the device. Use Supabase, factor in Google Sign-In for auth and data ownership, keep the app local-first, and migrate the current local-only storage to a synchronized backend model." (Design background: `docs/proposals/cloud-sync-supabase.md`; PRD §8, milestone M7.)

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Turn on backup by signing in with Google (Priority: P1)

A user who has been logging workouts on their phone opens Settings, taps "Sign in with Google", picks their Google
account, and from then on their whole history (workouts, sets, plans, templates, custom exercises, sport activities)
is backed up to their personal cloud account. The app keeps working exactly as before, including offline; backup
happens quietly in the background and Settings shows when the last backup succeeded.

**Why this priority**: This is the protection the feature exists for. Without it nothing can be restored. It also
delivers value alone: even before restore exists in the UI, the data is safe on the server.

**Independent Test**: On a phone with existing history, sign in with Google, wait for "Last backed up" to show a
time, then confirm in the backend that every workout, set, template, plan, custom exercise and activity of that user
is present and that no other user can see it.

**Acceptance Scenarios**:

1. **Given** a signed-out user with 50 finished workouts, **When** they sign in with Google and stay online,
   **Then** all 50 workouts with their exercises, sets, notes and plan snapshots are backed up and Settings shows
   "Last backed up" with the current time.
2. **Given** a signed-in user, **When** they finish a workout, **Then** that workout is backed up without any extra
   action.
3. **Given** a signed-in user in airplane mode, **When** they log and finish a workout, **Then** logging works with
   no error message, and the workout is backed up automatically the next time the app starts or returns to the
   foreground with a connection.
4. **Given** a signed-in user, **When** they edit or delete a past workout, template or activity, **Then** the
   backup reflects the edit or deletion after the next sync.
5. **Given** a user who never signs in, **When** they use the app, **Then** nothing is sent off the device and the
   app behaves exactly as it does today.

---

### User Story 2 - Restore everything on a new or replacement phone (Priority: P1)

A user who lost, reset or upgraded their phone installs the app, signs in with the same Google account, and gets
their full history back: past workouts, progress charts, current plans per exercise and per template, templates,
custom and hidden exercises, and sport activities including tracked routes.

**Why this priority**: This is the outcome the user actually asked for ("data isn't lost if a device is lost or
upgraded"). It is the M7 acceptance criterion.

**Independent Test**: Back up a known history from phone A, install a fresh app on phone B, sign in with the same
account, and compare History, Progress, templates and plans on B against A.

**Acceptance Scenarios**:

1. **Given** a backed-up account and a fresh install with no local history, **When** the user signs in, **Then** the
   app shows restore progress and afterwards History, Progress, templates, plans and activities match the backup.
2. **Given** a restore is interrupted (app closed or connection lost), **When** the user opens the app again online,
   **Then** the restore continues and completes without duplicates.
3. **Given** a restored phone, **When** the user starts a workout for an exercise, **Then** the suggested weight is
   the one from their latest plan (progressive overload continues where it stopped).

---

### User Story 3 - Keep two phones in step (Priority: P2)

A user signed in on two devices (e.g. an old and a new phone during an upgrade, or a phone and a tablet) sees changes
made on one appear on the other after it syncs. Deletions on one device disappear on the other too and never come
back.

**Why this priority**: Upgrades often overlap both phones for a while; without this, edits on one phone would be
silently lost or deleted items would reappear. Less common than the single-device case.

**Independent Test**: With two devices signed in to one account, create, edit and delete a workout, a template and an
activity on device A; open device B and verify each change is reflected.

**Acceptance Scenarios**:

1. **Given** devices A and B on one account, **When** a workout is logged on A and B is later opened online,
   **Then** the workout appears on B.
2. **Given** the same plan is changed on A and then later on B before either syncs, **When** both sync, **Then**
   both devices end up with the most recent change.
3. **Given** a workout is deleted on A, **When** B syncs, **Then** the workout disappears from B and is not
   recreated by any later sync, even if B had edited it while offline.

---

### User Story 4 - Sign-in on a phone that already has data (Priority: P2)

A user signs in on a phone that already holds history, while their account already holds a backup from another phone
(both phones were used before ever signing in, or the phone was used with a different account). The app explains the
situation and lets the user choose, so no data is merged into or wiped from the wrong account by surprise.

**Why this priority**: Rare but the riskiest path for data loss or data leaking between accounts.

**Independent Test**: Prepare a phone with local history and an account with a different backup; sign in and walk
through each choice, verifying the resulting data on the phone and in the account.

**Acceptance Scenarios**:

1. **Given** a phone with local history that was never signed in, and an account with a backup, **When** the user
   signs in and chooses "Merge", **Then** both histories are combined on the phone and in the account with no
   duplicates and no lost items.
2. **Given** a phone whose data belongs to account X, **When** the user signs in with account Y, **Then** the app
   warns that the phone holds another account's data and only replaces it with Y's data after explicit confirmation;
   cancelling keeps the phone unchanged and signed out.
3. **Given** a merge where both sides have a template (or custom exercise) with the same name, **When** the merge
   completes, **Then** both are kept and one is renamed with a visible suffix such as " (2)".

---

### User Story 5 - Sign out, remove data, delete account (Priority: P3)

A signed-in user can sign out (data stays on the phone, backup stops), remove their data from this phone, or
permanently delete their cloud account and its backup.

**Why this priority**: Required for user control, shared devices and store policy, but not needed to protect data.

**Independent Test**: Exercise each action from Settings and verify phone and backend state afterwards.

**Acceptance Scenarios**:

1. **Given** a signed-in user, **When** they sign out, **Then** their history stays visible on the phone and no
   further data is sent until they sign in again.
2. **Given** a signed-in or signed-out user with data on the phone, **When** they choose "Remove my data from this
   phone" and confirm, **Then** all their personal data is erased from the phone and the app returns to a first-run
   state with the built-in exercise library.
3. **Given** a signed-in user, **When** they choose "Delete account" and confirm twice, **Then** their account and
   all backed-up data are permanently removed from the server, and they are asked whether to keep or remove the data
   on the phone.

---

### Edge Cases

- A set is cleared and re-logged with the same set number before a sync: the backup must end with only the new set.
- A row is edited on the phone while a sync of that row is in progress: the edit must not be lost or marked as backed
  up before it is sent.
- A template is deleted on one device while the other device uses it in a workout: the workout keeps its history;
  the template stays deleted.
- A built-in exercise hidden (feature 012 soft delete) on one device must stay hidden after restore, without affecting
  other users.
- A live GPS tracking session in progress is never synced; only the saved activity is.
- The app is killed mid-sync or mid-restore: the next sync resumes without duplicates or partial records.
- The device clock is wrong by hours: changes are still delivered; "most recent change wins" uses the device-recorded
  time, and a deletion always wins regardless of clocks.
- The Google sign-in sheet is cancelled or fails: the app stays signed out with a short message, no data changes.
- The account's session expires or is revoked: sync stops silently, Settings shows "Sign in again", local data and
  logging are unaffected.
- Very large histories (several years, thousands of sets, tracked routes): backup and restore complete without the
  app freezing.
- Two devices finish workouts at the same moment: both workouts are kept.

## Requirements *(mandatory)*

### Functional Requirements

**Local-first behaviour**

- **FR-001**: The app MUST keep the on-device data as the source of truth; every existing screen and action MUST work
  identically when signed out, offline, or while a sync is running.
- **FR-002**: Sync failures MUST be silent (no error dialogs during training) and MUST be retried automatically on
  the next sync trigger; no change may be lost because a sync failed.
- **FR-003**: No user data may leave the device unless the user has signed in (opt-in, per the constitution).

**Authentication and ownership**

- **FR-004**: Users MUST be able to sign in with their Google account from Settings, using the device's native
  account picker.
- **FR-005**: Each backed-up record MUST belong to exactly one account, and an account MUST only ever be able to
  read or change its own records; this MUST be enforced by the backend, not only by the app.
- **FR-006**: The phone MUST remember which account its data belongs to and MUST NOT mix data of two accounts without
  explicit user confirmation (User Story 4).
- **FR-007**: Users MUST be able to sign out, remove their data from the phone, and permanently delete their account
  with all backed-up data (User Story 5). Destructive actions require confirmation.

**What is backed up**

- **FR-008**: The backup MUST include workouts, workout exercises (including plan and result snapshots), sets,
  per-exercise plans, templates with their exercises and per-template plans, custom exercises, the user's hidden
  built-in exercises, and sport activities (including tracked route and splits).
- **FR-009**: The backup MUST include these preferences: default rest time, rest-alert vibration and rest-alert sound.
  Transient state (an active rest timer, notification-permission prompts) MUST NOT be backed up.
- **FR-010**: In-progress GPS tracking sessions and their raw location points MUST NOT leave the device.
- **FR-011**: Unfinished (in-progress) workouts MUST be backed up and restored like finished ones, so they appear as
  resumable on a restored device.
- **FR-012**: The built-in exercise library MUST continue to ship with the app and MUST NOT be duplicated per user in
  the backup.

**Sync behaviour**

- **FR-013**: The app MUST sync automatically on app start, when it returns to the foreground, after a workout is
  finished, and right after sign-in; Settings MUST offer a manual "Back up now".
- **FR-014**: Only one sync may run at a time; repeated triggers within a few seconds MUST be coalesced.
- **FR-015**: On first sign-in the app MUST back up all existing local history, not only changes made afterwards.
- **FR-016**: Creations, edits and deletions made on one device MUST reach every other signed-in device of the same
  account on its next sync.
- **FR-017**: When the same record was changed on two devices, the most recent change MUST win; a deletion MUST
  always win over an edit and a deleted record MUST never reappear.
- **FR-018**: A change made on the phone while a sync is in progress MUST remain pending and be sent on a later sync.
- **FR-019**: Incoming changes MUST NOT overwrite a newer local change that has not yet been backed up.
- **FR-020**: Repeating or resuming any sync or restore MUST NOT create duplicates.
- **FR-021**: Settings MUST show the account in use and the time of the last successful backup, or "Not backed up"
  / "Sign in again" when appropriate.

**Restore and merge**

- **FR-022**: Signing in on a phone with no local history MUST restore the account's full backup, showing progress
  until done.
- **FR-023**: Signing in on a never-signed-in phone that has history, with an account that has a backup, MUST ask the
  user to merge; merging MUST keep every record from both sides and rename name clashes of templates and custom
  exercises with a visible suffix.
- **FR-024**: After restore or merge, progression MUST continue from the latest plans (no recalculation that changes
  past results).

**Engineering quality (from the constitution)**

- **FR-025**: Existing on-device data MUST survive the app update that introduces this feature (no data loss on
  upgrade).
- **FR-026**: Backend access rules and backend schema changes MUST be versioned in the repository and covered by
  automated tests, including a test that one account cannot see another's data.
- **FR-027**: No secrets or credentials may be committed; backend keys used by the app MUST come from git-ignored
  configuration with a redacted example committed.

### Key Entities

- **Account**: A person identified by their Google identity. Owns all of their backed-up records.
- **Device binding**: The phone's record of which account its local data belongs to, and when it last synced.
- **Synced record**: Any backed-up item (workout, workout exercise, set, plan, template, template exercise, custom
  exercise, hidden built-in exercise, activity, preferences). Carries its owner, the time it was last changed, and
  whether it was deleted.
- **Pending change**: A local creation, edit or deletion not yet backed up.
- **Sync progress marker**: Per kind of record, how far this phone has received changes from the account.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A user with a fresh install who signs in recovers 100% of their backed-up workouts, sets, plans,
  templates, custom exercises and activities (verified by comparing counts and contents with the source phone).
- **SC-002**: Restoring a history of 2 years of training (about 300 workouts, 15,000 sets, 100 tracked activities)
  completes in under 60 seconds on a typical mobile connection.
- **SC-003**: A workout finished while online is backed up within 30 seconds; one finished offline is backed up
  within 30 seconds of the app next being opened online.
- **SC-004**: Signing in with Google takes no more than 3 taps from Settings and under 30 seconds.
- **SC-005**: Logging a set, finishing a workout and opening History take no noticeably longer while signed in than
  while signed out (no visible delay added by sync).
- **SC-006**: In automated tests, zero records of one account are readable or writable by any other account.
- **SC-007**: In automated two-device tests (create, edit, conflicting edits, delete, offline then reconnect), both
  devices end with identical data in 100% of runs, with no duplicates and no deleted record reappearing.

## Assumptions

- Android is the target platform for this feature; iOS (and the Apple Sign-In it would require) is out of scope.
- Google is the only sign-in method in this feature; email magic link and Apple Sign-In (PRD §8) are later.
- No anonymous cloud accounts: the app stays fully local until the user signs in.
- Sign-in is optional; the app never forces it. A one-time, dismissible prompt to enable backup may be shown.
- Sign-out keeps the data on the phone by default; removal is a separate, explicit action.
- Sync is near-real-time only at the listed triggers; live push of changes between devices is out of scope.
- Sharing data between users, coaches or friends is out of scope (no social features, PRD §8).
- Backup of photos or other files is out of scope (the app stores none today).
- Users have intermittent connectivity; the app must never depend on being online.
- Depends on a hosted backend project (Supabase, per PRD §8 and the proposal) and a Google Cloud OAuth setup; both
  are configured by the owner and documented in the plan.
- The constitution currently marks Phase 2 sync as LATER and limits dependencies; it must be amended before
  implementation (`/speckit-constitution`).
