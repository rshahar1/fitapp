# Implementation Plan: Go Button & Template Rows Polish

**Branch**: `033-go-button-polish` | **Date**: 2026-11-21 | **Spec**: [spec.md](./spec.md)

## Summary

UI-only change in two widgets. No domain, schema, sync or dependency change; constitution
unaffected.

## Design

1. `lib/features/shell/shell_scaffold.dart` `_GoButton`: a 56 dp accent circle whose child is a
   centred column (play icon 26 dp, "Go" 11 sp w700, `AppColors.onAccent`); the caption below
   the circle is removed.
2. `lib/features/start/start_hub_sheet.dart`: template `GroupRow` loses its `subtitle`.
3. Tests in `test/features/start_hub_test.dart`: "Go" text is a descendant of the circle; the
   sheet shows no exercise names of a template.
4. PRD v2.19 §5.9 + changelog.
