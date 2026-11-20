# Research: Share a Workout as an Image

## Share sheet plugin
- **Decision**: `share_plus` 13.x (`SharePlus.instance.share(ShareParams(files: [XFile(path)], text: …))`).
- **Rationale**: Flutter Community plugin, current, null-safe, Android + iOS, the de-facto standard;
  handles the `FileProvider` for content URIs.
- **Alternatives**: platform channel with a custom `FileProvider` (more native code, no benefit).

## Producing the image
- **Decision**: render a widget in a `RepaintBoundary` on the preview screen and capture with
  `toImage(pixelRatio: 3)`; fixed 360 × 450 logical canvas inside a `FittedBox`.
- **Rationale**: the user sees exactly what is shared (FR-002); no off-screen pipeline; text and
  theme fonts reuse the app's rendering.
- **Alternatives**: off-screen `PipelineOwner` rendering (fragile, no preview); `screenshot`
  package (extra dependency for the same `RepaintBoundary` call).

## Route on the image
- **Decision**: draw the stored simplified polyline with a `CustomPainter` (equirectangular
  projection with cos(lat) correction, as in `RouteThumbnail`), no map tiles.
- **Rationale**: offline-first, deterministic, no wait for tiles, no tile key in the pipeline,
  no tile licensing/attribution issues on a shared image.
- **Alternatives**: `flutter_map` with tiles captured from the widget (tiles load async, needs the
  network, attribution required) — possible later enhancement.

## Image format
- **Decision**: PNG, 1080 × 1350 (4:5).
- **Rationale**: crisp text; 4:5 is the largest portrait ratio shown uncropped in Instagram feeds
  and displays well in WhatsApp.
