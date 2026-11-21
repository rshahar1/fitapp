# Implementation Plan: Share Polish

**Branch**: `029-share-polish` | **Date**: 2026-11-21 | **Spec**: [spec.md](./spec.md)

## Summary

Swap every share icon for `Icons.adaptive.share`; move Share into the `⋮` menus; drop the
exercise cap and give the gym card a computed height / column layout; render durations as
number + unit parts and scale stat grids uniformly. No schema, sync or dependency change.

## Constitution Check

Layout math (`shareListLayout`) and duration parts live in `lib/domain/share/share_card.dart`,
pure and tested first (II, III). Sizes in `ShareCardSize` tokens (IV). Menu items keep 48 dp
targets and labels (V). No privacy or scope change (VI, VII).

## Design

1. **Domain** `share_card.dart`:
   - `ShareStat` gains `parts` (`List<ShareStatPart>`: text + `isUnit`); `ShareStat(label, value,
     [unit])` keeps working; `value`/`unit`/`toString` derive from parts. Duration stats use
     `durationShareStat(label, minutes)` → `27 min`, `1h 3m`, `4h`.
   - Remove `maxShareExerciseLines` and `hiddenExercises`; `exercises` holds all lines.
   - `shareListLayout(count, baseHeight, maxHeight, overhead, rowHeight, twoColumnRowHeight)` →
     `ShareListLayout(cardHeight, columns, rowHeight)`: one column at base height if it fits;
     one column grown up to max; two columns (two-line rows) clamped to max; else two columns at
     max with rows shrunk to fit.
2. **Tokens** `ShareCardSize`: `maxHeight` 640, fixed `header`, `statBlock`, `footer` heights and
   `strengthOverhead`, `twoColumnRow` 40.
3. **View** `share_card_view.dart`: canvas height from `shareListLayout` for strength cards;
   header/stats/footer at fixed heights; list in 1 or 2 columns with `LayoutBuilder` safety (row
   height never exceeds available space); `_StatGrid` measures every value with `TextPainter` and
   applies one shared scale; parts rendered as big digits + small units.
4. **Entry points**: activity detail gets a `PopupMenuButton` (tooltip "More options") with
   Share; workout screen moves Share into its existing menu (finished, not editing); icons →
   `Icons.adaptive.share` in finish summary and preview screen.
5. **Tests**: domain tests for parts and layout; update widget tests (`share_test.dart`) for the
   menus and the uncapped list.
6. **Docs**: PRD §5.11 + changelog (v2.15), CLAUDE.md active feature.
