/// Sanity check of a captured share image (feature 030). Pure Dart.
library;

import 'dart:typed_data';

/// Sample points per side of the grid checked by [isBlankImage].
const _grid = 8;

/// Whether the raw RGBA image ([width] × [height], 4 bytes per pixel) is
/// blank: every sampled pixel (an 8 × 8 grid, the centre and the four
/// corners) is fully transparent. A capture taken before the card was
/// painted comes back like that; a real card is opaque everywhere. Empty
/// or truncated data also counts as blank.
bool isBlankImage(Uint8List rgba, {required int width, required int height}) {
  if (width <= 0 || height <= 0 || rgba.length < width * height * 4) {
    return true;
  }
  bool opaque(int x, int y) => rgba[(y * width + x) * 4 + 3] != 0;
  final points = <(int, int)>[
    (0, 0),
    (width - 1, 0),
    (0, height - 1),
    (width - 1, height - 1),
    (width ~/ 2, height ~/ 2),
    for (var i = 0; i < _grid; i++)
      for (var j = 0; j < _grid; j++)
        (
          ((i + 0.5) * width / _grid).floor(),
          ((j + 0.5) * height / _grid).floor(),
        ),
  ];
  for (final (x, y) in points) {
    if (opaque(x, y)) return false;
  }
  return true;
}
