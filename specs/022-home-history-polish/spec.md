# Feature Specification: Home and History Polish

**Feature Branch**: `022-home-history-polish`

**Created**: 2026-11-20

**Status**: Implemented (device check open)

**Input**: Owner request, four items: (1) the "Continue workout" button is green like "Start gym
workout", so a running session is easy to miss; (2) the functional-training icon looks like karate;
(3) the History calendar starts weeks on Monday, should be Sunday; (4) tapping the daily steps card
on Train should open History in Calendar view.

## Clarifications

### Session 2026-11-20

- Q: Live style? → A: Amber (#FF9F0A, already in the palette as the weight metric colour) fill with
  black text and a play icon on the Continue button, amber card border and a small "● LIVE" pill.
  The Start button stays green. Applies to any session in progress (gym and GPS).
- Q: Functional icon? → A: The 🏋️ emoji (person lifting weights, gender-neutral), shown in colour,
  wherever activity-type icons appear. Other types keep their icons.
- Q: Sunday start scope? → A: History calendar view only (grid and weekday header). Weekly stats
  keep ISO (Monday) weeks.
- Q: Which steps state is tappable? → A: Only when steps are shown. The Connect / Get Health Connect
  prompts keep their own buttons.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - See that a session is running (Priority: P1)

Back on Train with a workout in progress, the card reads as live (amber border, LIVE pill, amber
Continue button) and cannot be mistaken for the green Start action.

**Independent Test**: Start a gym workout, go back to Train: the button is amber with a play icon.

**Acceptance Scenarios**:

1. **Given** no session, **Then** the button reads "Start gym workout" in green with no LIVE pill.
2. **Given** a gym or GPS session in progress, **Then** the card shows an amber border, a LIVE pill
   and an amber "Continue …" button with a play icon.

### User Story 2 - Recognisable functional training (Priority: P2)

**Acceptance Scenarios**:

1. **Given** functional training in the start hub, activity sheet, History list or calendar,
   **Then** it shows 🏋️.

### User Story 3 - Calendar weeks start on Sunday (Priority: P2)

**Acceptance Scenarios**:

1. **Given** the History calendar, **Then** the header reads Sun … Sat and each row runs Sunday to
   Saturday, including days outside the month.

### User Story 4 - Steps card opens the calendar (Priority: P2)

**Acceptance Scenarios**:

1. **Given** steps are shown on Train, **When** the card is tapped, **Then** the History tab opens
   in Calendar view.

## Requirements

- **FR-001**: A session in progress is styled with a distinct "live" colour on the Train card;
  starting stays the green primary style.
- **FR-002**: Functional training shows the 🏋️ emoji everywhere activity icons appear, with the same
  accessible labels as before.
- **FR-003**: History calendar weeks start on Sunday; stats weeks are unchanged.
- **FR-004**: The steps card (steps shown) is a button that opens History in Calendar view; it is
  announced as a button to screen readers.
- **FR-005**: Domain stays pure Dart; calendar tests are written first.

## Edge Cases

- A month whose 1st is a Sunday starts its grid on the 1st; a month ending on Saturday has no
  trailing days.
- Emoji rendering depends on the device font; Android ships a colour emoji font.
- If History is already showing List view, tapping steps switches it to Calendar.

## Success Criteria

- **SC-001**: A running session is identifiable at a glance from colour alone (amber vs green).
- **SC-002**: Calendar grids for all 12 months of 2026 start on Sunday and contain every day of the
  month.
- **SC-003**: One tap from Train reaches the History calendar.
- **SC-004**: Format, analyze and all tests clean.

## Assumptions

- Amber is not used for errors in this app (danger is red), so it does not read as a warning.
