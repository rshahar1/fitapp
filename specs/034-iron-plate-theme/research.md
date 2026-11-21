# Research: Iron Plate Visual Identity

## R1 — Capitals without changing strings

- **Decision**: build a derived font `PlateDisplay` from Big Shoulders Display whose lowercase code
  points map to the capital glyphs; static 800 and 900 instances.
- **Rationale**: Flutter has no `text-transform`. Upper-casing strings at call sites would change
  semantics labels and break dozens of `find.text` tests. Big Shoulders Display is SIL OFL 1.1
  with no Reserved Font Name, so a renamed derivative is allowed.
- **Alternatives**: `smcp`+`c2sc` font features (small caps are visibly shorter, must be set on
  every style); `.toUpperCase()` everywhere (semantic and test churn).

## R2 — Fixed-width digits

- **Decision**: numbers use Barlow Condensed (has `tnum`); Barlow body text keeps the existing
  `tabular` feature where it was used.
- **Rationale**: Big Shoulders Display has no `tnum` and proportional digits (the "1" is about half
  as wide), so timers and steppers would jitter. Barlow Condensed ExtraBold has the same
  condensed industrial voice and real tabular figures.
- **Alternatives**: fixed-width boxes per digit (layout hacks); keep Big Shoulders for static
  numbers only (two number faces looked inconsistent).

## R3 — Icon set

- **Decision**: `material_symbols_icons` 4.2960.0, **Sharp** style, weight 600, fill 0, optical size
  24, mapped through one `AppIcons` class.
- **Rationale**: sharp corners and square terminals match the plate geometry; variable weight
  gives the heavy ≈ 2.5 dp stroke; maintained, null-safe, Google's successor to the built-in
  icons (constitution IV); tree-shaken in release builds.
- **Alternatives**: Lucide / Tabler (round caps, against the direction); a custom icon font (cost).

## R4 — Shapes

- **Decision**: `Radii.card = 2`, chips and blocks 0, no circles or stadiums; check marks become
  solid squares; Go becomes a 56 × 48 dp yellow rectangle.
- **Rationale**: owner-approved direction; the 2 dp softening avoids aliasing on large cards.

## R5 — Contrast

Measured (WCAG 2.x): chalk/soot 15.0, chalk/surface 13.6, muted/surface 5.5, muted/surfaceHigh
4.75, yellow/surface 10.4, soot-on-yellow 11.5, green/surface 6.6, safety orange/surface 5.8,
plate red/surface 3.9 and plate blue/surface 4.3 (fills and ≥ 24 sp numbers only), readable red
`#FF6A5C` 6.0 and readable blue `#6FA0FF` 6.6 for smaller text, tertiary `#7A7064` 3.5 (graphics
only).

## R6 — Launcher icon and splash

- **Decision**: draw the mark with a Swift CoreGraphics script (`tool/draw_launcher_icon.swift`,
  no third-party image tools on this machine), then regenerate with the existing
  `flutter_launcher_icons` and `flutter_native_splash` configs (colors → `#15120F`).

## R7 — Map tiles

- **Decision**: tiles stay as delivered by the provider; only app-drawn layers follow the palette.
