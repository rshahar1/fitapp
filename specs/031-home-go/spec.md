# Feature Specification: Home & Go

**Feature Branch**: `031-home-go`

**Created**: 2026-11-21

**Status**: Implemented

**Input**: Owner request (21 Nov 2026): (1) move the template START action off the Train page into
the sheet opened by the centre "+" button, next to the other training modes; (2) rename the Train
tab/screen to **Home**; (3) rename the "+" button to **Go**. Owner confirmed (same day): the
in-progress card with Continue stays on Home, and the Templates section is removed from Home.

## Findings before the change

- Bottom bar: `Train · History · [+] · Progress · You`; "+" is an accent circle with a plus icon,
  tooltip/label "Start or log a session"; it opens the sheet titled "Start or log".
- Train shows the in-progress hero (Continue), a Templates section (one card per template with a
  START pill, or an empty hint), steps, stat tiles, By type and Recent.
- Gym workouts start only from a template (feature 024).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Start a gym template from Go (Priority: P1)

1. **Given** templates exist, **When** the user taps **Go**, **Then** the sheet (titled "Go")
   lists under *Start now*, after the Continue row (when a session runs), one row per template
   with its name, exercise summary and the gym icon.
2. **When** the user taps a template row, **Then** the sheet closes and a live workout starts from
   that template (same as the old START).
3. **Given** a session is in progress, **When** a template row is tapped, **Then** the start is
   refused with the existing in-progress message and its Open action.
4. **Given** no templates, **Then** the sheet shows one row "Create a gym template" that opens
   You → Gym Templates.
5. GPS rows, log-for-today rows and the *Earlier* group are unchanged.

### User Story 2 - Home replaces Train (Priority: P1)

1. The first tab and the screen title read **Home**; the "Back to Train" buttons read
   "Back to Home"; user-visible texts naming the Train screen name Home.
2. Home keeps the in-progress card with Continue, steps, stat tiles, By type and Recent.
3. Home has no Templates section, no template cards, no START buttons and no template hint.

### User Story 3 - Go button (Priority: P1)

1. The centre button shows a play icon in the accent circle, a small "Go" caption, and its
   tooltip and accessibility label are "Go". Its tap target stays at least 48 dp and it is still
   never a selected tab.

### Edge Cases

- Many templates: the sheet scrolls; all rows reachable.
- Template with no exercises: the summary line is empty or omitted; the row still starts it.
- The share-card slogan "Train · Track · Progress" is branding and stays.

## Requirements *(mandatory)*

- **FR-001**: The Go sheet lists every gym template as a start row, starting through the shared
  start guard.
- **FR-002**: With no templates, the Go sheet offers "Create a gym template" → Gym Templates.
- **FR-003**: The Home screen has no Templates section.
- **FR-004**: Tab label, screen title, back buttons and user-visible references say Home.
- **FR-005**: The centre button is labelled "Go" (tooltip, accessibility, caption) with a play
  icon; the sheet is titled "Go".

## Success Criteria *(mandatory)*

- **SC-001**: A gym template can be started in two taps from any tab (Go → template).
- **SC-002**: No visible text in the app names the "Train" screen (slogan excepted).
- **SC-003**: Every existing start path (GPS, log for today, log a past session, continue) still
  works unchanged.

## Assumptions

- Internal names (`TrainScreen`, `lib/features/train/`, route `/train`) stay to limit churn.
- The Continue row stays in the Go sheet as well as on Home.
