---
description: "Task list for photo backdrop"
---

# Tasks: Photo Backdrop

**Tests**: semantics/hit-testing widget test (constitution III); visual approval by the owner.

## Phase 1: Setup

- [x] T001 Owner chooses the source photo after reviewing previews (Pexels 6389516, "whole barbell" layout)
- [x] T002 Write tool/make_backdrop.py (Pillow) producing assets/images/backdrop_fill.jpg (blur 30, brightness 30 %, fog 8 %) and assets/images/backdrop_band.jpg (full width, blur 6, brightness 55 %, fog 8 %), ≤ 300 KB together; record source/author/license in assets/images/BACKDROP_LICENSE.md; register `assets/images/` in pubspec.yaml

## Phase 2: User Story 1 – Photo behind every screen (P1)

- [x] T003 [US1] Widget test: AppBackdrop shows an Image layer that is excluded from semantics and ignores pointers; child content stays on top — in test/app/backdrop_test.dart
- [x] T004 [US1] Compose fill (cover) + feathered band (screen width, barbell at 60 % height) + header wash + bottom darkening from tokens; remove grid, curve and glow — in lib/app/backdrop.dart and lib/app/theme/tokens.dart
- [x] T005 [US1] Precache the image before the first frame (no black flash) in lib/app/app.dart; make sure AppBar, NavigationBar and the workout footer use opaque AppColors.background

## Phase 3: Polish

- [ ] T006 Update README (assets + license note); format/analyze/test; build APK; owner approves on the phone (README, gates and APK done; owner approval on the phone pending)
