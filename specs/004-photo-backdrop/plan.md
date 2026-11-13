# Implementation Plan: Photo Backdrop

**Branch**: `004-photo-backdrop` | **Date**: 2026-11-13 | **Spec**: [spec.md](./spec.md)

## Summary

Bundle two pre-processed images made from the chosen photo and compose them at runtime so the
layout adapts to every screen shape: (1) `backdrop_fill.jpg` — the photo heavily blurred (r≈30) and
darkened (~30 %), drawn full-screen with `BoxFit.cover`; (2) `backdrop_band.jpg` — the full-width
photo lightly blurred (r≈6) at ~55 % brightness, drawn at screen width and positioned so the barbell
(56.7 % down the photo) lands at 60 % of the screen height, with 180 dp feathered top/bottom edges
(ShaderMask). On top: a dark wash behind the header (top ~330 px → transparent) and a bottom
darkening gradient (lower 40 %). Drop the old grid/curve/glow. Pre-cache both images before the
first frame. Navigation bar and workout footer stay opaque black.

## Technical Context

**Language/Version**: Dart 3.14, Flutter 3.50 | **New dependencies**: none

**Assets**: `assets/images/backdrop_fill.jpg` (540×360, q≈75; heavily blurred, so cover-upscaling is invisible) and
`assets/images/backdrop_band.jpg` (1080 wide, q≈80), ≤ 300 KB together, produced by
`tool/make_backdrop.py` (Pillow) from the Pexels source (URL in the script);
`assets/images/BACKDROP_LICENSE.md` records source, author, license.

**Testing**: widget test that AppBackdrop renders an excluded-from-semantics, non-hit-testable
image layer; golden-free. Manual look check on the phone.

**Performance**: single decoded image (cacheWidth = screen width × DPR), `RepaintBoundary`, no
runtime blur (`ImageFilter` avoided for scroll performance).

## Constitution Check

I offline ✅ · II domain untouched ✅ · III test for semantics/hit-testing ✅ · IV theme tokens for
overlay colors ✅ · V readability unchanged, opaque cards ✅ · VI asset license recorded ✅ ·
VII owner-requested scope ✅

## Project Structure

```text
tool/make_backdrop.py                 # reproducible processing (crop, blur, darken, fog)
assets/images/backdrop_{fill,band}.jpg # processed assets
assets/images/BACKDROP_LICENSE.md     # source + license
lib/app/backdrop.dart                 # image layer + gradient (+ optional glow)
lib/app/theme/tokens.dart             # backdropScrim colors
lib/main.dart or lib/app/app.dart     # precacheImage before first frame
test/app/backdrop_test.dart
```
