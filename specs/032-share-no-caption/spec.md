# Feature Specification: No Caption on Any Share

**Feature Branch**: `032-share-no-caption`

**Created**: 2026-11-21

**Status**: Implemented

**Input**: Owner (2026-11-21, after testing 0.0.25): remove the predefined text sent with a share
from **all** session types, not only gym workouts; the owner adds their own text if wanted.

## Findings before the change

- Feature 030 dropped the caption for gym shares only. Activity shares still sent
  `<title> · <stat> · <stat>` (e.g. `Running · 10 km · 5:00 /km`) with the image.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Image only (Priority: P1)

1. **Given** any session (gym, running, cycling, snowboarding, functional, pilates; GPS or
   manual), **When** Share image is tapped, **Then** the share sheet receives the PNG only, with
   no pre-filled text.

## Requirements *(mandatory)*

- **FR-001**: No share sends text. The sharer interface takes no text, so none can be added by
  mistake; the caption helpers are removed.

## Success Criteria *(mandatory)*

- **SC-001**: In WhatsApp/Messages the shared item arrives as an image with an empty message box,
  for every session type.

## Assumptions

- The file name (`fitapp-<type>-<date>.png`) stays; it is not message text.
