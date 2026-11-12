# Feature Specification: FitApp v1 – Offline Workout Logger with Automatic Progressive Overload

**Feature Branch**: `001-fitapp-v1`

**Created**: 2026-11-12

**Status**: Draft

**Input**: User description: "Implement the FitApp v1 PRD (`docs/PRD-fitapp-flutter.md`, v2.1): a
minimalist, fast, offline-first gym workout logger built around automatic progressive overload, with
one-tap set logging, a configurable rest timer, editable history, and progress analytics. Milestones
M0–M6; Phase 2 sync (M7) is out of scope."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Log a workout and progress automatically (Priority: P1)

A lifter opens the app in the gym, starts a workout, adds an exercise, sets up a plan the first time
(base weight, target reps, number of sets, increment), and logs each set with one tap when they did
what was prescribed. The last set of every exercise is an "overload" set at base + increment. When
they finish, the app tells them whether each exercise's working weight goes up next time.

**Why this priority**: This is the product. Without it there is no app; with only this, the lifter
already gets automatic progressive overload.

**Independent Test**: Start a workout, add Incline Dumbbell Bench Press, set plan `20 kg × 10 × 3,
+2.5`, log `20×10, 20×10, 22.5×6`, finish. The summary shows `20 kg → 22.5 kg`, and the next workout
prescribes `22.5, 22.5, 25`.

**Acceptance Scenarios**:

1. **Given** no workout is in progress, **When** the user taps Start workout, **Then** a live workout
   opens with a header showing Duration, Volume, Sets and a Finish button.
2. **Given** a live workout, **When** the user adds an exercise that has no plan, **Then** an inline
   plan setup card appears with base weight, target reps (default 10), sets (default 3, min 2), and
   increment chips +1 / +2 / +2.5 / +5 preselected to the exercise's default increment.
3. **Given** a plan `base 20, reps 10, sets 3, inc 2.5`, **When** the exercise card shows, **Then**
   the set table lists sets 1–2 at 20 kg × 10 and set 3 (marked as overload ↑) at 22.5 kg × 10,
   dimmed until logged, with a PREVIOUS column showing the same set from the last session or `—`.
4. **Given** an unlogged set row, **When** the user taps its check box, **Then** the set is logged
   exactly as prescribed, the row turns full-brightness accent, and the header totals update.
5. **Given** a set row, **When** the user taps the row, **Then** a bottom sheet opens with large
   weight (steps by increment) and reps (steps by 1) steppers, Log/Update and Clear set.
6. **Given** a logged working set with fewer reps than the target, **Then** its reps show in red
   (e.g. `8 / 10`).
7. **Given** sets `20×10, 20×10, 22.5×6`, **When** the user finishes, **Then** the summary shows
   `⬆ Incline Dumbbell Bench Press: 20 kg → 22.5 kg` and the next prescription is `22.5, 22.5, 25`.
8. **Given** sets `22.5×10, 22.5×8, 25×4`, **When** the user finishes, **Then** the summary shows
   `• … stays at 22.5 kg`.
9. **Given** a workout with no logged sets, **When** the user taps Finish, **Then** the app offers to
   discard the workout (with confirmation) instead of saving it.
10. **Given** the app is killed mid-workout, **When** it is reopened, **Then** every logged set is
    still there and the home tab offers Continue workout.

---

### User Story 2 - Rest between sets with a countdown timer (Priority: P2)

After each logged set a rest countdown appears in a fixed footer pill next to Finish. It counts down
from the exercise's own rest time or the global default (60 s out of the box), pulses at zero, then
shows overtime. The lifter can change the default in Settings and override it per exercise.

**Why this priority**: Rest timing is used on every set and was a top request, but logging works
without it.

**Independent Test**: Log a set; the footer shows a countdown from 1:00 without moving any rows; at
0 the phone pulses and the pill shows `+0:05` etc. Change the default to 90 s in Settings, restart
the app, log a set: it counts down from 1:30.

**Acceptance Scenarios**:

1. **Given** default settings, **When** a set is logged, **Then** a countdown from 60 s appears in the
   footer and no set row changes position.
2. **Given** an exercise with a custom rest time of 120 s, **When** one of its sets is logged,
   **Then** the countdown starts at 2:00.
3. **Given** a countdown reaches 0, **Then** the device gives a haptic pulse (and a sound if enabled)
   and the pill switches to a muted overtime count-up (`+0:12`).
4. **Given** a running timer, **When** the next set is logged, **Then** the timer restarts; **When**
   the pill is tapped, **Then** it is dismissed.
5. **Given** the app is backgrounded for 40 s during a 60 s countdown, **When** it returns, **Then**
   the pill shows about 0:20 remaining.
6. **Given** the Settings screen, **When** the user sets the default rest time with the stepper
   (5 s steps, 10 s–10 min) or a preset chip (30/60/90/120/180 s), **Then** the value persists across
   restarts and applies to the next logged set.

---

### User Story 3 - Correct history safely (Priority: P2)

The lifter browses finished workouts by month, opens one, and fixes mistakes: changes or clears a
set, adds or removes an exercise, resumes the most recent workout if they finished by mistake, or
deletes a workout. The current working weight is only rewritten when it is safe to do so.

**Why this priority**: Mistakes happen every week; without safe correction the progression becomes
wrong and the lifter stops trusting it.

**Independent Test**: Run PRD section 11 scenarios 4–8 through the History tab and verify the
current base weight after each.

**Acceptance Scenarios**:

1. **Given** finished workouts, **When** the user opens History, **Then** workouts are grouped by
   month, each row showing date, exercise names, total volume, set count and duration.
2. **Given** the latest finished workout (20 → 22.5), **When** the user edits set 2 to 9 reps,
   **Then** the current base becomes 20; **When** they change it back to 10, **Then** it is 22.5.
3. **Given** two sessions (20→22.5, then 22.5→25), **When** the user edits the first to fail,
   **Then** that workout's stored result becomes 20 but the current base stays 25.
4. **Given** the most recent finished workout and no workout in progress, **When** the user taps
   Resume, **Then** its progression is undone (base back to 20), it becomes the live workout, and
   finishing again re-applies progression.
5. **Given** a workout that is not the most recent, or another workout is in progress, **Then**
   Resume is not offered.
6. **Given** the user manually changed the base to 30 after finishing, **When** they resume and
   re-finish, **Then** the result is judged on the original plan but the current base stays 30.
7. **Given** the latest finished workout, **When** it is deleted (after confirmation), **Then** its
   increase is undone; deleting an older workout leaves the current base unchanged.

---

### User Story 4 - See progress per exercise (Priority: P3)

The lifter opens the Progress tab to see workouts per week and every trained exercise with its
current working weight, then drills into an exercise for metric tiles, a chart (Working weight /
Volume / Est. 1RM), personal-record badges, session history and the plan editor.

**Why this priority**: Motivating and useful, but only valuable once workouts are being logged.

**Independent Test**: With 1, 2 and 25 logged sessions of one exercise, the detail page renders the
chart (last 20 sessions), tiles, PR badge and history without errors.

**Acceptance Scenarios**:

1. **Given** workouts over several weeks, **Then** a bar chart shows workouts per ISO week for the
   last 8 weeks with the current week highlighted.
2. **Given** trained exercises, **Then** the list shows them most recent first with their current
   base weight.
3. **Given** an exercise detail page, **Then** the Summary tab shows Current base, Heaviest set,
   Est. 1RM and Sessions tiles, a chart with three metric chips, and "compared to previous" deltas.
4. **Given** the latest session beat all history on heaviest weight, Est. 1RM or best set volume,
   **Then** a PR badge shows.
5. **Given** the History tab of an exercise, **Then** sessions are listed newest first with their
   sets; tapping one opens that workout.
6. **Given** the plan card, **When** the user taps Edit, **Then** they can change base weight, reps,
   sets, increment and rest time.

---

### User Story 5 - Home overview and exercise library (Priority: P3)

The Train tab shows the date, a Start/Continue hero card, tiles for This week, Week streak and Total
workouts, and the three most recent workouts. The exercise picker offers a built-in library of 16
exercises grouped by muscle group, search, and creating a custom exercise.

**Why this priority**: Improves orientation and flexibility; basic logging works with the seeded
library alone.

**Independent Test**: Log workouts in ISO weeks 2026-W52, 2026-W53 and 2027-W01; the streak shows 3.
Search "row", see Seated Cable Row and Dumbbell Row; create "Hack Squat" and add it to a workout.

**Acceptance Scenarios**:

1. **Given** workouts in consecutive ISO weeks ending this or last week, **Then** Week streak counts
   them, the in-progress current week does not break it, and it works across year boundaries.
2. **Given** the picker, **When** the user types a name that does not exist, **Then** they can create
   a custom exercise with name, per-hand flag and increment; names are unique case-insensitively.

---

### Edge Cases

- Logging the same set number twice overwrites it; there are never duplicate set numbers.
- Extra sets added beyond the plan are logged and count toward volume but never affect progression.
- The overload set logged at or below base weight → no progression (`overload_not_heavier`).
- Working sets hit at a lighter weight than base → no progression (`missed_reps`).
- Overload set heavier than prescribed (+5 instead of +2.5) → next base is the weight actually lifted.
- Exercises without a plan are logged but never progressed.
- Weights accumulate float error (`0.1 + 0.2 + 22.2`) → always rounded to the nearest 0.25 kg.
- Per-hand exercises count volume ×2.
- Legacy workouts without a plan snapshot are re-evaluated with the current plan, only if latest.
- Steppers never go below 0; plans with fewer than 2 sets, reps < 1, increment ≤ 0 or negative
  base are rejected.
- Exercise detail with exactly 1 session (no "previous"), 2 sessions, and more than 20 sessions.
- Corrupt or unexpected stored data shows a short error message instead of crashing.
- Android back gesture closes bottom sheets and navigates back correctly everywhere.

## Requirements *(mandatory)*

### Functional Requirements

**Progression**

- **FR-001**: For a plan `{base, reps, sets = N, increment}` the system MUST prescribe sets 1..N−1 at
  base and set N (overload) at base + increment, rounding all weights to the nearest 0.25 kg.
- **FR-002**: The system MUST reject plans with sets < 2, reps < 1, increment ≤ 0 or base < 0.
- **FR-003**: On finish, the system MUST evaluate each planned exercise in this order: any working set
  missing → `incomplete`; any working set below target reps or below base weight → `missed_reps`;
  overload set missing → `no_overload_set`; overload weight ≤ base → `overload_not_heavier`;
  otherwise `progressed`, with next base = the weight actually lifted on the overload set. Reps on the
  overload set do not matter; evaluation is independent of logging order.
- **FR-004**: Finishing MUST be atomic: store a snapshot of the plan used and the resulting base on
  each workout exercise, and raise the current base only if it still equals the snapshot's base.
- **FR-005**: A resumed workout MUST be re-evaluated against its original snapshot plan.
- **FR-006**: The system MUST show a finish summary per exercise (`⬆ X: 20 kg → 22.5 kg` or
  `• X: stays at 50 kg`).

**Live workout**

- **FR-007**: At most one workout MAY be in progress; the home tab MUST offer Start or Continue.
- **FR-008**: The workout header MUST show live elapsed duration, volume and completed set count.
- **FR-009**: Each exercise card MUST show the name, plan summary (e.g. `3 × 10 @ 20 kg · overload
  +2.5 · per hand`), a menu with Remove exercise (confirmed) and Edit plan, and optional notes.
- **FR-010**: The set table MUST show SET (number or ↑), PREVIOUS (same set number from the previous
  session, or `—`), KG, REPS and a check box; unlogged rows dimmed, logged rows highlighted, missed
  reps in red, overload row visually marked.
- **FR-011**: Tapping the check box MUST log the set as prescribed in one tap; tapping the row MUST
  open a bottom-sheet editor with weight/reps steppers, Log/Update and Clear set.
- **FR-012**: Users MUST be able to add extra set rows and add exercises from a picker.
- **FR-013**: After the first logged set, each exercise MUST show a "compared to previous" card (Sets,
  Reps, Volume, Top weight with ▲/▼/– and % change), or "First session".
- **FR-014**: Every logged set MUST be saved immediately and survive the app being killed.

**Rest timer & settings**

- **FR-015**: Each logged set MUST start a rest countdown in a fixed footer pill, from the exercise's
  rest time if set, else the global default (60 s initially); logging another set restarts it;
  tapping dismisses it.
- **FR-016**: At zero the timer MUST give a haptic pulse (and sound if enabled) and then show
  overtime counting up in a muted style; time is computed from a stored start time so it stays
  correct after backgrounding.
- **FR-017**: A Settings screen (gear icon on the Train tab) MUST let users set the default rest time
  (5 s steps, 10 s–10 min, presets 30/60/90/120/180 s) and SHOULD offer haptic and sound toggles
  (both on by default). Settings persist across restarts.
- **FR-018**: Plan setup and Edit plan MUST offer a per-exercise rest time: Default or a custom value.
- **FR-019**: A system notification when the rest timer ends while the app is in the background is
  SHOULD.

**History**

- **FR-020**: History MUST list finished workouts grouped by month with date, exercise names, total
  volume, set count and duration; opening one shows the workout in edit mode with auto-save and Done,
  Resume (when allowed) and Delete (confirmed).
- **FR-021**: Edits to a finished workout MUST re-evaluate progression against the snapshot plan,
  update its stored result, and rewrite the current base only when the workout is the latest session
  for that exercise AND the current base equals its stored result.
- **FR-022**: Resume MUST be allowed only for the most recent finished workout and only when no other
  workout is in progress; it undoes that workout's progression when safe.
- **FR-023**: Delete MUST undo progression when safe, then remove the workout and all its data.

**Progress & home**

- **FR-024**: The Progress tab MUST show workouts per ISO week (last 8 weeks, current highlighted) and
  trained exercises (most recent first) with current base weight.
- **FR-025**: Exercise detail MUST provide Summary (tiles: Current base, Heaviest set, Est. 1RM,
  Sessions; chart of the last 20 sessions with Working weight / Volume / Est. 1RM; PR badge; compared
  to previous; plan card with Edit) and History (sessions newest first, tap to open).
- **FR-026**: Est. 1RM MUST use Epley `w × (1 + reps/30)` rounded to 0.1 (1 rep → w, 0 reps → 0);
  volume MUST be Σ weight × reps, ×2 for per-hand exercises; working weight = heaviest non-overload
  set of the session; a PR is strictly greater than all prior history.
- **FR-027**: The Train tab MUST show date, Start/Continue hero, This week, Week streak (consecutive
  Monday-start ISO weeks with ≥ 1 workout ending this or last week, correct across year boundaries
  including ISO week 53) and Total workouts, plus the 3 most recent workouts.

**Library**

- **FR-028**: The app MUST ship the 16-exercise seed library from PRD §5.1 with fixed ids; seeding is
  idempotent and refreshes names, groups and increments on every start.
- **FR-029**: The picker MUST support search, grouping by muscle group, and creating custom exercises
  (name unique case-insensitively, per-hand flag, increment).

**Quality, look & platform**

- **FR-030**: All features MUST work fully offline.
- **FR-031**: The UI MUST be always-dark with one accent color, fixed metric colors, a subtle
  non-interactive backdrop, haptics (tick, success, warning), portrait only, 48 dp minimum targets,
  and screen-reader labels on every interactive control.
- **FR-032**: Destructive actions MUST ask for confirmation; the Android back gesture MUST behave
  correctly and close bottom sheets.
- **FR-033**: The app MUST NOT include social features, warm-up or other set types, light theme,
  analytics/trackers, videos, AI workouts, ads, or account sign-in in v1.

### Key Entities

- **Exercise**: a movement (library or custom); name, muscle group, per-hand flag, default increment.
- **Exercise plan (state)**: per exercise; base weight, target reps, target sets (≥ 2), increment,
  optional rest time.
- **Workout**: a training session; start time, end time (empty while in progress), optional notes.
- **Workout exercise**: an exercise within a workout, in order; notes; snapshot of the plan used and
  the resulting base weight.
- **Set**: one logged set; set number (unique per workout exercise), weight, reps, overload flag,
  completion time.
- **Setting**: a local key/value preference (e.g. default rest seconds, alert toggles).
- **Pending delete**: a record of a deletion, kept for future cloud sync.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A set performed as prescribed is logged with exactly 1 tap, and the screen reflects it
  in under 100 ms.
- **SC-002**: The app opens from cold in under 2 seconds on a mid-range Android phone.
- **SC-003**: 100% of the worked scenarios in PRD section 11 produce the expected base weight, both in
  automated tests and when performed through the UI.
- **SC-004**: 0 logged sets are lost when the app is force-closed mid-workout (verified on device).
- **SC-005**: 100% of v1 features are usable in airplane mode.
- **SC-006**: No row in the set list moves when the rest timer appears or disappears.
- **SC-007**: The rest timer is within ±1 s of wall-clock time after 5 minutes in the background.
- **SC-008**: The owner completes a full real gym workout on their phone using the installed release
  APK without needing to type anything except custom values.
- **SC-009**: Every interactive control is announced meaningfully by the screen reader.

## Assumptions

- Single user per device; no sign-in in v1. Cloud backup/restore (Phase 2) is designed for but not
  built.
- Units are kilograms only; a kg/lb setting is a later feature.
- Android is the first target (sideloaded APK); iOS comes later and is not verified in v1.
- The PRD (`docs/PRD-fitapp-flutter.md`, v2.1) is authoritative for any detail not repeated here,
  including design tokens (§2.2), seed library (§5.1), data model (§7), test plan (§12) and
  milestones (§13).
- The app icon is a simple placeholder (black background, green mark) until artwork is designed.
- Hevy is a structural reference only; no branding, copy, icons or exact layouts are copied.
