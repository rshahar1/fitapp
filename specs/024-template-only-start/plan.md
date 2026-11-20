# Implementation Plan: Template-Only Gym Start

**Branch**: `024-template-only-start` | **Date**: 2026-11-20 | **Spec**: [spec.md](./spec.md)

## Summary

Remove the empty gym start from the Train hero. The hero renders only while a session is in
progress (Continue). `StartActions.startGym` becomes `startTemplate(context, templateId)` with a
required id. No schema, dependency, domain or sync change.

## Technical Context

**Language/Version**: Dart 3.14, Flutter 3.50 (unchanged) · **New dependencies**: none ·
**Storage**: unchanged · **Testing**: widget tests updated; e2e flow starts from a seeded template.

## Constitution Check

UI-only removal; domain untouched (no new pure-Dart logic, so no test-first domain work). PRD §5.5
updated to match (docs follow what was built).

## Design

1. `lib/features/start/start_actions.dart`: `startGym({String? templateId})` →
   `startTemplate(BuildContext, String templateId)`; drop the `WorkoutRepository.startWorkout()`
   branch (the repository method stays: templates and tests use it).
2. `lib/features/train/train_screen.dart`: `_HeroCard` returns `SizedBox.shrink()` when
   `inProgress == null`; drop the "Ready to train?" title and the start button branch (the button
   is always Continue: live variant, play icon). Template cards call `startTemplate`. Update the
   doc comments.
3. Tests: `test/features/train_screen_test.dart` empty state expects no "Ready to train?" / "START
   GYM WORKOUT"; `test/features/start_hub_test.dart` drops the one-tap gym start test (template
   one-tap test already covers it); `test/e2e/workout_flow.dart` seeds a template with no exercises
   or with a different exercise, starts it via START, then continues with ADD EXERCISE as before.
4. `docs/PRD-fitapp-flutter.md` §5.5 hero text; bump PRD version note if the PRD keeps a changelog.
