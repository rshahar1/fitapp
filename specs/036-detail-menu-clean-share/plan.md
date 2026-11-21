# Implementation Plan: Clean Share Map, Edit and Delete in the ⋮ Menu

**Branch**: `036-detail-menu-clean-share` | **Date**: 2026-11-21 | **Spec**: [spec.md](./spec.md)

## Summary

UI-only change. No domain, schema, sync or dependency change.

## Design

1. `lib/features/share/share_card_view.dart`: `_RouteBox` no longer stacks `ShareMapCredit`;
   `lib/features/share/share_map.dart`: remove `ShareMapCredit`. Share tests assert no credit
   text with tiles and that the tiles painter is still present and sharing works.
2. `lib/features/activities/activity_detail_screen.dart`: remove the two `IconButton`s; the
   `PopupMenuButton` ("More options") gets `edit`, `share`, `delete` items (`ListTile`, leading
   `AppIcons.edit` / `AppIcons.share` / `AppIcons.delete`, Delete icon and text in
   `AppColors.danger`), dispatched with a `switch` to `showActivitySheet`, share route, `_delete`.
3. `lib/features/workout/workout_screen.dart`: for a finished workout the standalone Edit button
   shows only while editing ("Done editing", check icon); Delete button removed. The menu shows for
   every finished workout and holds `edit` (readOnly), `share` (readOnly), `resume`, `template`,
   `delete` (finished), `discard` (live).
4. Tests: replace `find.byTooltip('Edit …' / 'Delete …')` taps with opening the ⋮ menu and tapping
   the item text; assert no standalone buttons.
5. PRD §5 / §15 + changelog v2.22; CLAUDE.md active feature.
