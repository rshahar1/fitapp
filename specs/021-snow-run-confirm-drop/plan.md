# Implementation Plan: Earlier Run Confirmation Off a Lift

**Branch**: `021-snow-run-confirm-drop` | **Date**: 2026-11-17 | **Spec**: [spec.md](./spec.md)

## Summary

Lower the `SnowTuning.runConfirmDrop` default from 10 m to 6 m so a run that starts on a flat
traverse is shown sooner on the live screen. Applies Finding 1 of feature 019. No new rule, field,
dependency or schema change.

## Technical Context

**Language/Version**: Dart 3.14, Flutter 3.50 (unchanged)

**New dependencies**: none

**Testing**: Val Thorens fixture test and a reducer test, written first.

## Evidence

Feature 019 simulated a day on real OSM/IGN terrain. Both pistes start with about 40 s of
near-level riding at 2.5-6 m/s (Blanchot link off the Boismint chair; Col de l'Audzin ridge below
Cime Caron).

| `runConfirmDrop` | Boismint run | Cime Caron run |
|---|---|---|
| 10 m | 49 s | 63 s |
| 6 m | 36 s | 31 s |

Totals (runs, ride / lift / rest time, drop, distance, max speed) are identical on the Val Thorens
session and on `plainDay` and `longDay`: runs are backdated, only live timing changes.

## Change

`lib/domain/tracking/snow_reducer.dart`: `runConfirmDrop` default 10 → 6. Off a lift, a run is
confirmed after `runConfirm` (10 s) and a net smoothed-altitude drop ≥ `runConfirmDrop`; distance
alone does not count off a lift. From a rest, 10 s and 60 m distance also confirms (unchanged).

Not changed: `runConfirmMeters` (60 m). The 7 s "Riding" flicker at the cable-car start stays a
known limit, pinned by the 019 test "known limit: the cable car start shows a run for under 10 s";
a trade-off to judge on real data.

## Risk

A lift that loses ≥ 6 m net over ≥ 10 s while moving ≥ 2 m/s with climb rate ≤ 0.10 m/s could be
split by a false run (a gondola dipping across a valley). Guarded by a new test; a real ski day
should confirm.

## Tests

| Test | Covers |
|---|---|
| `test/domain/tracking/val_thorens_fixture_test.dart` "a run off a lift on a flat traverse shows within 40 s (021)" | Written first; failed with 49 > 40 before the change |
| `test/domain/tracking/snow_reducer_test.dart` "a lift dipping 5 m between towers stays one lift (021)" | No false run on a dip |

Gates: `dart format --set-exit-if-changed .`, `flutter analyze`, `flutter test` (906 green).

## Files

| File | Change |
|---|---|
| `lib/domain/tracking/snow_reducer.dart` | default 10 → 6 |
| the two test files above | new tests |
| `specs/017-snowboard-live-tracking/plan.md`, `specs/019-snow-sim-val-thorens/plan.md` | cross-references |
| `CLAUDE.md` | active feature |

## Constitution Check

| Principle | Status |
|---|---|
| II. Pure domain: change stays in `lib/domain/`, pure Dart | ✅ |
| III. Tests first: the new fixture test failed before the change | ✅ |
| Other: no new dependency, no data or privacy impact | ✅ |

No constitution change needed.
