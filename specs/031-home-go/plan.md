# Implementation Plan: Home & Go

**Branch**: `031-home-go` | **Date**: 2026-11-21 | **Spec**: [spec.md](./spec.md)

## Summary

UI-only: template start rows move into the hub sheet (renamed Go), the Train screen is relabelled
Home and loses its Templates section, the "+" becomes a Go play button. No domain, schema, sync or
dependency change.

## Constitution Check

No domain logic changes (II, III untouched). Tokens reused (IV). Go keeps a ≥ 48 dp target and
an accessibility label; template rows are labelled (V). No privacy or scope change (VI, VII).

## Design

1. **Hub** `start_hub_sheet.dart`: title "Go"; new `TemplateChoice(templateId)` and
   `CreateTemplateChoice`; rows from `templatesProvider` after the Continue row (gym icon,
   `name`, exercises joined with " · ", semantics "Start <name> template"); empty → "Create a gym
   template" (`Routes.templates`). `showStartHub` dispatches to `StartActions.startTemplate` /
   `push(Routes.templates)`.
2. **Shell** `shell_scaffold.dart`: tab label Home; `_PlusButton` → `_GoButton`, label "Go",
   `Icons.play_arrow_rounded`, small "Go" caption under the circle within the 72 dp bar.
3. **Home** `train_screen.dart`: title Home; remove the Templates section, `_TemplateCard` and
   unused imports.
4. **Text**: "Back to Home" (workout, live track), privacy text, doc comments.
5. **Tests**: update `start_hub_test`, `templates_test`, `train_screen_test` and other "Train"
   expectations; add hub template start, blocked start and empty-state tests.
6. **Docs**: PRD §5.5, §5.9, navigation tree, changelog; CLAUDE.md active feature; README.
