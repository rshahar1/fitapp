---
description: "Task list for photo backdrop"
---

# Tasks: Photo Backdrop

**Tests**: semantics/hit-testing widget test (constitution III); visual approval by the owner.

## Phase 1: Setup

- [ ] T001 Owner chooses the source photo after reviewing previews (blocking)
- [ ] T002 Write tool/make_backdrop.py (Pillow): cover-crop to 1080×2340, Gaussian blur, darken so max luminance ≤ 25 %, 15 % fog toward #1C1C1E, JPEG ≤ 300 KB → assets/images/backdrop.jpg; record source/author/license in assets/images/BACKDROP_LICENSE.md; register `assets/images/` in pubspec.yaml

## Phase 2: User Story 1 – Photo behind every screen (P1)

- [ ] T003 [US1] Widget test: AppBackdrop shows an Image layer that is excluded from semantics and ignores pointers; child content stays on top — in test/app/backdrop_test.dart
- [ ] T004 [US1] Draw the photo (BoxFit.cover, cacheWidth from MediaQuery) + top/bottom dark gradient scrim from tokens; keep only the subtle accent glow; remove grid and curve — in lib/app/backdrop.dart and lib/app/theme/tokens.dart
- [ ] T005 [US1] Precache the image before the first frame (no black flash) in lib/app/app.dart; make sure AppBar, NavigationBar and the workout footer use opaque AppColors.background

## Phase 3: Polish

- [ ] T006 Update README (assets + license note); format/analyze/test; build APK; owner approves on the phone
