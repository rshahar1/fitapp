# Feature Specification: Start/Log Hub (center "+" action)

**Feature Branch**: `011-start-hub`

**Created**: 2026-11-14

**Status**: Draft

**Input**: Owner decision (2026-11-14) in [docs/ux/unified-start-proposal.md](../../docs/ux/unified-start-proposal.md)
§5, Option C, slice 1: "a center '+' start/log hub in the bottom bar, reachable from any tab, that
starts any sport now or logs a past session; gym start stays one tap from Train". Slices 2
(unified feed) and 3 (cardio templates) are separate features.

## Clarifications

### Session 2026-11-14

- Q: Name of the new fourth tab (Settings and Exercise library)? → A: **You** (person icon), route `/you`.
- Q: What do non-live sports under More sports do? → A: Open the **past-session form prefilled**
  with that sport and today. No timed session in this slice.
- Q: Template START while a session is in progress: keep the dialog? → A: **No.** Every blocked
  start shows the same message ("<Session> in progress. Finish it first." with Open).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Start a live run or ride from anywhere (Priority: P1)

A runner opens the app on any tab, taps the "+" in the middle of the bottom bar, sees a "Start
now" list with Gym workout, Running and Cycling, taps Running and lands on the GPS setup screen.
Two taps instead of three, and no "Log" wording on the way.

**Why this priority**: Live tracking is the action most hidden today (3 taps behind a "Log
activity" form). Making it a peer of the gym start is the core of the redesign.

**Independent Test**: From each of the four tabs, tap "+", tap Running: the app is on the
tracking setup route for running.

**Acceptance Scenarios**:

1. **Given** any tab is shown, **When** the user taps "+", **Then** the Start/Log hub opens and
   the selected tab does not change.
2. **Given** the hub is open and nothing is in progress, **When** the user taps Running (or
   Cycling), **Then** the hub closes and the tracking setup screen for that sport opens.
3. **Given** the hub is open, **When** the user taps Gym workout, **Then** an empty gym workout
   starts and the live workout screen opens.
4. **Given** the hub is open and templates exist, **When** the user taps a template, **Then** a
   workout from that template starts and the live workout screen opens.

---

### User Story 2 - Gym stays one tap from Train (Priority: P1)

A lifter opens the app on Train and taps "Start gym workout" in the hero card, or START on a
template card. Exactly as today: one tap to the live workout.

**Why this priority**: The owner's hard constraint. The core gym user must not pay for the
redesign.

**Independent Test**: On Train with nothing in progress, one tap on "Start gym workout" opens the
live workout screen with an active workout; one tap on a template's START does the same with the
template's exercises.

**Acceptance Scenarios**:

1. **Given** Train with nothing in progress, **When** the user taps "Start gym workout", **Then**
   a workout starts and the live workout screen opens.
2. **Given** Train with templates, **When** the user taps START on a template, **Then** a workout
   from that template starts and the live workout screen opens.

---

### User Story 3 - One "in progress" session at a time, everywhere (Priority: P1)

While a gym workout or a GPS session is running, every start entry point (hub rows, Train hero,
template STARTs) refuses to start a second session and offers to open the running one. The hub's
first row and Train's hero become "Continue …" for the session in progress.

**Why this priority**: Today the guards differ per entry point (the activity sheet checks both
kinds of session, template starts check only gym, GPS starts only from one sheet). Two parallel
sessions corrupt history and the tracking state.

**Independent Test**: With an active GPS session, tap "+" → Gym workout: no workout is created, a
message "Running in progress. Finish it first." with an Open action appears. Same with an active
gym workout and "+" → Running: no tracking setup opens.

**Acceptance Scenarios**:

1. **Given** a gym workout in progress, **When** the hub opens, **Then** its first row is
   "Continue workout" and tapping it opens the live workout.
2. **Given** a running session in progress, **When** the hub opens, **Then** its first row is
   "Continue running" (with the sport's name) and tapping it opens the live tracking screen.
3. **Given** any session in progress, **When** the user taps any start row in the hub or a
   template START on Train, **Then** nothing new starts and a message names the session in
   progress with an Open action that goes to it.
4. **Given** a GPS session in progress, **When** Train is shown, **Then** the hero card shows the
   sport, elapsed time and distance with a "Continue" button that opens the live tracking screen,
   and there is no separate tracking banner.
5. **Given** a gym workout in progress, **When** Train is shown, **Then** the hero card shows
   "Workout in progress" and "Continue workout" as today.

---

### User Story 4 - Log a past session from the hub (Priority: P2)

A user who forgot to record yesterday's Pilates class taps "+", then "Log a past session" under
"Earlier", picks the sport, date and duration, and saves. The form no longer offers "Start live":
it is only for sessions that already happened (and for editing them from History).

**Why this priority**: Separates "now" from "earlier" by intent; removes the mixed launcher/form.

**Independent Test**: "+" → Log a past session opens the activity form titled "Log a past
session" with no "Start live" button and no "or log it manually below" text, for any sport.

**Acceptance Scenarios**:

1. **Given** the hub, **When** the user taps Log a past session, **Then** the past-session form
   opens with no sport preselected.
2. **Given** the form with Running or Cycling selected, **Then** no "Start live" control and no
   "or log it manually below" text appear.
3. **Given** a session in progress, **When** the user taps Log a past session, **Then** the form
   opens normally (logging the past is never blocked).
4. **Given** History, **When** the user opens an activity to edit it, **Then** the same form opens
   in edit mode as today.

---

### User Story 5 - Other sports under "More sports" (Priority: P2)

A user who just finished a snowboarding day taps "+" → More sports → Snowboarding. Sports without
live tracking have no "start now" mode in this slice, so the past-session form opens with
Snowboarding and today preselected.

**Why this priority**: Every sport is reachable from the hub; the long tail does not clutter the
top of the list.

**Independent Test**: "+" → More sports lists Functional training, Snowboarding and Pilates;
tapping Pilates opens the form with Pilates selected and the date "Today".

**Acceptance Scenarios**:

1. **Given** the hub, **When** the user taps More sports, **Then** the sports without live
   tracking are listed.
2. **Given** that list, **When** the user taps a sport, **Then** the past-session form opens with
   that sport selected and today's date.

---

### User Story 6 - New "You" tab for settings and the exercise library (Priority: P3)

The Train header icons (Exercises, Settings) are gone. A fourth tab holds Exercise library and
Settings, so the bottom bar is Train · History · + · Progress · You with "+" in the centre.

**Why this priority**: Needed to keep "+" centred with four real destinations; low risk.

**Independent Test**: Tap the fourth tab, tap Settings: the settings screen opens; back, tap
Exercise library: the library opens.

**Acceptance Scenarios**:

1. **Given** the bottom bar, **Then** it has five slots in the order Train, History, +, Progress,
   You, and "+" is never shown as selected.
2. **Given** the You tab, **When** the user taps Settings or Exercise library, **Then** that
   screen opens; back returns to the You tab.
3. **Given** Train, **Then** it has no header icons and no "Log activity" button.

### Edge Cases

- Hub opened while the sheet is already open: the bottom bar is covered by the sheet, so a second
  hub cannot open.
- A session ends while the hub is open (e.g. the GPS session is finished from the notification):
  the hub reflects the current state the next time it opens; a start tapped against a stale view
  is still checked against the stored state at tap time.
- Double tap on a start row: the first tap starts, the second is blocked by the same guard (a
  session is now in progress) or ignored because the hub has closed.
- An unknown in-progress sport id (from a newer app version): the label falls back to "Activity".
- No templates: the hub shows no template rows (no empty-state text needed in the hub).
- Back gesture with the hub open closes the hub and stays on the current tab.
- Deep links to `/settings` and `/exercises` keep working.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The bottom bar MUST have five slots: Train, History, a centre "+" action, Progress,
  You. "+" MUST NOT be a destination: tapping it opens the hub sheet and leaves the current tab
  selected.
- **FR-002**: "+" MUST have the accessible label "Start or log a session" and a target of at least
  48×48 dp.
- **FR-003**: The hub MUST show a "Start now" section with, in order: a "Continue …" row when a
  session is in progress; Gym workout; one row per sport with live tracking, in registry order;
  More sports; one row per template.
- **FR-004**: The hub MUST show an "Earlier" section with "Log a past session".
- **FR-005**: Live-tracking sport rows MUST open the tracking setup for that sport
  (`/track/new?type=<id>`).
- **FR-006**: More sports MUST list the sports without live tracking; choosing one MUST open the
  past-session form with that sport and today preselected.
- **FR-007**: A single start guard MUST decide, from the gym workout and GPS session currently in
  progress, whether a new gym or GPS start is allowed, and if not which session blocks it (gym
  workout or the GPS sport). Every start entry point (hub rows, Train hero, Train template START)
  MUST use it and MUST re-check the stored state at the moment of the tap.
- **FR-008**: A blocked start MUST create nothing and MUST show "<Session> in progress. Finish it
  first." with an Open action that goes to the session in progress ("Workout" or the sport name).
- **FR-009**: When a session is in progress, the hub's first row MUST be "Continue workout" (gym)
  or "Continue <sport>" (GPS) and open that session.
- **FR-010**: Train MUST keep the one-tap "Start gym workout" hero button and the templates with
  START; it MUST NOT show the "Log activity" button or the header icons.
- **FR-011**: When a GPS session is in progress, Train's hero card MUST show "<Sport> in
  progress", elapsed time and distance, and a "Continue <sport>" button to the live tracking
  screen; the separate tracking banner MUST be removed.
- **FR-012**: The activity form MUST NOT offer "Start live" or the "or log it manually below"
  line; a new entry MUST be titled "Log a past session"; editing keeps "Edit activity".
- **FR-013**: The You tab MUST list Exercise library and Settings, opening the existing screens;
  their routes stay valid.
- **FR-014**: The data layer MUST also refuse starting a template workout while a GPS session is
  in progress (defence in depth; the empty-workout and GPS starts already refuse both).
- **FR-015**: PRD §6 and the route contract MUST describe the new navigation.

### Key Entities

- **Session in progress**: at most one of a gym workout without end time or a GPS tracking
  session; identified for the user by kind (gym) or sport (GPS).
- **Start request**: the kind of start asked for (empty gym, gym template, GPS sport); the guard
  answers allowed or blocked-by(session).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Starting a live run or ride takes 2 taps from any tab (down from 3, from Train only).
- **SC-002**: Starting an empty or templated gym workout from Train still takes exactly 1 tap.
- **SC-003**: Continuing any session in progress takes 1 tap from Train or 2 from any tab.
- **SC-004**: In 100% of entry points, starting while a session is in progress creates no second
  session.
- **SC-005**: Logging a past session is reachable from every tab in 2 taps.

## Assumptions

- Non-live sports get no timed "start now" session in this slice; they log via the form.
- Gym past-session logging is out of scope (the existing backdate on a workout remains).
- Train stats and Recent stay as they are (gym-centric); sport-neutral stats are slice 2.
- Cardio templates are slice 3; the hub lists gym templates only.
- The hub is a bottom sheet; the fourth tab is named You (clarified).
- No schema change, no new package.
