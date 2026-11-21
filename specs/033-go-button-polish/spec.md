# Feature Specification: Go Button & Template Rows Polish

**Feature Branch**: `033-go-button-polish`

**Created**: 2026-11-21

**Status**: Implemented

**Input**: Owner (2026-11-21): (1) put the "Go" caption inside the play button instead of below
it; (2) in the Go sheet, a template option shows only the template, not all its exercises.

## Findings before the change

- The centre bar action was a 48 dp accent circle with a play icon and a separate "Go" caption
  under it (feature 031).
- Each template row in the Go sheet had the exercise list (`Bench · Squat · …`) as its subtitle.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Go inside the button (Priority: P1)

1. **Given** any tab, **When** the bottom bar shows, **Then** the centre accent circle contains
   the play icon with "Go" under it, both inside the circle; no caption sits below the circle.

### User Story 2 - Template rows show the template only (Priority: P1)

1. **Given** a template "Push" with exercises, **When** the Go sheet opens, **Then** the row shows
   "Push" with no exercise names; tapping it still starts the template.

## Requirements *(mandatory)*

- **FR-001**: The Go action is one accent circle (at least 48 dp, label and tooltip "Go") holding
  the play icon and the "Go" text in the on-accent colour.
- **FR-002**: Go sheet template rows have a title (template name) and no subtitle.

## Success Criteria *(mandatory)*

- **SC-001**: The "Go" text is drawn inside the circle on every tab.
- **SC-002**: No exercise name appears in the Go sheet.

## Assumptions

- The circle grows to 56 dp so icon and text fit; the 72 dp bar height is unchanged.
