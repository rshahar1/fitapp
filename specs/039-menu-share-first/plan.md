# Implementation Plan: Share First in the Finished Session ⋮ Menu

**Branch**: `039-menu-share-first` | **Date**: 2026-11-21 | **Spec**: [spec.md](./spec.md)

## Summary

UI-only change. No domain, schema, sync or dependency change.

## Design

1. `lib/features/workout/workout_screen.dart`: Share item before Edit workout.
2. `lib/features/activities/activity_detail_screen.dart`: Share item before Edit activity.
3. `test/features/edit_mode_test.dart`: assert the Share, Edit, Delete order.
4. PRD §5.4 / §15 / changelog v2.25; CLAUDE.md active feature.
