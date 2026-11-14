# Feature Specification: Workout Flow Fixes, Exercise Library and History Calendar

**Feature Branch**: `007-workout-flow-library`

**Created**: 2026-11-13

**Status**: Draft

**Input**: User description: "UI/UX improvements: (1) resume a finished activity marked done by
mistake; (2) cancel/discard a running workout directly, protected by an 'are you sure' prompt,
instead of save-then-delete; (3) browse all exercises before a workout starts, and add and edit
exercises from a central management view; (4) assign a custom exercise to an existing category
(chest, legs, back, ...) with 'custom' as an additional option, not the only one; (5) a date
picker when logging a workout so past sessions (gym, cycling, snowboarding, ...) get the correct
date; (6) a History calendar view to navigate months and years, showing the training icon on each
day with a session."

## Clarifications

### Session 2026-11-13 (decided by the orchestrator from the request and the codebase)

- Q: Which "activities" can be resumed? → A: **Gym workouts.** Sport activities are logged in one
  step (no running state) and are already editable from History, so "resume" has no meaning there.
- Q: Which finished workout can be resumed? → A: **Any finished workout**, as long as no other
  workout is in progress (previously only the most recent one, and the button was only on the
  History detail screen). It is also offered directly on the finish summary.
- Q: How long is a resumed workout? → A: Its **earlier duration plus the time spent after
  resuming**; the days in between never count.
- Q: Discarding a resumed workout? → A: Allowed, with a stronger warning: it deletes the whole
  workout, including the sets logged before it was resumed.
- Q: Which date picker for past sessions? → A: Sport activities already have one (feature 006).
  Gym workouts get a **Date** row on the workout screen, both while training and when editing a
  finished workout. The time of day is kept; the duration is kept.
- Q: Can a past session change today's working weights? → A: **Only if it is the newest session**
  for that plan. A backdated session older than an existing one is recorded but never rewrites a
  base weight (constitution principle II).
- Q: Which categories exist? → A: The built-in groups **Chest, Back, Legs, Shoulders, Arms**, plus
  **Custom** (no group). No new groups in this feature.
- Q: Can built-in exercises be edited? → A: **No**; they can be viewed. Only custom exercises can
  be renamed, re-categorised and have per-hand / increment changed. Deleting exercises is out of
  scope.
- Q: Calendar layout? → A: The History tab gets a **List / Calendar** switch. The calendar has
  **Month** and **Week** modes, arrows to move, a month/year jump picker and a Today shortcut.
  Each day with training shows the icon of its first session (gym or sport) and a "+N" count when
  there are more. Tapping a day lists its sessions below.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Resume a workout finished by mistake (Priority: P1)

The lifter taps Finish too early. The summary sheet offers **Resume workout**; tapping it reopens
the live workout with all sets intact, and any working-weight increase from that finish is undone
until it is finished again.

**Why this priority**: Finishing by mistake currently has no obvious fix and corrupts progression.

**Independent Test**: Finish a workout that raised the bench base from 60 to 62.5; tap Resume on
the summary → the live workout shows the same sets, bench base is 60 again; finish again → 62.5.

**Acceptance Scenarios**:

1. **Given** the finish summary, **When** the user taps Resume workout, **Then** the workout
   becomes the live workout again with the same exercises and sets.
2. **Given** a finished workout opened from History and no workout in progress, **Then** a Resume
   action is available, also for workouts that are not the most recent.
3. **Given** a workout in progress, **Then** no other workout can be resumed.
4. **Given** a workout that lasted 50 min is resumed two days later and trained 10 more minutes,
   **Then** after finishing it shows 60 min and keeps its original date.
5. **Given** resuming an older workout, **Then** base weights set by newer sessions are not
   changed by the resume or by finishing it again.

---

### User Story 2 - Discard a running workout (Priority: P1)

The lifter started a workout by accident. From the workout screen's menu they choose **Discard
workout**, confirm "Discard workout?", and the workout is gone without appearing in History.

**Why this priority**: Save-then-delete is slow and pollutes stats and progression.

**Independent Test**: Start a workout, log 2 sets, Discard → confirm → back on Train with no
workout in progress; History unchanged; base weights unchanged.

**Acceptance Scenarios**:

1. **Given** a live workout (with or without sets), **When** the user picks Discard workout,
   **Then** a confirmation dialog appears; Cancel keeps everything.
2. **Given** the user confirms, **Then** the workout, its sets and its rest timer are removed and
   the Train tab shows "Ready to train?".
3. **Given** the live workout was resumed from History, **Then** the dialog warns that the whole
   workout including earlier sets will be deleted.

---

### User Story 3 - Exercise library outside a workout (Priority: P1)

From the Train tab (and the Progress tab) the lifter opens **Exercises**: every exercise grouped by
category with search. They can open any exercise to see its plan and history, create a new
exercise, and edit custom exercises - all without starting a workout.

**Why this priority**: Planning happens before the gym; the library was only reachable mid-workout.

**Independent Test**: With no workout in progress, open Exercises, create "Hip Thrust" in Legs,
edit it to per hand, tap it → the exercise detail opens. Start a workout → Add Exercise lists Hip
Thrust under Legs.

**Acceptance Scenarios**:

1. **Given** no workout, **When** the user opens Exercises, **Then** all exercises are listed by
   category (Chest, Back, Legs, Shoulders, Arms, then Custom), with search by name.
2. **Given** an exercise row, **When** tapped, **Then** its detail (plan, history) opens.
3. **Given** the New action, **Then** the create sheet opens; the new exercise appears in its
   category immediately.
4. **Given** a custom exercise, **Then** an edit action opens the same sheet pre-filled; saving
   updates name, category, per hand and increment. Built-in exercises have no edit action.
5. **Given** a new or edited name equal to another exercise (ignoring case), **Then** an inline
   error shows and nothing is saved.

---

### User Story 4 - Category for custom exercises (Priority: P2)

When creating or editing a custom exercise, the lifter picks its category: Chest, Back, Legs,
Shoulders, Arms or Custom (default Custom).

**Independent Test**: Create "Cable Crunch" as Custom and "Pec Deck" as Chest; the picker and the
library show Pec Deck under Chest and Cable Crunch under Custom.

**Acceptance Scenarios**:

1. **Given** the create sheet, **Then** a category selector is shown with Custom pre-selected.
2. **Given** a category is chosen, **Then** the exercise is listed under that category everywhere.

---

### User Story 5 - Log a past gym session (Priority: P2)

Back home, the lifter logs yesterday's gym session: they start a workout, tap the **Date** row,
pick yesterday, log the sets and finish. It appears in History on yesterday's date. Past sport
activities keep using the date picker of the Log activity sheet.

**Independent Test**: With a bench session on 10 Nov raising the base to 62.5, log a backdated
session on 8 Nov meeting all targets → History shows it on 8 Nov, bench base stays 62.5.

**Acceptance Scenarios**:

1. **Given** a live workout, **Then** a Date row shows "Today"; tapping it opens a date picker
   limited to the past 5 years up to today.
2. **Given** an earlier day is chosen and the workout is finished, **Then** it is stored on that
   day at the same time of day, with the real training duration.
3. **Given** a finished workout in edit mode, **Then** the Date row can move it to another day;
   duration and sets are kept and no base weight changes.
4. **Given** the backdated session is the newest session for a plan, **Then** finishing it may
   progress that plan as usual; otherwise no base weight changes.
5. **Given** a past date was picked, **Then** History, stats, streaks and weekly bars use that date.

---

### User Story 6 - History calendar (Priority: P2)

On History the lifter switches to **Calendar**. A month grid shows each training day with the
session's icon (dumbbell for gym, the sport's icon otherwise). Arrows move by month (or by week in
Week mode); tapping the month title jumps to any month and year; Today returns to the present.
Tapping a day lists that day's sessions, which open as from the list.

**Independent Test**: With a gym workout on 3 Nov and cycling plus gym on 5 Nov, the November grid
shows a dumbbell on the 3rd and a bike with "+1" on the 5th; tapping the 5th lists both rows.

**Acceptance Scenarios**:

1. **Given** History, **Then** a List / Calendar switch is visible; List is the existing view.
2. **Given** Calendar, **Then** the current month is shown, weeks start on Monday, today is
   highlighted and today is selected.
3. **Given** a day with sessions, **Then** it shows the first session's icon and "+N" for more.
4. **Given** the arrows or the month/year picker, **Then** the calendar moves accordingly; a Today
   action returns to the current month/week.
5. **Given** Week mode, **Then** one Monday-Sunday row is shown and the arrows move by one week.
6. **Given** a day is tapped, **Then** its sessions are listed below the calendar (or "No training"),
   and tapping one opens the workout or the activity sheet.

### Edge Cases

- App killed during a resumed or backdated live workout: the earlier duration and the chosen date
  survive a restart.
- A live workout from before this feature (no live-session record): finishing stores the current
  time as before; Discard and Date still work.
- Discarding with no sets: same confirmation, same result.
- Finishing a backdated workout with no sets: still discarded, as today.
- Picking today as the date on a live workout clears any earlier pick.
- Renaming a custom exercise to its own name with different case is allowed.
- Days with many sessions show at most one icon and a "+N" badge; the grid never overflows.
- A month without training shows an empty grid and "No training" for the selected day.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Any finished workout MUST be resumable while no workout is in progress; Resume MUST be
  offered on the finish summary and on the finished-workout screen.
- **FR-002**: Resuming MUST undo that workout's progression only where it is still the current base
  of the newest session for the plan (existing safety rule).
- **FR-003**: A resumed workout's duration MUST be its earlier duration plus live time after
  resuming; its date MUST stay unchanged unless the user changes it.
- **FR-004**: The live workout screen MUST offer Discard workout behind a confirmation dialog;
  confirming deletes the workout and its sets, clears the rest timer and returns to Train.
- **FR-005**: An Exercises screen MUST be reachable without a workout (Train and Progress tabs),
  listing all exercises by category with search, opening exercise detail on tap.
- **FR-006**: Users MUST be able to create exercises from the Exercises screen and edit custom
  exercises (name, category, per hand, increment); built-in exercises are read-only.
- **FR-007**: Exercise names MUST stay unique ignoring case, on create and on edit.
- **FR-008**: Create and edit MUST offer the categories Chest, Back, Legs, Shoulders, Arms and
  Custom (default).
- **FR-009**: The workout screen (live and finished) MUST show a Date row that changes the workout's
  day (past 5 years up to today), keeping time of day and duration.
- **FR-010**: Finishing, editing or resuming a workout MUST rewrite a plan's base weight only when
  the workout is the newest finished session for that plan.
- **FR-011**: History MUST offer a Calendar view with Month and Week modes, previous/next
  navigation, a month/year picker and a Today action; weeks start on Monday.
- **FR-012**: Calendar days MUST show the icon of the first session of the day (gym or sport type)
  and "+N" for additional sessions; tapping a day lists its sessions, which open as in the list.
- **FR-013**: All new interactive controls MUST have semantic labels and 48 dp tap targets; all
  destructive actions MUST confirm.

### Key Entities

- **Live session record**: local-only facts about the one workout in progress: when it became live,
  the duration accumulated before (for resumed workouts) and the day the user chose (if any).
- **Exercise**: gains an editable category for custom exercises (existing optional muscle group).
- **Calendar day**: a date and the sessions (workouts and activities) that started on it.

## Success Criteria *(mandatory)*

- **SC-001**: A workout finished by mistake is back in progress within 2 taps from the summary.
- **SC-002**: A running workout is discarded within 3 taps and never appears in History or stats.
- **SC-003**: Any exercise's detail is reachable from Train in 2 taps without starting a workout.
- **SC-004**: A past gym session is logged on its real date with 1 extra tap plus the date choice;
  0 base weights change when it is older than the newest session.
- **SC-005**: Any month of the last 5 years is shown in the calendar within 3 taps.
- **SC-006**: All quality gates (format, analyze, tests) stay green.

## Assumptions

- Sport activities already support past dates (feature 006); this feature does not change them.
- Week starts on Monday, matching the existing ISO-week stats.
- The live-session record is device-local, like settings; finished data stays in the synced tables.
- Out of scope: deleting exercises, new categories, editing built-in exercises, a time-of-day picker.
