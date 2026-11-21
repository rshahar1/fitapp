# Feature Specification: Share First in the Finished Session ⋮ Menu

**Feature Branch**: `039-menu-share-first`

**Created**: 2026-11-21

**Status**: Implemented

**Input**: Owner (2026-11-21, after 0.0.33): the ⋮ menu of a finished workout opened from History
reads Edit, Share, Delete; change the order to Share, Edit, Delete.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Share on top (Priority: P1)

1. **Given** a finished workout opened from History, **When** the ⋮ menu opens, **Then** it lists
   Share, Edit workout, Delete workout, in that order.
2. The activity detail ⋮ menu uses the same order (Share, Edit activity, Delete activity) for
   consistency.

## Requirements

- **FR-001** Finished workout ⋮ menu order: Share, Edit workout, Delete workout.
- **FR-002** Activity detail ⋮ menu order: Share, Edit activity, Delete activity.
