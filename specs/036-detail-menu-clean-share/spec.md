# Feature Specification: Clean Share Map, Edit and Delete in the ⋮ Menu

**Feature Branch**: `036-detail-menu-clean-share`

**Created**: 2026-11-21

**Status**: Implemented

**Input**: Owner (2026-11-21, after 0.0.29): (1) remove the MapTiler text from the GPS share
image without breaking the map or the share flow. (2) On a workout opened from History, move Edit
and Delete into the vertical ⋮ menu next to Share and drop the separate app-bar buttons.

## Findings before the change

- `ShareMapCredit` ("© MapTiler © OpenStreetMap") is stacked bottom-right on the route box in
  `share_card_view.dart` (`_RouteBox`) whenever tiles loaded. The in-app maps (`route_map.dart`)
  have their own `RichAttributionWidget`, which pops open for 3 s each time a map opens.
- `ActivityDetailScreen` (run, ride, snow, other activities) and `WorkoutScreen` (finished gym
  workout) both show Edit and Delete icon buttons beside the ⋮ menu.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Share image without the credit (Priority: P1)

1. **Given** a GPS run with map tiles, **When** the share preview opens, **Then** the route is
   drawn on the tiles and no "MapTiler" / "OpenStreetMap" text is on the card; sharing works.
2. **Given** tiles fail, **Then** the plain route is shown and sharing works (unchanged).
3. (Owner follow-up, after 0.0.30) **Given** a GPS activity opened from History, live tracking or
   snow replay, **Then** no MapTiler / OpenStreetMap credit or info button appears on the map, not
   even briefly.

### User Story 2 - Edit and Delete in the ⋮ menu (Priority: P1)

1. **Given** a finished activity, **When** its detail opens, **Then** the app bar shows only the
   ⋮ menu ("More options") holding Edit activity, Share and Delete activity; Edit opens the
   activity sheet, Delete asks for confirmation as before.
2. **Given** a finished gym workout, **Then** the app bar shows only the ⋮ menu ("Workout
   options") with Edit workout, Share, Resume workout (when allowed), Save as template (with
   exercises) and Delete workout; Edit enters edit mode, Delete asks for confirmation.
3. **Given** edit mode, **Then** a "Done editing" check button stays in the app bar to leave it,
   and the menu offers no Edit / Share item (as Share was hidden while editing before).
4. A live workout is unchanged (no Edit / Delete; Save as template, Discard).

## Requirements

- **FR-001** The share card draws no map credit text; tiles, route, markers and capture stay.
- **FR-005** No in-app map (`RouteMap`) shows an attribution popup or button.
- **FR-002** Edit and Delete are ⋮ menu items with an icon and label (ListTile, like Share);
  Delete uses the danger colour and is last. No standalone Edit / Delete buttons.
- **FR-003** Menu items follow the app's text direction (Material handles RTL mirroring).
- **FR-004** Dialogs, sheet and navigation for Edit and Delete are unchanged.

## Notes

- MapTiler's and OpenStreetMap's terms ask for attribution on maps shown to others; removing the
  credit is the owner's decision (recorded in PRD §15).
