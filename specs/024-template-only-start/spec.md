# Feature Specification: Template-Only Gym Start

**Feature Branch**: `024-template-only-start`

**Created**: 2026-11-20

**Status**: Implemented

**Input**: Owner request: "please remove the 'start gym workout', it's no longer needed, i only need
the option to start gym workouts from templates."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Gym workouts start from a template (Priority: P1)

The user always trains from a routine. The Train tab no longer offers an empty "Start gym workout";
each template's START is the only way to begin a gym workout.

**Independent Test**: Open Train with nothing in progress: no "Start gym workout" button and no
"Ready to train?" card. Tap a template's START: the workout opens with that template's exercises.

**Acceptance Scenarios**:

1. **Given** no session in progress, **When** Train is shown, **Then** there is no "Start gym
   workout" button and no "Ready to train?" card; the Templates section comes right after the title.
2. **Given** at least one template, **When** its START is tapped, **Then** a gym workout starts from
   that template and opens.
3. **Given** no templates, **Then** Train shows the existing hint to create a template and its
   **New** action.
4. **Given** a gym workout in progress, **Then** the in-progress card still shows **Continue
   workout**.
5. **Given** a GPS session in progress, **Then** the in-progress card still shows **Continue
   <sport>**, and template START is refused with the existing message.

### Edge Cases

- A workout in progress that was started empty before this change still continues, finishes and
  shows in History as before.
- Adding exercises inside a template workout keeps working.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The app MUST NOT offer a way to start an empty gym workout.
- **FR-002**: A template's START MUST stay the way to start a gym workout (same guard as today).
- **FR-003**: The in-progress card on Train MUST show only while a gym workout or GPS session is in
  progress, with its Continue action.

## Success Criteria *(mandatory)*

- **SC-001**: With nothing in progress, Train shows zero "Start gym workout" controls.
- **SC-002**: Every gym workout started after this change is linked to a template.
- **SC-003**: Continuing a session in progress still takes one tap from Train.

## Assumptions

- With nothing in progress the card would have no action, so it is hidden rather than shown empty.
- The start hub (Start or log sheet) has no gym start today and is unchanged.
- Stored data, History, editing and resuming finished workouts are unchanged.
