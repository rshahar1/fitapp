# Tasks: Share a Workout as an Image

**Input**: [plan.md](./plan.md), [spec.md](./spec.md), [data-model.md](./data-model.md),
[contracts/ui-share.md](./contracts/ui-share.md)

**Tests**: required by the constitution (principle III): domain tests are written first.

## Phase 1: Setup

- [x] T001 Add `share_plus` ^13.3.1 to `pubspec.yaml` (`flutter pub add share_plus`)
- [x] T002 [P] Amend `.specify/memory/constitution.md` to 1.9.0 (VI, VII, Technology: image sharing through the OS share sheet, owner request 2026-11-20)

## Phase 2: Foundational

- [x] T003 [P] Write failing tests for `projectRoute` in `test/domain/share/route_projection_test.dart` (fits padding box, keeps aspect ratio with cos(lat), single-point/degenerate routes centred)
- [x] T004 Implement `projectRoute` in `lib/domain/share/route_projection.dart`
- [x] T005 [P] Write failing tests for the shared stat rules in `test/domain/share/share_card_test.dart` ("omit null/≤0 values", pace/speed only when distance and duration > 0)
- [x] T006 Implement `ShareStat`, `ShareLayout`, `ShareCardData` and helpers in `lib/domain/share/share_card.dart`
- [x] T007 [P] `ImageSharer` interface, `SharePlusImageSharer` (temp PNG + `SharePlus.instance.share`) and `imageSharerProvider` in `lib/core/image_sharer.dart`
- [x] T008 [P] Share-card tokens (canvas 360×450, pixel ratio 3) in `lib/app/theme/tokens.dart`
- [x] T009 `ShareCardView` frame (header, footer "FitApp", stat grid for 0–6 stats) in `lib/features/share/share_card_view.dart` and `ShareRoutePainter` in `lib/features/share/share_route_painter.dart`
- [x] T010 `SharePreviewScreen` (load, preview in `RepaintBoundary` + `FittedBox`, capture `pixelRatio: 3`, share, SnackBar "Could not share the image.", empty state "Nothing to share") in `lib/features/share/share_preview_screen.dart`; routes `/share/workout/:id` and `/share/activity/:id` in `lib/app/router.dart`

## Phase 3: User Story 1 – run or ride with route (P1)

**Independent test**: GPS run → Share → route + pace card → share sheet gets one PNG.

- [x] T011 [US1] Tests: route layout for running (distance, avg pace, duration, moving time, climb, best km) and cycling (avg speed) in `test/domain/share/share_card_test.dart`
- [x] T012 [US1] `activityShareCard` route layout in `lib/domain/share/share_card.dart`
- [x] T013 [US1] Share icon (tooltip "Share activity") in `lib/features/activities/activity_detail_screen.dart`
- [x] T014 [US1] Widget test: route card renders, Share image calls the fake sharer with PNG bytes, in `test/features/share_test.dart`

## Phase 4: User Story 2 – gym workout (P1)

- [x] T015 [US2] Tests: exercise lines ("3 × 8 · 60 kg", "3 sets · top 85 kg × 5", bodyweight "3 × 12", per-hand "20 kg each", ≤ 7 lines else 6 + "+N more exercises") and totals in `test/domain/share/share_card_test.dart`
- [x] T016 [US2] `workoutShareCard` + `exerciseShareLine` in `lib/domain/share/share_card.dart`
- [x] T017 [US2] Strength layout in `lib/features/share/share_card_view.dart`
- [x] T018 [US2] Share icon on finished read-only workout in `lib/features/workout/workout_screen.dart`; "Share workout" choice in `lib/features/workout/widgets/finish_summary_sheet.dart` (go Train then push share)
- [x] T019 [US2] Widget tests (long list, entry points) in `test/features/share_test.dart`

## Phase 5: User Story 3 – snowboarding day (P1)

- [x] T020 [US3] Tests: snow layout (breakdown ride/lift/rest, top speed, vertical, runs, ride distance, total time, longest run), manual snowboarding → basic, in `test/domain/share/share_card_test.dart`
- [x] T021 [US3] Snow layout in `lib/domain/share/share_card.dart`
- [x] T022 [US3] Heat-coloured route + ride/lift/rest bar in `lib/features/share/share_card_view.dart`
- [x] T023 [US3] Widget test for the snow card in `test/features/share_test.dart`

## Phase 6: User Story 4 – other activities (P2)

- [x] T024 [US4] Tests: pilates/functional duration only; manual run distance + pace, no route; empty entry → no stats + "Logged in FitApp"; unknown type → "Activity", in `test/domain/share/share_card_test.dart`
- [x] T025 [US4] Basic layout in `lib/domain/share/share_card.dart` and `lib/features/share/share_card_view.dart`

## Phase 7: Polish

- [x] T026 [P] PRD v2.13 (§5.11 Sharing, §6 screens, decision log, changelog) in `docs/PRD-fitapp-flutter.md`; `docs/ARCHITECTURE.md`; README roadmap
- [x] T027 `dart format --set-exit-if-changed .`, `flutter analyze`, `flutter test`; mark spec Implemented; commit

## Dependencies

Setup → Foundational → US1/US2/US3/US4 (independent of each other; they share
`share_card.dart`, so run them in sequence) → Polish.

## Parallel examples

T002, T003, T005, T007, T008 touch different files; T026 can run alongside any story.

## Implementation strategy

MVP = Foundational + US1; then US2, US3, US4, each a shippable increment.
