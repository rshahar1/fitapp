# Feature Specification: Share Capture Fix

**Feature Branch**: `030-share-capture-fix`

**Created**: 2026-11-21

**Status**: Implemented

**Input**: Owner report (2026-11-21) on 0.0.24: (1) sharing a gym workout for the first time
often sends a blank/white image; other trainings seem fine. (2) Do not send extra caption text
(title, duration, …) with a shared gym workout; the owner adds their own text if wanted.

## Findings before the change

- The preview watched the session through `watchQuery`, which reloads after **any** write to
  **any** table. Right after finishing a gym workout, cloud sync clears `dirty` on the workout,
  its exercises, sets and plans and applies pulled rows, so the gym card was rebuilt many times in
  the first seconds. Each rebuild produced new card data and a repaint of the captured boundary.
- The capture (`RenderRepaintBoundary.toImage`) ran straight from the tap without waiting for
  a painted frame and without checking the result. A capture that lands between a rebuild and
  its paint can come back empty (fully transparent), which chat apps show as white.
- Activities are single rows with little sync churn, so they rarely hit the race.
- The gym share sent the caption `<title> · <duration> · <sets>` along with the image.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - The shared image is never blank (Priority: P1)

1. **Given** a gym workout that was just finished (sync still writing), **When** Share image is
   tapped, **Then** the shared PNG shows the card, never a blank or white image.
2. **Given** the database keeps changing while the preview is open, **Then** the preview card
   does not flicker or rebuild; it shows the session as it was when the preview opened.
3. **Given** a capture still comes back blank, **Then** the app waits a frame and retries (up to
   3 attempts); if it is still blank it shows "Could not share the image." and sends nothing.

### User Story 2 - No caption on gym shares (Priority: P1)

1. **Given** a gym workout share, **Then** only the image is sent, with no text.
2. Activity shares keep their short caption (unchanged).

## Requirements *(mandatory)*

- **FR-001**: The preview takes the session once (first loaded, finished value) and ignores later
  database updates.
- **FR-002**: Capture waits for the end of the current frame before reading the boundary.
- **FR-003**: A captured image whose sampled pixels are all fully transparent counts as blank;
  blank captures are retried up to 3 times, then reported as an error and never shared.
- **FR-004**: Gym workout shares send no text.

## Success Criteria *(mandatory)*

- **SC-001**: No blank image is ever handed to the share sheet (a blank result is caught).
- **SC-002**: Gym shares arrive in the target app with no pre-filled text.

## Assumptions

- The race could not be reproduced on a device from here; the fix removes the rebuild churn,
  waits for a painted frame and verifies the pixels, so all known paths to a blank image are closed.
