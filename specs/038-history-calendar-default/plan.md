# Implementation Plan: History Opens on Calendar, No "template plan" Label

**Branch**: `038-history-calendar-default` | **Date**: 2026-11-21 | **Spec**: [spec.md](./spec.md)

## Summary

UI-only change. No domain, schema, sync or dependency change.

## Design

1. `lib/features/history/history_screen.dart`: `HistoryViewNotifier.build` returns
   `HistoryView.calendar`; Calendar segment first, List second.
2. `lib/features/workout/widgets/exercise_card.dart`: subtitle drops the `template plan` part.
3. Tests: History list tests switch to List first; steps card tests expect the calendar default;
   template UI test asserts no `template plan` text.
4. PRD §5.4 / §5.x / changelog v2.24; CLAUDE.md active feature.
