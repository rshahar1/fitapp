# Feature Specification: Daily step count

**Feature Branch**: `014-daily-steps`
**Created**: 2026-11-15
**Status**: Implemented

**Input**: Add daily step-count tracking, preferably via Google Fit. On by default, with an option
to turn it off in Settings. Owner decisions 2026-11-15: read steps through Android Health Connect
(Google Fit's developer APIs end at the end of 2026; the Google Fit app writes its steps into
Health Connect); only data from the moment access is granted is needed, no historical import.

## User Scenarios & Testing

### User Story 1 — See today's steps (P1)

A user opens the Train tab and sees how many steps they have taken today, as counted by Google
Fit, the phone, or any other app that shares steps with Health Connect.

**Acceptance Scenarios**

1. **Given** step access is granted, **When** the user opens the Train tab, **Then** a "Steps
   today" card shows today's total (local midnight to now), formatted with thousands separators.
2. **Given** the app returns from the background, **Then** the count refreshes without any tap.
3. **Given** no steps were recorded today, **Then** the card shows 0.
4. **Given** several apps report steps, **Then** the total is not double counted (Health Connect's
   aggregate is used).

### User Story 2 — Connect on first use (P1)

The feature is on by default, so a new or updated install offers to connect.

**Acceptance Scenarios**

1. **Given** the feature is on and access was never asked, **When** the user first opens the
   Train tab, **Then** a short sheet explains what is read (steps only, read-only, stays on the
   phone) with "Connect" and "Not now".
2. **When** the user taps "Connect", **Then** the Health Connect permission screen opens; on
   grant the card shows the count.
3. **When** the user taps "Not now" or denies, **Then** the sheet does not appear again by
   itself; the card shows "Connect" instead of a number, and tapping it asks again.
4. **Given** Health Connect is missing or needs an update (Android 13 and lower), **Then** the
   card offers "Get Health Connect", which opens its store page.
5. **Given** the device cannot run Health Connect at all, **Then** no card and no sheet appear.

### User Story 3 — Turn it off (P1)

**Acceptance Scenarios**

1. **Given** Settings, **Then** an "Activity" section has a "Daily steps" switch, on by default,
   with a subtitle showing the access state ("Connected to Health Connect", "Not connected — tap
   to connect", or "Health Connect not available").
2. **When** the user turns it off, **Then** the Train card disappears, no step data is read, and
   the first-use sheet never shows.
3. **When** the user turns it back on, **Then** the card returns; if access is missing, the app
   asks for it.
4. Revoking access in Health Connect is reflected the next time the app resumes (card shows
   "Connect").

### Edge Cases

- Reading fails (Health Connect error, timeout): the card shows "—" and never crashes the app.
- Midnight passes while the app is open: the next refresh counts the new day only.
- Access granted but nothing on the phone shares steps: the count is 0 with a static hint "Turn
  on Health Connect sharing in Google Fit".

## Requirements

### Functional Requirements

- **FR-001**: Today's step total is read from Health Connect's aggregated step count for the
  current local day.
- **FR-002**: Only the steps read permission is requested; nothing is written to Health Connect.
- **FR-003**: Step data is not stored in the app database, not backed up and not sent anywhere.
- **FR-004**: The feature is enabled by default; a Settings switch disables it, and when disabled
  no Health Connect call is made.
- **FR-005**: The first-use sheet is shown at most once per install (and again only if the user
  turns the feature on from Settings while access is missing — then the system permission is
  requested directly).
- **FR-006**: The count refreshes on Train tab open and on app resume.
- **FR-007**: The Android app declares the Health Connect permission rationale entry points
  required by the platform.
- **FR-008**: Everything else in the app works unchanged when Health Connect is unavailable,
  denied or failing.

### Key Entities

- **Step preference** (local setting): enabled (default true), intro shown (default false). Not
  synced (device-specific permission).

## Success Criteria

- **SC-001**: After granting access, today's steps appear on the Train tab within 2 seconds.
- **SC-002**: Turning the switch off removes the card immediately and causes zero further reads.
- **SC-003**: Connecting takes at most 2 taps from the first-use sheet (Connect, then Allow).
- **SC-004**: No crash or blocking error in any access state (granted, denied, unavailable,
  failing).

## Assumptions

- Android only; iOS HealthKit is out of scope (the app is Android-first).
- No step goal, no history chart, no historical import; the count is "today" only.
- The Google Play health-permissions declaration and privacy policy URL are filed by the owner in
  the Play Console before a public release.
