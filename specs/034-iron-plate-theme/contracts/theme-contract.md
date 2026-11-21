# Theme Contract (feature 034)

The only place look values exist. Widgets read these; they never hard-code values.

## AppColors

| Token | Value | Use |
|---|---|---|
| `background` | `#15120F` | screen, nav bar, canvas |
| `surface` | `#201C18` | cards, sheets, dialogs, menus |
| `surfaceHigh` | `#2E2822` | rules, pressed rows, stepper wells, empty bars |
| `textPrimary` | `#EDE6D8` | chalk text |
| `textSecondary` | `#9C9284` | labels, captions |
| `textTertiary` | `#7A7064` | chevrons, empty check squares (graphics only) |
| `accent` | `#F5C518` | single action color |
| `onAccent` | `#15120F` | text/icons on accent |
| `accentSoft` | accent at 15 % | current-set tint, selected chips |
| `live` / `liveSoft` | `#F2711C` / 15 % | session in progress |
| `danger` | `#FF6A5C` | destructive text and icons |
| `plateRed` | `#E5352B` | red fills, sets bars |
| `plateBlue` | `#3D7BF2` | blue fills, volume bars |
| `plateGreen` | `#2FB85C` | done squares, reps |
| `metricSets` | `#FF6A5C` | sets (readable) |
| `metricReps` | `#2FB85C` | reps |
| `metricVolume` | `#6FA0FF` | volume (readable) |
| `metricWeight` | `#EDE6D8` | weight (plate white) |
| `routeLift` | `#9C9284` | lift stretches |
| `heat` | blue `#3D7BF2` → green `#2FB85C` → yellow `#F5C518` → orange `#F2711C` → red `#E5352B` | speed |
| `accentBright` | `#FFD84A` | reward flash |
| `mint` | `#EDE6D8` | reward highlight (chalk) |
| `gold` | `#F5C518` | reward spark |
| `rewardIconFill` | `#2E2822` | reward figure fill |
| scrims | soot at 45 % / 65 % | backdrop, reward |

## Shapes and strokes

`Radii.card = 2`, `Radii.chip = 0`, `Radii.block = 0` (no `pill`).
`Strokes.rule = 1`, `Strokes.section = 2`, `Strokes.cardTop = 4`, `Strokes.outline = 1.5`.

## Type

| Family | Weights | Use |
|---|---|---|
| `PlateDisplay` | 800, 900 | words in capitals: titles, names, headers, Go, tags |
| `BarlowCondensed` | 600, 700, 800 (+ `tnum`) | big or ticking numbers |
| `Barlow` | 400, 500, 600, 700 | default |

`context.plate` (`PlateTextStyles` extension): `display(size)`, `number(size)`, `tag`.

## Icons

`AppIcons.<name>` → `Symbols.<name>_sharp`; theme icon weight 600, fill 0. `Icons.` is banned.
