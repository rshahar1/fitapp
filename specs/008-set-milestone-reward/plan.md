# Implementation Plan: Set Milestone Reward Animation

**Branch**: `008-set-milestone-reward` | **Date**: 2026-11-14 | **Spec**: [spec.md](spec.md)

## Summary

A derived, UI-only reward on the exercise card. A pure domain rule decides when sets 1 and 2 hit
the plan's target reps; the card detects the false → true transition in a live workout and plays a
neon bodybuilder + firework overlay, then shows a persistent pill beside "Add Set".

**No data-model changes**: nothing is stored or migrated, so no `data-model.md` is needed.

## Technical Context

Flutter stable, Dart 3, Riverpod 3, Material 3 built-ins. Rendering with `CustomPainter`, one
`AnimationController`, `OverlayEntry` + `IgnorePointer`, `HapticFeedback.heavyImpact`/success.
No new packages.

## Design

- Domain: `firstTwoSetsHitTarget({int? targetReps, int? set1Reps, int? set2Reps})` in
  `lib/domain/milestones.dart`: true only when all three are present and both reps >= target.
- Transition: `exercise_card.dart` remembers the previous rule value (initialised from the first
  build, so opening never plays). On false → true while the workout is live (not edit mode) and
  `!MediaQuery.disableAnimations`, it asks the burst overlay to play. The pill is shown whenever
  the rule is true.
- Burst overlay (`OverlayEntry`, wrapped in `IgnorePointer`): centered over the set table via the
  table's render box; scrim 65% black fading out at the end; one burst at a time (static guard);
  removed on completion and on dispose.
- Figure painter: line-art upper body in a double-biceps pose, strokes in accent with
  `MaskFilter.blur` glow, fills in the surface color; three pumps scale biceps, delts and pecs with
  growing glow, shake and strain lines; flash and collapse at 1.4 s.
- Firework painter: 60 sparks with trails, crackling sub-sparks, a shockwave ring, plus two
  smaller side bursts using mint and gold highlights.
- Timeline (about 3 s): pop-in 0-380 ms, pumps to 1.3 s, flash/collapse at 1.4 s, burst and haptic,
  scrim fade, pill.
- Pill: small figure icon + "Target hit · sets 1–2" on the right of the Add Set row, inside the
  existing row so nothing shifts; `Semantics(liveRegion: true, label: 'Target hit for sets 1 and 2')`.
- Tokens in `lib/app/theme/tokens.dart` : `accentBright` #2BE07F,
  `mint` #7CF5B0, `gold` #FFD60A, `rewardIconFill` #14261C; accent stays #11D16C.

## Constitution Check

- I Offline-first: nothing persisted, no schema change. PASS
- II Pure domain: the rule lives in `lib/domain/` with tests first; no Flutter imports. PASS
- III Tests first: domain tests, then widget tests for burst/pill/transition cases. PASS
- IV Layering: no DB access in widgets; colors from tokens. PASS
- V UX: overlay never blocks taps; no layout shift (pill in the existing row); Semantics label;
  48 dp targets unchanged; reduced motion respected. PASS
- VII Scope: no sound, no other sets, no history, no toggle. PASS

## Project Structure (touched)

```text
lib/domain/milestones.dart                              (new) firstTwoSetsHitTarget
lib/app/theme/tokens.dart                               accentBright, mint, gold, rewardIconFill, rewardScrim
lib/features/workout/widgets/reward/                    (new)
  muscle_figure.dart                                   bodybuilder painter
  reward_burst.dart                                    firework + scrim + timeline overlay
  target_hit_pill.dart                                      "Target hit · sets 1–2" pill
lib/features/workout/widgets/exercise_card.dart         transition detection, pill, overlay
test/domain/milestones_test.dart                        (new)
test/features/set_milestone_reward_test.dart            (new)
```
