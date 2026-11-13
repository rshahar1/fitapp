# Feature Specification: Log Other Sport Activities

**Feature Branch**: `006-sport-activities`

**Created**: 2026-11-13

**Status**: Draft

**Input**: User description: "A lightweight way to log additional sport activities so they're
recorded in the overall activity history. Initial activities: Functional training, Cycling,
Snowboarding, Running. Keep it simple: no sport-specific tracking modules, metrics or custom flows;
just select/log one so it's saved in history. Structure it so more sports or deeper sport-specific
features are easy to add later."

## Clarifications

### Session 2026-11-13

- Q: Where is an activity logged? → A: A **Log activity** action on the Train tab opens a short
  sheet: type, date (today by default), optional duration, optional note.
- Q: Can activities be changed later? → A: **Yes**: tap one in History to edit it or delete it
  (delete asks to confirm).
- Q: Do activities count in stats? → A: They count toward **This week**, **Week streak** and the
  **Progress weekly bars**. **Total workouts** stays gym workouts only.
- Q: How are they shown? → A: History lists workouts and activities together by month, with a
  **distinct icon per type, including a gym icon for workouts** (owner's addition).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Log an activity (Priority: P1)

After a snowboarding day the lifter opens the Train tab, taps Log activity, picks Snowboarding,
leaves the date as today, sets 180 minutes and saves. It appears in History with a snowboard icon.

**Why this priority**: This is the feature.

**Independent Test**: Log "Running, today, 30 min, 'easy 5k'": History shows it at the top of this
month with the running icon, "Running" and "30 min · easy 5k".

**Acceptance Scenarios**:

1. **Given** the Train tab, **When** the user taps Log activity, **Then** a sheet opens with the
   four types, the date (today), an optional duration and an optional note.
2. **Given** a type is chosen, **When** Save is tapped, **Then** the activity is stored and the
   sheet closes; no type chosen → Save is disabled.
3. **Given** the date is changed to an earlier day, **Then** the activity is stored on that day.
   Future dates cannot be chosen.
4. **Given** no duration and no note, **Then** saving still works.
5. **Given** a workout is in progress, **Then** logging an activity still works and does not
   affect the workout.

---

### User Story 2 - See activities in History and stats (Priority: P1)

History shows gym workouts and activities together, newest first, grouped by month. Each row starts
with an icon: a dumbbell for gym workouts, and one icon per sport. Activities count toward This
week, Week streak and the weekly bars on Progress.

**Why this priority**: The owner wants a complete record of their training.

**Independent Test**: With one workout on Monday and a cycling activity on Wednesday of this week,
History lists both with different icons; This week = 2; Total workouts = 1; the current week's bar
on Progress = 2.

**Acceptance Scenarios**:

1. **Given** workouts and activities, **Then** History lists them together by date, newest first,
   grouped by month, each with its type's icon (gym icon for workouts).
2. **Given** an activity this week, **Then** This week and the current week's Progress bar include
   it; Total workouts does not.
3. **Given** the only training of last week was an activity, **Then** the week streak counts that
   week.
4. **Given** only activities and no workouts, **Then** History is not empty.

---

### User Story 3 - Edit or delete an activity (Priority: P2)

The lifter logged Running by mistake instead of Cycling; they tap it in History, change the type and
save. Another entry was a duplicate; they delete it after confirming.

**Why this priority**: Mistakes happen; history must be correctable.

**Independent Test**: Edit an activity's type, date, duration and note; reopen it to see the new
values. Delete one: after confirming it disappears from History and stats.

**Acceptance Scenarios**:

1. **Given** an activity in History, **When** tapped, **Then** the same sheet opens pre-filled
   with Save and Delete.
2. **Given** Delete, **Then** a confirmation is required; cancelling keeps the activity.
3. **Given** a deletion, **Then** it is removed from History and stats immediately.

### Edge Cases

- **Unknown type** (an id from a newer version or one that was removed later): shown with a generic
  icon and the label "Activity"; still editable and deletable.
- **Duration**: whole minutes, 1–1440; empty means not recorded.
- **Note**: trimmed; empty → none; at most 200 characters.
- **Several activities on one day**: all are listed; each counts toward This week.
- **Same week as a workout**: the streak counts the week once.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The app MUST offer the activity types Functional training, Cycling, Snowboarding and
  Running from one central list, each with a stable id, label and icon, so new types can be added
  by adding one entry.
- **FR-002**: Users MUST be able to log an activity with a type (required), a date (default today,
  not in the future), an optional duration in minutes and an optional note.
- **FR-003**: Activities MUST be stored on the device, work offline, and be ready for later sync
  like other records.
- **FR-004**: History MUST list workouts and activities together, newest first, grouped by month,
  with a distinct icon per type and a gym icon for workouts.
- **FR-005**: Users MUST be able to edit and delete (with confirmation) an activity from History.
- **FR-006**: Activities MUST count toward This week, Week streak and the Progress weekly bars, and
  MUST NOT count toward Total workouts, volume, exercise statistics or progression.
- **FR-007**: The data upgrade MUST preserve all existing data.

### Key Entities

- **Activity type**: stable id, label, icon (defined in the app, not stored).
- **Activity**: type id, date and time, optional duration (minutes), optional note, last-updated
  time and sync flag.

## Success Criteria *(mandatory)*

- **SC-001**: Logging an activity with defaults takes at most 3 taps from the Train tab (Log
  activity → type → Save).
- **SC-002**: 100% of logged activities appear in History with the correct icon and date.
- **SC-003**: Week count and streak include activities exactly as specified (automated tests).
- **SC-004**: After the update, all existing workouts, templates and plans are unchanged.

## Assumptions

- No sport-specific metrics (distance, pace, heart rate) — out of scope; the structure allows adding
  them later.
- The Train tab's Recent list stays gym workouts only; History is the overall record.
- The time of an activity is the time it was logged (today) or the current time of day on the chosen
  date; only the date is shown.
