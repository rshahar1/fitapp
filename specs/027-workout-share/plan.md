# Implementation Plan: Share a Workout as an Image

**Branch**: `027-workout-share` | **Date**: 2026-11-20 | **Spec**: [spec.md](./spec.md)

## Summary

Every finished gym workout and every activity gets a **Share** action that opens a preview of a
1080 × 1350 PNG card and hands it to the Android share sheet. A pure-Dart domain module turns a
session into type-specific card data (stats, route, ride/lift/rest breakdown, compressed exercise
lines); a Flutter widget renders that data on a fixed 360 × 450 dp canvas which is captured at
3× through a `RepaintBoundary`. The route is drawn with a `CustomPainter` (no map tiles), so the
image works offline and no tile key or network call is involved.

## Technical Context

**Language/Version**: Dart 3.14, Flutter 3.50 (unchanged)
**New dependencies**: `share_plus` ^13.3.1 (Flutter Community, current, null-safe) — the
standard way to open the platform share sheet with a file. `path_provider` (already present)
supplies the temporary directory.
**Storage**: none (temporary PNG in the cache directory, overwritten per share). No schema or
sync change.
**Testing**: domain unit tests first (`test/domain/share/`), widget tests for the card layouts,
the preview screen (with a fake sharer) and the entry points.
**Target Platform**: Android first (iOS works through the same plugin later).
**Performance Goals**: card capture + file write < 2 s (SC-003).
**Constraints**: offline, no network, no notes on the image, theme tokens only.

## Constitution Check

| Principle | Status |
|-----------|--------|
| I Offline-first | ✅ Rendering is local; route drawn without tiles. |
| II Pure domain | ✅ Card data, set-line compression, stat selection, route projection and list capping live in `lib/domain/share/` with tests first. |
| III Test-first gates | ✅ Domain tests before code; format/analyze/test before commit. |
| IV Layering | ✅ Widgets read existing providers; sharing goes through an `ImageSharer` interface in `lib/core/` behind a Riverpod provider (fake in tests). Colors/sizes from tokens (new share-card tokens added to `tokens.dart`). |
| V UX | ✅ Share is an app-bar icon (48 dp) with a tooltip/semantics label; preview + one button. |
| VI Privacy | ⚠️ → amended. The image leaves the device only when the user picks a target in the OS share sheet; the app sends nothing itself. Notes excluded. |
| VII Scope | ⚠️ → amended. Constitution says "any sharing between users remains out of scope until the owner requests them". Owner requested it on 2026-11-20 → constitution 1.9.0 (MINOR): image export via the OS share sheet is in scope; social features (feeds, friends, in-app sharing between accounts) stay out. |

No unjustified violations; Complexity Tracking empty.

## Project Structure

```text
lib/domain/share/
  share_card.dart          # ShareCardData + ShareStat/ExerciseLine/TimeBreakdown, builders
  route_projection.dart    # projectRoute(points, size, padding) -> offsets (pure)
lib/core/image_sharer.dart # ImageSharer interface + share_plus implementation + provider
lib/features/share/
  share_card_view.dart     # renders ShareCardData on a 360x450 canvas
  share_route_painter.dart # CustomPainter for route + coloured spans + dots
  share_preview_screen.dart# loads session, shows card, captures PNG, calls ImageSharer
lib/app/router.dart        # /share/workout/:id, /share/activity/:id
lib/features/activities/activity_detail_screen.dart  # Share icon
lib/features/workout/workout_screen.dart             # Share icon (finished, read-only)
lib/features/workout/widgets/finish_summary_sheet.dart # "Share workout" choice
test/domain/share/*_test.dart, test/features/share_test.dart
```

## Design

1. **Domain** (`share_card.dart`): input records free of drift types —
   `ActivityShareInput` (typeId, startedAt, durationMinutes, distanceMeters, movingSeconds,
   elevationGainMeters, route, splits, maxSpeedMps, verticalDropMeters, runCount, liftSeconds,
   restSeconds, segments, source) and `WorkoutShareInput` (name, startedAt, endedAt, exercises of
   `(name, perHand, sets[(weight, reps)])`). Builders `activityShareCard` and `workoutShareCard`
   return `ShareCardData` with `layout` ∈ {route, snow, strength, basic}. See
   [data-model.md](./data-model.md).
2. **Stat rules**: omit null/≤0 values; pace/speed only when distance and duration > 0; same
   formulas as the detail screen; max 6 stats on route/basic cards, 6 on snow, 4 totals on
   strength.
3. **Exercise lines**: uniform sets → `3 × 8 · 60 kg`; mixed → `4 sets · top 85 kg × 5` (top =
   heaviest weight, then most reps); weight 0 → reps only; per-hand → `kg each`; at most 7 lines,
   or 6 + `+N more exercises` when there are more than 7.
4. **Rendering**: `ShareCardView` is a fixed 360 × 450 logical canvas (≥ 10 dp text → ≥ 30 px at
   3×). Header (type icon, title, date), body by layout, footer "FitApp". Route area uses
   `projectRoute`; snow spans reuse `snowLiftSpans`/`snowHeatSpans`.
5. **Capture/share**: `RepaintBoundary.toImage(pixelRatio: 3)` → PNG bytes →
   `ImageSharer.sharePng(bytes, fileName, text)` writes to the temp dir and calls `SharePlus`.
   Errors show a SnackBar ("Could not share the image.").
6. **Entry points**: see [contracts/ui-share.md](./contracts/ui-share.md).
7. **Docs**: constitution 1.9.0, PRD v2.13 (§5.11 Sharing, decision log, changelog), README
   roadmap, `docs/ARCHITECTURE.md` feature list, CLAUDE.md active feature.

## Complexity Tracking

None.
