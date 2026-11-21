# Implementation Plan: Iron Plate Visual Identity

**Branch**: `034-iron-plate-theme` | **Date**: 2026-11-21 | **Spec**: [spec.md](./spec.md)

## Summary

A look-only reskin of the whole app. New tokens, typefaces, shapes and an icon map are defined
once in `lib/app/theme/`; every widget, sheet, chart, map layer, the reward animation and the share
picture are then swept to use them; the launcher icon and splash are regenerated. No domain,
schema, sync or behaviour change.

## Technical Context

**Language/Version**: Dart 3 / Flutter 3.50 (stable)
**Primary Dependencies**: Material 3 (`material_ui`), Riverpod, fl_chart, flutter_map; new:
`material_symbols_icons` 4.2960.0 (Material Symbols Sharp, variable weight)
**Storage**: unchanged (drift)
**Testing**: `flutter test` (widget + unit), `dart format`, `flutter analyze` (very_good_analysis)
**Target Platform**: Android first (emulator `fitapp_sim` for owner review), iOS builds kept green
**Project Type**: mobile app
**Performance Goals**: set logging UI < 100 ms (unchanged); no layout shift on ticking numbers
**Constraints**: offline (fonts bundled); always dark; tokens only; ≥ 48 dp targets
**Scale/Scope**: ~60 widget files, ~12 widget test files, launcher + splash assets, PRD §2.2

## Constitution Check

| Principle | Status |
|---|---|
| I–III domain purity / tests first | No domain change; widget tests updated with the files they cover. |
| IV tokens only, built-ins preferred | All look values live in `lib/app/theme/`; one maintained, null-safe package added (icons) — Material Symbols is Google's own successor of the built-in set. |
| V always dark, one accent, fixed metric colors, tabular figures, 48 dp, semantics, fixed footer | Kept: yellow is the single accent, metric colors stay fixed (new values), numbers use a face with real tabular digits, semantics strings unchanged (capitals come from the font, not from the strings). |
| Hevy reference only | Unaffected. |

Gate: **pass**. No constitution amendment (only PRD §2.2 values change).

## Design

See [research.md](./research.md) for the decisions and
[contracts/theme-contract.md](./contracts/theme-contract.md) for the exact tokens.

1. **Fonts** (`assets/fonts/`, `pubspec.yaml` `fonts:`):
   - `PlateDisplay` 800/900: Big Shoulders Display pinned to static weights with lowercase mapped to
     capitals (built by `tool/build_display_font.py`). Words: screen titles, exercise and template
     names, section headers, Go label, tags, share headings.
   - `BarlowCondensed` 600/700/800 with `tnum`: every big or ticking number (timers, steppers,
     weights, totals, live tracking, share stats).
   - `Barlow` 400/500/600/700: default family for everything else.
   - OFL licence texts registered with `LicenseRegistry`.
2. **Tokens** (`tokens.dart`): new `AppColors` values (old names kept where meaning is unchanged;
   `accentBright`/`mint`/`rewardIconFill` re-pointed; `metricSetsText` / `metricVolumeText`
   readable tints added; `live` → safety orange; `heat` in plate order). `Radii` becomes
   `card = 2`, `chip = 0`, `block = 0`; `pill` removed. New `Strokes` (`rule = 1`,
   `section = 2`, `cardTop = 4`, `outline = 1.5`). New `AppFonts` family names.
3. **Theme** (`app_theme.dart`): `fontFamily: Barlow`; text theme maps display/headline/title to
   `PlateDisplay`; component themes for every Material control in use (buttons, icon buttons,
   dialogs, popup menus, snackbars, bottom sheets, date picker, segmented button, slider,
   progress, switch, checkbox, input decoration, tab bar, FAB, tooltip, chips, list tiles,
   navigation bar) with `RoundedRectangleBorder(Radii.card)` or `BeveledRectangleBorder.zero`;
   `IconThemeData(weight: 600, opticalSize: 24, fill: 0)`; `MetricColors` gets the plate values;
   a `PlateTextStyles` extension (`number`, `display`, `tag`) for the non-Material styles.
4. **Icons** (`app_icons.dart`): `AppIcons` maps every semantic icon now used
   (`Icons.*`, 52 names) to `Symbols.*_sharp`. `Icons.` is no longer referenced in `lib/` or
   `test/`. `activity_icons.dart` maps activity types to sharp symbols.
5. **Shared kit** (`lib/widgets/`): square `AppCard` with optional 4 dp yellow top rule,
   rectangular `AppButton` (filled yellow / outlined chalk / text), `Group` with 1 dp rules,
   `SectionHeader` in `PlateDisplay`, tape-label `ChipSelector`, square `AppStepper`,
   `DeltaBadge` as a flat plate tag, charts with square bar ends and plate colors.
6. **Screens** swept by area (see tasks): shell + Go block, workout (square checks, yellow
   current set rail, overload tag, rest block, reward), templates and exercises, history and
   calendar, progress and charts, tracking and activities (square markers, plate heatmap,
   safety-orange live), train / you / settings / account / privacy, share preview and the share
   card painter.
7. **Backdrop**: same photos, scrims built from `AppColors.background` (soot) instead of black.
8. **Launcher and splash**: new 1024 px `icon.png` / `icon_foreground.png` (yellow square-capped
   chevron and bar on soot) drawn by `tool/draw_launcher_icon.swift`; regenerate with
   `flutter_launcher_icons` and `flutter_native_splash` using `#15120F`.
9. **Docs**: PRD v2.20 §2.2 rewritten with the new tokens + changelog; `CLAUDE.md` active
   feature → 034.
10. **Guard test**: `test/app/theme_guard_test.dart` scans `lib/` for old hex values, `Icons.`,
    `BoxShape.circle`, `StadiumBorder`, `CircleBorder` and `Radii.pill` and fails if any remain
    (SC-001).
11. **Review gate**: run on `fitapp_sim` (`flutter run`), owner walk-through; fixes land on this
    branch; merge / version bump / APK only after explicit approval.

## Project Structure

```text
assets/fonts/                 PlateDisplay-*.ttf, Barlow*.ttf, OFL-*.txt
assets/icon/                  icon.png, icon_foreground.png (regenerated)
tool/                         build_display_font.py, draw_launcher_icon.swift
lib/app/theme/                tokens.dart, app_theme.dart, app_icons.dart, text_styles.dart
lib/app/backdrop.dart
lib/widgets/*                 shared kit
lib/features/**               screen sweeps
test/app/theme_guard_test.dart
```

## Complexity Tracking

None.
