# Feature Specification: Iron Plate Visual Identity

**Feature Branch**: `034-iron-plate-theme`

**Created**: 2026-11-21

**Status**: Draft

**Input**: Owner (2026-11-21): replace the whole visual identity with the "Iron plate" direction
(chalk, steel and competition plates) everywhere in the app, with no leftover of the previous style:
every screen, tab, sheet, dialog, menu, snackbar, picker, settings, charts, maps and route colors,
live tracking, the reward animation, share cards (the exported picture), the launcher icon and the
splash screen. The owner wants to try it on the local Android emulator and reject details before
anything is merged to main or released as an APK.

## Findings before the change

- The look (PRD §2.2) is an iOS-style dark skin: pure black background, `#1C1C1E` / `#2C2C2E`
  grey cards, one green accent `#11D16C`, metric colors red / green / light blue / orange, a live
  orange, rounded cards (radius 14), pill buttons, circular check marks and a circular Go button,
  the platform default typeface, and stock rounded Material icons.
- All colors and sizes already come from one token file; shapes, typefaces and icons are spread
  across about 30 widget files.
- The share picture, the reward animation, route heatmaps, the launcher icon (green chevron on
  black) and the splash screen (black) each carry the old colors independently.

## Design direction (the "Iron plate" look)

| Role | Value | Contrast note |
|---|---|---|
| Background (soot) | `#15120F` | chalk text 15.0:1 |
| Surface (cards, sheets) | `#201C18` | chalk text 13.6:1 |
| Surface high / rules | `#2E2822` | chalk text 11.7:1, muted 4.75:1 |
| Text primary (chalk) | `#EDE6D8` | |
| Text secondary (muted) | `#9C9284` | 5.5:1 on surface |
| Text tertiary (graphics only) | `#7A7064` | 3.5:1 on surface, never body text |
| Accent (plate yellow) | `#F5C518` | 10.4:1 on surface; soot text on it 11.5:1 |
| Live (safety orange) | `#F2711C` | 5.8:1 on surface |
| Plate red (fills) / readable red (text) | `#E5352B` / `#FF6A5C` | fill 3.9:1; text 6.0:1 |
| Plate blue (fills) / readable blue (text) | `#3D7BF2` / `#6FA0FF` | fill 4.3:1; text 6.6:1 |
| Plate green | `#2FB85C` | 6.6:1 |
| Plate white | chalk `#EDE6D8` | |

Metric colors follow the competition plates: **sets = red, reps = green, volume = blue,
weight = plate white**. Yellow is reserved for actions so it never doubles as a metric.

Typography: a condensed industrial display face (Big Shoulders Display, heavy, capitals) for
screen titles, exercise names, section headers, tags and the Go label; a condensed numeric face
with fixed-width digits (Barlow Condensed) for big and ticking numbers; a sturdy grotesque
(Barlow) for body, rows and controls.

Shape: square corners everywhere (at most 2 dp softening), solid square check boxes, a 4 dp yellow
top rule on primary cards, "tape label" chips (flat block or 1.5 dp outlined rectangle), thick
2 dp rules between sections, and a rectangular yellow Go block.

Icons: one consistent heavy, sharp-cornered outline set (about 2.5 dp stroke at 24 dp, square
caps, no rounded terminals) replacing the stock rounded icons; activity glyphs follow the same
geometry.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Core gym flow in the new look (Priority: P1)

The owner opens the app, sees the Train tab, taps Go, starts a workout, logs sets, rests and
finishes, entirely in the Iron plate look.

**Why this priority**: this is the screen time that matters most; it proves the identity.

**Independent Test**: run a full workout on the emulator and compare every screen against the
direction table above.

**Acceptance Scenarios**:

1. **Given** any tab, **When** the app shows, **Then** the background is soot, cards are square
   surface blocks, titles are condensed uppercase, and the bottom bar's centre action is a
   rectangular yellow "Go" block with soot text and a play glyph.
2. **Given** an active workout, **When** a set is logged, **Then** its row shows a solid green
   square check, the current set is marked in yellow, and the overload set shows a yellow tag
   with soot text (no green, no circles, no pills).
3. **Given** the rest timer runs, **When** it shows in the footer, **Then** it is a square yellow
   or outlined block with fixed-width digits that do not shift as they change.
4. **Given** any number shown for sets, reps, volume or weight, **When** it is colored by metric,
   **Then** it uses red, green, blue or plate white respectively.

---

### User Story 2 - Every other screen, sheet and control (Priority: P1)

Every remaining surface (Train, History calendar, Progress, exercise detail and charts, Templates
and editor, exercise library and picker, custom exercise sheet, You tab, Settings, Account,
Privacy, activity sheet and detail, snow day / replay / compare, track setup, live tracking,
finish sheets, Go hub sheet, duration and date pickers, dialogs, menus, snackbars, switches,
sliders, segmented controls, text fields, progress spinners, empty and error states) uses the new
look.

**Why this priority**: the owner explicitly asked for no leftover of the old style.

**Independent Test**: visit every route and open every sheet, dialog and menu on the emulator;
none shows old green, iOS grey, pill or rounded-card styling.

**Acceptance Scenarios**:

1. **Given** any dialog, menu, snackbar or picker, **When** it opens, **Then** it is a square
   surface block with chalk text, yellow for its confirm action and readable red for destructive
   ones.
2. **Given** a chart (weekly bars, line charts, steps), **When** it renders, **Then** it uses
   plate colors, the current period in yellow, and square bar ends.
3. **Given** a GPS or snowboard route, **When** it is drawn, **Then** the speed heatmap runs
   blue → green → yellow → orange → red (plate order), lifts are muted, start/finish markers are
   square.
4. **Given** a session in progress, **When** the live indicator shows, **Then** it is safety
   orange, distinct from the yellow accent and from red.
5. **Given** the set milestone reward, **When** it plays, **Then** its colors are yellow, chalk
   and plate green (no mint or old green).

---

### User Story 3 - Share picture, launcher icon and splash (Priority: P2)

The shared workout / route / snow picture, the home-screen launcher icon and the start-up splash
carry the new identity.

**Why this priority**: these leave the app; leftovers here are the most visible to others.

**Independent Test**: share each card type, open the PNG, and look at the launcher and splash on
the emulator.

**Acceptance Scenarios**:

1. **Given** a gym, route or snow share, **When** the picture is generated, **Then** it uses
   soot / surface / chalk, condensed uppercase headings, plate metric colors and the yellow
   accent, at the same sizes and aspect ratios as before.
2. **Given** the app is installed, **When** the launcher shows, **Then** the icon is a yellow
   square-capped chevron-and-bar mark on soot (adaptive icon included).
3. **Given** a cold start, **When** the splash shows, **Then** its background is soot with the
   same mark.

---

### User Story 4 - Owner review on the emulator before release (Priority: P1)

Before any merge to main or APK release, the owner can run the new build on the local Android
emulator, try every flow and send rejects that get fixed on the same branch.

**Why this priority**: explicit owner gate.

**Independent Test**: the branch build runs on the `fitapp_sim` emulator with demo data available.

**Acceptance Scenarios**:

1. **Given** implementation is done and checks pass, **When** the build is launched on the
   emulator, **Then** the owner can use it with hot reload available for quick fixes.
2. **Given** the owner has not approved, **When** work is complete, **Then** nothing is merged to
   main, pushed to main, version-bumped or released.

### Edge Cases

- Long exercise or template names in a condensed uppercase face must still wrap or ellipsize
  without overflow, at the system's largest font scale.
- Big numbers in the display face (timers, weights, steppers) must keep fixed-width digits so
  values do not jitter.
- Text that used the old metric red/blue as small text must switch to the readable tints.
- Map tiles themselves come from the map provider and are not recolored; only app-drawn layers
  (route, markers, overlays, controls) follow the palette.
- The photo backdrop stays but its scrims become soot-tinted, with no green glow.
- The user's saved data, settings and synced content are unaffected.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: All colors MUST come from the Iron plate palette in the direction table; no old
  palette value (`#000000` background, `#1C1C1E`, `#2C2C2E`, `#8E8E93`, `#5A5A5F`, `#11D16C`,
  `#2BE07F`, `#7CF5B0`, `#64D2FF`, `#FF9F0A`, `#FF453A`, `#FFD60A`, `#14261C`) may remain in the
  app, its share pictures, its launcher icon or its splash.
- **FR-002**: Yellow MUST be the single accent for primary actions, the active tab, the current
  set and selection; text and icons on yellow MUST be soot.
- **FR-003**: Metric colors MUST be sets = red, reps = green, volume = blue, weight = plate white,
  used everywhere a metric is colored (numbers, chart lines, bars, share picture).
- **FR-004**: All body and label text MUST reach at least 4.5:1 contrast against its background;
  plate red and plate blue MUST only be used for fills, rails and large display numbers, with the
  readable tints used for smaller text.
- **FR-005**: Titles, exercise names, section headers, tags and the Go label MUST use the
  condensed display face in capitals; big and ticking numbers MUST use the condensed numeric face
  with fixed-width digits; everything else MUST use the body face. Both faces MUST be
  packaged with the app (it works offline) and MUST also be used on the share picture.
- **FR-006**: Corners MUST be square (≤ 2 dp) on cards, sheets, dialogs, menus, buttons, chips,
  inputs, snackbars, check boxes, steppers, bars and the Go action; no pill or circular shapes
  remain except where a circle carries meaning on a map or chart (none are planned).
- **FR-007**: Primary cards MUST carry a 4 dp yellow top rule; grouped lists MUST use 1 dp rules;
  sections MAY use a 2 dp rule.
- **FR-008**: All icons MUST come from one heavy, sharp-cornered outline set (about 2.5 dp stroke,
  square caps), including activity glyphs and the play glyph on Go.
- **FR-009**: The photo backdrop MUST keep working with soot-tinted scrims.
- **FR-010**: Charts, route heatmaps, live tracking panels, the reward animation and the share
  picture MUST follow FR-001 to FR-008.
- **FR-011**: The launcher icon (including the adaptive icon) and the splash screen MUST use the
  new mark and soot background.
- **FR-012**: Behavior, layout structure, tap targets (≥ 48 dp, steppers 56×60), semantics labels,
  haptics and the fixed footer MUST be unchanged; this feature changes only the look.
- **FR-013**: The PRD visual identity section MUST be rewritten to describe the Iron plate look
  and its tokens, and the active-feature pointer updated.
- **FR-014**: Delivery MUST stop at a branch build running on the local emulator; merging,
  pushing main, version bumping and APK release MUST wait for the owner's explicit approval.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A search of the app source, share picture code, launcher and splash configuration
  finds zero old palette values and zero stock rounded icons.
- **SC-002**: 100% of screens, sheets, dialogs and menus reachable in the app show the new look
  during the owner's emulator walk-through.
- **SC-003**: Every text/background pair in the palette used for body text meets 4.5:1.
- **SC-004**: The full gym flow (open, Go, log 3 sets, rest, finish) takes the same number of taps
  as before.
- **SC-005**: All existing automated checks (format, analyze, tests) pass.
- **SC-006**: The owner approves the look on the emulator before release.

## Assumptions

- Always-dark stays; no light theme.
- The constitution's look rules (always dark, one accent, a fixed color per metric, fixed-width
  digits, tokens only) still hold; only PRD §2.2 values change, so no constitution amendment is
  needed.
- Map tiles from the provider are not restyled (both existing map styles stay selectable).
- The photo backdrop images stay; only their overlays change.
- Haptic patterns and sounds are unchanged.
- The two typefaces are free to bundle (SIL Open Font License); their licence texts ship with the
  app.
