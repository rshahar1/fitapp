# Feature Specification: Map Behind Shared Routes, Tidier Home

**Feature Branch**: `035-share-map-home-tidy`

**Created**: 2026-11-21

**Status**: Implemented

**Input**: Owner (2026-11-21, after testing 0.0.28): (1) the running / cycling share image draws
the route on a plain black box with no streets or city, so the place is not recognisable; draw it
on a real map. (2) Home: remove the redundant "BY TYPE" header above the weekly per-type list.
(3) Home: gym rows under "RECENT" list every exercise; show only the template name, as compact as
running, cycling and functional rows.

## Findings before the change

- `ShareRoutePainter` projects the route onto a `surfaceHigh` box with no tiles (feature 027
  chose "no map tiles"). The in-app maps already use MapTiler raster tiles (`MAP_TILES_KEY`).
- The card is captured with `RepaintBoundary.toImage`; a live `flutter_map` widget gives no
  signal that its tiles have loaded, so a capture could hold half-loaded tiles.
- `workouts.name` is never written; a workout does not store its template. Each
  `workout_exercises.template_exercise_id` points to the template exercise it came from.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Route on a map (Priority: P1)

1. **Given** a GPS run or ride with a route and map tiles available, **When** the share preview
   opens, **Then** the route is drawn over map tiles (streets, labels) of that place, start and
   finish markers on top, with a small "© MapTiler © OpenStreetMap" credit.
2. **Given** the tiles are still loading, **When** Share image is tapped, **Then** the image is
   captured only once the tiles are drawn (or have failed).
3. **Given** no tiles key, no network or a tile error, **Then** the card falls back to the plain
   background as before; sharing still works.
4. Snowboarding cards get the same map, in the user's chosen map style.

### User Story 2 - Home list without "By type" (Priority: P2)

1. **Given** sessions this week, **Then** the per-type rows follow the stat tiles with no
   "By type" header.

### User Story 3 - Compact gym rows in Recent (Priority: P2)

1. **Given** a gym workout started from template "Push Day", **Then** its Home Recent row shows the
   date and "Push Day" only (no exercise list), one line each, like activity rows.
2. **Given** the template was deleted, or the workout came from no template, **Then** the row shows
   "Workout".
3. History rows keep their full layout (exercises, volume, sets).

## Requirements *(mandatory)*

- **FR-001**: Route and snow share cards draw raster map tiles that cover the route's Web Mercator
  bounds, fitted with padding, at a zoom between 3 and 17; the route uses the same projection.
- **FR-002**: The preview waits for every tile to load or fail (at most 8 s) before the card is
  drawn as ready; the Share button stays in "Preparing…" until then.
- **FR-003**: Running, cycling and other route cards use the Dark style; snowboarding uses the
  chosen map style. Tiles are requested at @2x for a sharp 1080 px image.
- **FR-004**: Home has no "By type" header; the list itself is unchanged.
- **FR-005**: `WorkoutListItem` carries `templateName`: the workout's name, else the name of the
  template its exercises came from, else null. Home Recent gym rows show the date and
  `templateName ?? 'Workout'`.

## Success Criteria *(mandatory)*

- **SC-001**: A shared 5 km city run shows the streets and place names around the route.
- **SC-002**: Home Recent rows have the same height for gym and activity sessions; no overflow.

## Assumptions

- Only tile coordinates leave the device, as for the in-app maps (constitution VI).
- A renamed template shows its current name in Recent.
