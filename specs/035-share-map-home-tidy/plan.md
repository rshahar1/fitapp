# Implementation Plan: Map Behind Shared Routes, Tidier Home

**Branch**: `035-share-map-home-tidy` | **Date**: 2026-11-21 | **Spec**: [spec.md](./spec.md)

## Summary

Share cards fetch the MapTiler tiles that cover the route, wait for them, and paint them under the
route in one Web Mercator projection. Home drops the "By type" header and gets a compact gym row
that shows the template name, resolved in the repository. No schema, sync or dependency change.

## Design

1. `lib/domain/share/map_tiles.dart` (pure Dart, tests first): `fitTileView(points, width,
   height, padding, minZoom, maxZoom)` → a `TileView` (integer tile zoom, scale, top-left world
   pixel) with `project(point)` and `tiles` (x, y, wrapped x, screen rect).
2. `lib/features/share/share_map.dart`: `ShareMapTiles` loads every tile image through
   `NetworkImage` (8 s cap); `shareMapProvider` (`FutureProvider.family`) per route + style;
   `ShareMap` is the route box: tiles, a light soot veil, the route painter in the tile
   projection, and the credit line. No key → no tiles, current look.
3. `ShareRoutePainter` takes an optional projector; without one it keeps `projectRoute`.
4. `ShareCardView` takes an optional `ShareMapImages`; the preview loads it before it shows the
   card ready and keeps "Preparing…" until then.
5. Home: remove `SectionHeader('By type')`; `HistoryEntryRow(compact: true)` renders a
   `GroupRow` (date, template name) for gym workouts; `WorkoutRepository.history` fills
   `templateName`.
6. Tests: tile maths, compact row, repository `templateName`, Home without header, share card
   with tiles disabled (unchanged) and with fake tiles.
7. PRD §5.5 / §5.11 + changelog v2.21.
