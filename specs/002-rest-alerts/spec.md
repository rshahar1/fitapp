# Feature Specification: Rest-End Alerts That Work

**Feature Branch**: `002-rest-alerts`

**Created**: 2026-11-13

**Status**: Draft

**Input**: User description: "Rest-end alerts that actually work. Bug: when the rest countdown
reaches 0 there is no sound at all. Required: an audible, short, pleasant sound when rest ends in
the foreground (respecting the Sound toggle); a system notification at rest end when the app is in
the background or the screen is off, kept in sync with the timer, and opening the live workout when
tapped; a notification permission request at a sensible moment with a graceful fallback; accurate
timing in the background. Covers T056 and T057 of feature 001. Offline only."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Hear when rest is over (Priority: P1)

A lifter logs a set, puts the phone on the bench with the app open, and wants to hear a clear,
short chime when the rest countdown hits zero, so they don't have to keep looking at the screen.

**Why this priority**: This is the reported bug. Today nothing is audible at zero, so the rest
timer only works if the user stares at it.

**Independent Test**: With Sound on, log a set with a 10-second rest and wait with the app open:
a chime plays once at 0:00 (and the phone vibrates if Vibrate is on). With Sound off, only the
vibration happens.

**Acceptance Scenarios**:

1. **Given** Sound is on and the app is open, **When** the countdown reaches 0, **Then** a short,
   pleasant chime plays exactly once, audible at normal media/notification volume.
2. **Given** Sound is off, **When** the countdown reaches 0, **Then** no sound plays; vibration
   follows the Vibrate setting.
3. **Given** the phone is in silent or do-not-disturb mode, **When** the countdown reaches 0,
   **Then** no sound plays (the phone's silent mode is respected) and vibration follows the phone's
   own rules.
4. **Given** the user logs the next set before 0, **Then** no chime plays for the earlier timer.
5. **Given** the chime plays, **Then** any music the user is playing is only briefly lowered, not
   stopped.

---

### User Story 2 - Get notified when the phone is locked or the app is in the background (Priority: P1)

Between sets the lifter locks the phone or switches to a music app. When rest ends they get a
system notification ("Rest over — time for your next set") with sound and/or vibration according
to their settings. Tapping it opens the live workout.

**Why this priority**: Most lifters lock the phone between sets; without this the timer is useless
for them.

**Independent Test**: Log a set with a 30-second rest, lock the phone, wait: within a few seconds
of 0:00 a notification arrives with sound; tapping it opens the workout screen showing overtime.

**Acceptance Scenarios**:

1. **Given** a rest timer is running and the app goes to the background, **When** rest ends,
   **Then** a notification appears titled "Rest over" with text "Time for your next set" and the
   exercise name, with sound/vibration per settings.
2. **Given** that notification, **When** the user taps it, **Then** the app opens on the live
   workout.
3. **Given** a scheduled notification, **When** the user logs another set, dismisses the rest pill,
   finishes or discards the workout, or the timer restarts with a new rest time, **Then** the
   earlier notification never fires (it is cancelled or replaced).
4. **Given** the app is in the foreground at rest end, **Then** the user gets the in-app chime and
   no duplicate system notification sound.
5. **Given** the rest notification is shown, **When** the user returns to the app, logs a set or
   dismisses the timer, **Then** the notification is removed.

---

### User Story 3 - Permission and timing are handled gracefully (Priority: P2)

The first time a rest timer starts, the app asks for permission to show notifications (only where
the system requires it). If the user declines, everything else keeps working and Settings explains
how to enable it. Settings also shows whether background alerts can be precise.

**Why this priority**: Required for Story 2 on newer Android versions, but the in-app chime works
without it.

**Independent Test**: On a fresh install, log the first set: the system permission prompt appears
once. Decline it: the timer and in-app chime still work, no further prompts appear during the
workout, and Settings shows "Notifications off — enable in system settings" with a button that
opens the system settings page.

**Acceptance Scenarios**:

1. **Given** notification permission was never requested, **When** the first rest timer of the
   install starts, **Then** the system permission prompt is shown once.
2. **Given** the user denied permission, **Then** no prompt appears again automatically; Settings
   shows the status and a button to open system settings.
3. **Given** precise alarms are allowed, **Then** the background notification arrives within
   5 seconds of the timer reaching 0.
4. **Given** precise alarms are not allowed, **Then** the notification still fires (possibly
   later) and Settings explains "Alerts may be late while the phone is idle" with a way to allow
   precise alerts.

---

### Edge Cases

- Rest time very short (10 s) and the user backgrounds the app immediately.
- The app is killed by the system while a timer is running: the scheduled notification still fires.
- The phone reboots during rest: no stale notification fires after reboot for an old timer.
- The timer is already in overtime when the app returns to the foreground: no late chime.
- Both toggles off: neither sound nor vibration; a background notification still appears silently.
- The user changes the Sound or Vibrate toggle while a timer is running: the new settings apply to
  the alert that has not fired yet.
- Two quick set logs in a row: only the latest timer can alert.
- Notification permission revoked mid-workout: no crash; in-app alert still works.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: When a running rest countdown reaches zero while the app is visible, the app MUST play
  a short (under 2 seconds), pleasant chime once if Sound is on.
- **FR-002**: The chime MUST respect the phone's silent / do-not-disturb mode and MUST NOT stop
  other audio playing on the device (it may briefly lower it).
- **FR-003**: Vibration at zero MUST follow the existing Vibrate setting, independently of Sound.
- **FR-004**: Whenever a rest countdown starts, the app MUST schedule a system notification for its
  end time that fires even if the app is in the background, the screen is off, or the app process
  was stopped by the system.
- **FR-005**: The scheduled notification MUST be cancelled or replaced when a new set is logged,
  the rest pill is dismissed, the workout is finished or discarded, or the timer restarts.
- **FR-006**: At most one rest notification can be pending or shown at a time.
- **FR-007**: The notification MUST read "Rest over" / "Time for your next set" plus the exercise
  name, and play sound / vibrate according to the Sound and Vibrate settings at the time it fires.
- **FR-008**: Tapping the notification MUST open the app on the live workout (or the Train tab if
  that workout no longer exists).
- **FR-009**: If the app is in the foreground when the timer ends, the user MUST NOT get both the
  in-app chime and a notification sound.
- **FR-010**: A shown rest notification MUST be removed when the user returns to the workout and
  logs a set, dismisses the timer, or finishes the workout.
- **FR-011**: The app MUST request notification permission (where the system requires it) the first
  time a rest timer starts, at most once automatically; declining MUST NOT affect any other feature.
- **FR-012**: Settings MUST show the notification permission status and, when off, a control that
  opens the system notification settings for the app.
- **FR-013**: When the system allows precise alarms, background alerts MUST fire within 5 seconds of
  the target; otherwise they MUST still fire as soon as the system allows, and Settings MUST explain
  this with a control to allow precise alerts.
- **FR-014**: After a phone restart, no notification for a timer that started before the restart
  may fire late.
- **FR-015**: All of this MUST work fully offline and add no accounts, network calls or trackers.

### Key Entities

- **Active rest timer** (existing): start time and target duration; now also the exercise name used
  in the notification and an identifier for the pending notification.
- **Alert settings** (existing): Sound on/off and Vibrate on/off.
- **Notification permission state** (new, read from the system): granted / denied / not asked yet;
  precise alarms allowed / not allowed.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: With Sound on and the app open, a chime is heard at 0:00 in 10 out of 10 trials.
- **SC-002**: With the phone locked and precise alerts allowed, the notification arrives within
  5 seconds of the timer reaching 0 in 10 out of 10 trials.
- **SC-003**: After logging the next set early, no stale alert (sound, vibration or notification)
  occurs in 10 out of 10 trials.
- **SC-004**: Tapping the notification shows the live workout within 2 seconds.
- **SC-005**: With notifications denied, a full workout can still be completed with the in-app
  chime, and the user is prompted at most once.
- **SC-006**: Music playing in another app continues after the chime in 10 out of 10 trials.

## Assumptions

- Android is the target platform for v1; iOS behaviour follows the same rules when iOS is released.
- The chime is an original short sound created for FitApp (no third-party audio), bundled with the
  app.
- "Precise alerts" relies on the system's exact-alarm permission; where the system does not grant it
  automatically, the user is guided to allow it in Settings rather than being blocked.
- The phone's silent mode wins over the Sound toggle (the app never overrides silent mode).
- Existing behaviour from feature 001 (countdown derived from a stored start time, overtime display,
  tap to dismiss) is unchanged.
