# Feature Specification: Photo Backdrop

**Feature Branch**: `004-photo-backdrop`

**Created**: 2026-11-13

**Status**: Approved — photo chosen 2026-11-13

**Input**: User description: "Replace the blank black background with a blurred, darkened
background image (the owner suggested a specific gym photo, or a similar one). Keep it subtle so it
doesn't overpower the foreground UI."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A subtle gym atmosphere behind every screen (Priority: P1)

When the lifter opens FitApp, every screen shows a softly blurred, dark gym photo behind the cards
instead of flat black. Cards stay opaque and text is as readable as before; the photo only adds
atmosphere at the edges and between cards.

**Why this priority**: It is the whole feature.

**Independent Test**: Open Train, History, Progress, the live workout and Settings: each shows the
same blurred, darkened photo behind the content; all text passes the same contrast checks as
before; nothing moves when scrolling except the content.

**Acceptance Scenarios**:

1. **Given** any screen, **Then** the background is the chosen photo, blurred and darkened so that
   it reads as texture, not as a picture competing with the content.
2. **Given** cards and grouped rows, **Then** they remain fully opaque and their text contrast is
   unchanged.
3. **Given** a long scrolling list, **When** the user scrolls, **Then** the background stays fixed
   and scrolling stays smooth.
4. **Given** the accent glow and grid from the current backdrop, **Then** they are kept only if they
   still look good on top of the photo (decided during design; otherwise removed).
5. **Given** a screen reader, **Then** the background is ignored.
6. **Given** the app is opened, **Then** the background appears with the first frame (no flash of
   black or pop-in).

---

### Edge Cases

- Very tall or very wide screens: the photo covers the screen without stretching (crop, keep the
  subject roughly centered).
- Bottom navigation, app bars and the fixed workout footer stay opaque black so the photo never
  reduces the readability of controls.
- Bottom sheets and dialogs are unaffected (they keep their solid surfaces).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Every screen MUST show the same background photo, blurred and darkened, behind its
  content, fixed while content scrolls.
- **FR-002**: The darkening MUST keep the photo's brightest areas at or below ~25% luminance so all
  existing text/control contrast is unaffected; cards stay opaque.
- **FR-003**: The background MUST be shown from the first frame, work offline, and add no more than
  ~300 KB to the app.
- **FR-004**: The background MUST be excluded from accessibility semantics and not respond to touch.
- **FR-005**: The photo MUST be used under a license that permits bundling it in the app, or be the
  owner's own photo; its source and license are recorded in the repository.
- **FR-006**: The image MUST NOT show recognizable people, logos or brand names after processing.

### Key Entities

- **Background image asset**: one pre-processed (cropped, blurred, darkened) image bundled with the
  app, plus a record of its source and license.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: All primary text keeps a contrast ratio of at least 4.5:1 against its card/background.
- **SC-002**: Scrolling stays at a steady frame rate on a mid-range phone (no visible jank
  introduced).
- **SC-003**: App size grows by ≤ 300 KB.
- **SC-004**: The owner approves the look on the phone.

## Assumptions

- The image is blurred and darkened ahead of time (bundled already processed) rather than at
  runtime, for speed and consistent results.
- Photo (owner decision 2026-11-13, after reviewing previews of 6 options): Pexels photo 6389516
  "Close-up shot of a barbell" by Tima Miroshnichenko (Pexels License), "whole barbell" layout: a
  heavily blurred full-screen fill of the photo, with the full-width photo (lightly blurred) feathered
  in so the barbell sits in the open area at ~60% of screen height, a dark wash behind the header and
  a darker bottom. The owner's linked photo was previewed but not chosen.
