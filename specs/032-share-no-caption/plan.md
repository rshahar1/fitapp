# Implementation Plan: No Caption on Any Share

**Branch**: `032-share-no-caption` | **Date**: 2026-11-21 | **Spec**: [spec.md](./spec.md)

## Summary

Remove the `text` parameter from `ImageSharer.sharePng` and its `share_plus` implementation,
remove `shareCaption` / `shareCaptionFor` from `lib/domain/share/share_card.dart` and stop
passing text from the preview screen. No schema, sync or dependency change; constitution
unaffected (less data leaves the app).

## Design

1. `lib/core/image_sharer.dart`: `sharePng(bytes, {required fileName})`; `ShareParams(files:)`.
2. `lib/domain/share/share_card.dart`: delete the caption helpers.
3. `lib/features/share/share_preview_screen.dart`: no text argument.
4. Tests: drop caption tests; fake sharer has no text; activity and gym share tests still pass.
5. PRD v2.18 §5.11 + changelog.
