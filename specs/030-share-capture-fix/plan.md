# Implementation Plan: Share Capture Fix

**Branch**: `030-share-capture-fix` | **Date**: 2026-11-21 | **Spec**: [spec.md](./spec.md)

## Summary

Freeze the preview's card data on first load, wait for a painted frame before capturing, verify
the capture is not transparent (retry up to 3 times), and drop the caption for gym shares.

## Constitution Check

The blank check (`isBlankImage`) and the caption rule (`shareCaptionFor`) are pure Dart in
`lib/domain/share/` with tests first (II, III). No schema, sync, dependency or privacy change.

## Design

1. `lib/domain/share/share_card.dart`: `shareCaptionFor(ShareCardData)` returns null for
   `ShareLayout.strength`, otherwise `shareCaption`. New `lib/domain/share/image_check.dart`:
   `isBlankImage(Uint8List rgba, {required int width, required int height})` samples a grid of
   pixels (plus the four corners) and returns true when every sampled alpha is 0.
2. `lib/features/share/share_preview_screen.dart`: keep the first non-null card in state
   (`_frozen`) and render it; capture loop: `await WidgetsBinding.instance.endOfFrame`, `toImage`,
   read raw RGBA, `isBlankImage` → retry after the next frame, at most 3 attempts; then encode
   PNG and share with `text: shareCaptionFor(data)`.
3. Tests: domain tests for both functions; widget test that a database write after the preview
   opens does not change the shared image and that gym shares pass no text.
4. Docs: PRD changelog (v2.16).
