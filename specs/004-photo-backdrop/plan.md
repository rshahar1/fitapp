# Implementation Plan: Photo Backdrop

**Branch**: `004-photo-backdrop` | **Date**: 2026-11-13 | **Spec**: [spec.md](./spec.md)

## Summary

Bundle one pre-processed background photo (portrait crop, Gaussian blur, darkened to ≤ 25 %
luminance, light "fog" toward #1C1C1E) and draw it in `AppBackdrop` behind every screen with
`BoxFit.cover`, under a subtle top-to-bottom dark gradient. Keep the accent glow only if it still
reads well; drop the grid and curve. Pre-cache the image before the first frame. App bars, the
bottom navigation bar and the workout footer stay opaque black.

## Technical Context

**Language/Version**: Dart 3.14, Flutter 3.50 | **New dependencies**: none

**Asset**: `assets/images/backdrop.jpg` (1080×2340, JPEG q≈80, ≤ 300 KB) produced by
`tool/make_backdrop.py` (Pillow) from the source photo; `assets/images/BACKDROP_LICENSE.md`
records source, author, license.

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
assets/images/backdrop.jpg            # processed asset
assets/images/BACKDROP_LICENSE.md     # source + license
lib/app/backdrop.dart                 # image layer + gradient (+ optional glow)
lib/app/theme/tokens.dart             # backdropScrim colors
lib/main.dart or lib/app/app.dart     # precacheImage before first frame
test/app/backdrop_test.dart
```
