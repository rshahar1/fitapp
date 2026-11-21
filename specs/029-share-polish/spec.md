# Feature Specification: Share Polish

**Feature Branch**: `029-share-polish`

**Created**: 2026-11-21

**Status**: Implemented

**Input**: Owner review of feature 027 (2026-11-21): (1) a cleaner, more native share icon, chosen
from three options; (2) move Share out of the activity/workout app bar into the `⋮` overflow menu;
(3) the gym share card must show **all** exercises, never "+N more exercises"; (4) a long duration
such as `1h 3m` looks smaller than sets and reps; keep it balanced.

## Findings before the change

- Share used `Icons.ios_share` as an app-bar icon on the activity detail and finished workout
  screens, on the finish summary and on the preview screen.
- The gym card capped the list at 7 lines (6 + "+N more exercises") on a fixed 360 × 450 canvas.
- Each stat value was shrunk on its own (`FittedBox`) to fit a quarter of the card width, so
  `1 h 14 min` was drawn much smaller than `33` sets next to it.
- Owner picked option **A** (filled Material share glyph, platform adaptive) from the three
  rendered options (A Material share, B outlined share nodes, C paper plane).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Native share icon (Priority: P1)

1. Every share control (menu item, finish summary button, preview button and empty state) uses
   the platform share glyph: Material share on Android, the iOS share glyph on iOS.

### User Story 2 - Share lives in the overflow menu (Priority: P1)

1. **Given** an activity detail screen, **Then** the app bar has no share icon; a `⋮` menu
   ("More options") holds **Share** (with the share icon), which opens the share preview.
2. **Given** a finished workout (not editing), **Then** the existing `⋮` menu holds **Share**
   next to Resume workout / Save as template; the app bar has no share icon. While editing or
   live, Share is not offered.
3. Edit and delete stay where they are.

### User Story 3 - Every exercise on the gym card (Priority: P1)

1. **Given** a workout with 10 exercises, **Then** the card lists all 10 with their set lines and
   no "+N more" line.
2. Up to 8 exercises keep the 4:5 card (1080 × 1350). More exercises make the card taller, up
   to 9:16 (1080 × 1920). If one column still does not fit, the list flows into two columns
   (name above the set line); beyond that, rows shrink so everything still fits. Nothing is ever
   clipped or hidden.
4. Other card types keep 1080 × 1350.

### User Story 4 - Balanced durations (Priority: P2)

1. Durations read `27 min`, `1h 3m`, `4h`: digits at the same size as other stat values, unit
   letters small like `km` or `kg`.
2. When a value in a stat grid does not fit its column, every value in that grid is scaled by
   the same factor, so durations, sets and reps always share one size.

### Edge Cases

- 0 exercises with sets: card shows totals only (unchanged).
- 30+ exercises: two columns with shrunken rows, all present.
- Long exercise names: one line with ellipsis (two-column rows too).

## Requirements *(mandatory)*

- **FR-001**: Share icon = platform adaptive share glyph everywhere.
- **FR-002**: Share is a menu item in the `⋮` menu of the activity detail and finished-workout
  screens; no share icon in their app bars. The finish summary button stays.
- **FR-003**: Gym cards render every exercise with sets; the "+N more exercises" line is removed.
- **FR-004**: Card height is 450 dp unless the gym list needs more, then up to 640 dp; two
  columns, then smaller rows, when needed.
- **FR-005**: Duration stats are number/unit parts; stat grids scale all values uniformly.

## Success Criteria *(mandatory)*

- **SC-001**: A 10-, 20- and 40-exercise workout each produce a card listing every exercise with
  no overflow.
- **SC-002**: In the gym totals row, the duration digits are the same height as the sets and reps
  digits.
- **SC-003**: Share is reachable in two taps from both detail screens (⋮ → Share).

## Assumptions

- A taller 9:16 image is fine for WhatsApp/Instagram stories; 4:5 stays the default.
