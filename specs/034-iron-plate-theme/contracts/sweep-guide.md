# Sweep Guide (feature 034, "Iron plate")

How to convert a widget file from the old look to the Iron plate look. Read
[theme-contract.md](./theme-contract.md) first. The theme (`lib/app/theme/`) is already done:
**never edit `lib/app/theme/*`**. If you need a token that does not exist, use the closest one and
report it.

## Imports

```dart
import 'package:fitapp/app/theme/app_icons.dart';   // AppIcons
import 'package:fitapp/app/theme/text_styles.dart'; // context.plate
import 'package:fitapp/app/theme/tokens.dart';      // AppColors, Radii, Strokes, AppFonts, Space, Sizes
import 'package:fitapp/app/theme/app_theme.dart';   // context.metrics, tabular
```

## Icons: `Icons.*` is banned in `lib/` and `test/`

| Old | New |
|---|---|
| `Icons.add`, `Icons.add_circle_outline` | `AppIcons.add`, `AppIcons.addBox` |
| `Icons.remove` | `AppIcons.remove` |
| `Icons.check` | `AppIcons.check` |
| `Icons.close` | `AppIcons.close` |
| `Icons.edit_outlined` | `AppIcons.edit` |
| `Icons.delete_outline` | `AppIcons.delete` |
| `Icons.search` / `Icons.search_off` | `AppIcons.search` / `AppIcons.searchOff` |
| `Icons.adaptive.share` | `AppIcons.share` |
| `Icons.replay` | `AppIcons.replay` |
| `Icons.more_vert` | `AppIcons.more` |
| `Icons.drag_handle` | `AppIcons.dragHandle` |
| `Icons.login`, `Icons.lock`, `Icons.lock_open` | `AppIcons.login`, `AppIcons.lock`, `AppIcons.lockOpen` |
| `Icons.arrow_back` | `AppIcons.back` |
| `Icons.chevron_left` / `Icons.chevron_right` | `AppIcons.chevronLeft` / `AppIcons.chevronRight` |
| `Icons.calendar_month` | `AppIcons.calendar` |
| `Icons.history`, `Icons.history_outlined` | `AppIcons.history` |
| `Icons.show_chart`, `Icons.show_chart_outlined` | `AppIcons.chart` |
| `Icons.view_list`, `Icons.view_list_outlined` | `AppIcons.list` |
| `Icons.list_alt` | `AppIcons.listAlt` |
| `Icons.person`, `Icons.person_outline` | `AppIcons.person` |
| `Icons.settings_outlined` | `AppIcons.settings` |
| `Icons.layers_outlined` | `AppIcons.layers` |
| `Icons.play_arrow`, `Icons.play_arrow_rounded` | `AppIcons.play` |
| `Icons.pause` | `AppIcons.pause` |
| `Icons.timer_outlined` | `AppIcons.timer` |
| `Icons.flag` | `AppIcons.flag` |
| `Icons.info_outline` | `AppIcons.info` |
| `Icons.error_outline` | `AppIcons.error` |
| `Icons.science_outlined` | `AppIcons.science` |
| `Icons.cable` | `AppIcons.cable` |
| `Icons.gps_fixed` / `Icons.gps_not_fixed` | `AppIcons.gpsFixed` / `AppIcons.gpsSearching` |
| `Icons.my_location` | `AppIcons.myLocation` |
| `Icons.location_on` / `Icons.location_off_outlined` / `Icons.location_disabled` | `AppIcons.locationOn` / `AppIcons.locationOff` / `AppIcons.locationDisabled` |
| `Icons.fitness_center(_outlined)` | `AppIcons.gym` |
| `Icons.directions_bike` / `Icons.directions_run` | `AppIcons.cycling` / `AppIcons.running` |
| `Icons.snowboarding` / `Icons.downhill_skiing` | `AppIcons.snowboarding` / `AppIcons.skiing` |
| `Icons.self_improvement` / `Icons.sports` | `AppIcons.pilates` / `AppIcons.sport` |

Tests: `find.byIcon(Icons.x)` → `find.byIcon(AppIcons.y)`.

## Shapes: square

- `BorderRadius.circular(Radii.pill)`, `StadiumBorder()`, `CircleBorder()`, `BoxShape.circle`,
  `CircleAvatar` → square: `RoundedRectangleBorder()` / `BoxShape.rectangle` /
  `BorderRadius.zero`. `Radii.pill` no longer exists.
- Containers and cards: `Radii.card` (2 dp). Chips, tags, badges, bars, check boxes, markers:
  `Radii.chip` / `Radii.block` (0) or `BorderRadius.zero`.
- Any `Radius.circular(n)` with n ≥ 5 is a leftover (the guard test fails on it).
- Primary cards (the main card of a screen section, exercise cards, stat cards):
  `AppCard(topRule: true, ...)`. Grouped list rows keep plain cards with 1 dp rules
  (`Strokes.rule`).
- Check marks: done = solid square `AppColors.plateGreen` with `AppIcons.check` in
  `AppColors.onAccent`; empty = square outline `AppColors.textTertiary`, width `Strokes.outline`.
- Current / active row: 4 dp `AppColors.accent` left rail (`Strokes.cardTop`) + `AppColors.accentSoft`
  tint.
- Tape-label chips and tags: flat block (`accent` with `onAccent` text when selected / emphasised)
  or outlined rectangle (`Strokes.outline`, `textSecondary`) when idle; text `context.plate.tag()`.
- No shadows, glows, blurs or decorative gradients (`elevation: 0`). Functional fades (map scrims,
  photo backdrop) stay.

## Type

- Never call `.toUpperCase()` for styling: the `PlateDisplay` family draws capitals by itself.
  Remove existing `.toUpperCase()` calls that only served styling (keep semantics strings
  unchanged).
- Words that are titles, exercise / template / activity names, section headers, tags, button
  labels → `Theme.of(context).textTheme.titleLarge` / `headlineSmall` (already `PlateDisplay`) or
  `context.plate.display(size)`.
- Big or ticking numbers (≥ 18 sp, timers, steppers, weights, totals, live tracking values, chart
  hero values) → `context.plate.number(size, color: ...)`. Smaller numbers in body text keep the
  body face with `fontFeatures: tabular`.
- Everything else: theme defaults (Barlow).
- Hard-coded `fontWeight: w600/w700` on body text is fine; do not set `fontFamily` by hand except
  through `AppFonts`.

## Color

- `AppColors.accent` (yellow) = actions, selection, current state; text on it = `onAccent`.
- Metric colors via `context.metrics` (`sets` red, `reps` green, `volume` blue, `weight` chalk).
  Bars and large fills may use `AppColors.plateRed` / `plateBlue` / `plateGreen` / `accent`.
- Destructive = `AppColors.danger`; in progress = `AppColors.live` / `liveSoft`.
- `Color(0x00000000)` → `Colors.transparent`. No hex literals in widgets.

## Charts and maps

- Bars: square ends (`BorderRadius.zero`), current period `accent`, others `surfaceHigh` or the
  metric color. Grid lines `surfaceHigh` 1 dp, axis labels `textSecondary`.
- Lines: flat line in the metric or accent color, `isStrokeCapRound: false`, optional area fill at
  15 % of the line color, no glow / shadow layer, square dots.
- Map routes: `StrokeCap.square` ends, start / finish / position markers are squares with a soot
  outline; heatmap from `AppColors.heat`; lifts `AppColors.routeLift`.

## Don'ts

- Don't change behaviour, keys, `Semantics` labels, tap targets (≥ `Sizes.tap`), or layout
  structure. Don't rename public widget APIs (only add optional parameters with defaults).
- Don't edit files outside your assigned list. Don't run `git` commands that write.

## Verify (your files only; other areas are being edited in parallel)

```bash
dart format <your files>
flutter analyze <your lib and test paths>          # zero issues in your files
flutter test <your test files>                      # all pass
grep -nE "Icons\.|BoxShape\.circle|CircleBorder|CircleAvatar|StadiumBorder|Radii\.pill|Radius\.circular\(\s*([5-9]|[0-9]{2,})|0x[0-9A-Fa-f]{8}" <your files>   # no output
```

Errors that come only from files outside your list are expected while others work; report them,
don't fix them.
