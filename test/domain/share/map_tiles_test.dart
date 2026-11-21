import 'dart:math' as math;

import 'package:fitapp/domain/share/map_tiles.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // About 2 km across central Tel Aviv.
  const city = [
    (lat: 32.0700, lon: 34.7700),
    (lat: 32.0800, lon: 34.7800),
    (lat: 32.0850, lon: 34.7750),
  ];

  test('the route fits inside the padded box', () {
    final v = fitTileView(city, width: 312, height: 168, padding: 16);
    for (final p in city) {
      final s = v.project(p);
      expect(s.x, inInclusiveRange(16 - 1e-6, 296 + 1e-6));
      expect(s.y, inInclusiveRange(16 - 1e-6, 152 + 1e-6));
    }
  });

  test('the tighter axis touches the padding (fills the box)', () {
    final v = fitTileView(city, width: 312, height: 168, padding: 16);
    final ys = city.map((p) => v.project(p).y);
    final top = ys.reduce(math.min);
    final bottom = ys.reduce(math.max);
    // A tall-ish route in a wide box: height decides.
    expect(bottom - top, closeTo(168 - 32, 1e-6));
  });

  test('north is up and east is right', () {
    final v = fitTileView(city, width: 300, height: 200);
    final a = v.project(city[0]);
    final b = v.project(city[1]);
    expect(b.x, greaterThan(a.x));
    expect(b.y, lessThan(a.y));
  });

  test('the tile zoom is a whole number near the fitted zoom', () {
    final v = fitTileView(city, width: 312, height: 168, padding: 16);
    expect(v.tileZoom, inInclusiveRange(3, 17));
    expect(v.tileScale, inInclusiveRange(math.sqrt1_2 - 1e-9, math.sqrt2));
    expect((v.zoom - v.tileZoom).abs(), lessThanOrEqualTo(0.5 + 1e-9));
  });

  test('tiles cover the whole box without gaps', () {
    final v = fitTileView(city, width: 312, height: 168, padding: 16);
    final tiles = v.tiles;
    expect(tiles, isNotEmpty);
    expect(tiles.length, lessThanOrEqualTo(20));
    for (final t in tiles) {
      expect(t.size, closeTo(256 * v.tileScale, 1e-9));
    }
    // Sample points across the box: each falls in some tile.
    for (var x = 0.0; x <= 312; x += 13) {
      for (var y = 0.0; y <= 168; y += 7) {
        final hit = tiles.any(
          (t) =>
              x >= t.left - 1e-9 &&
              x <= t.left + t.size + 1e-9 &&
              y >= t.top - 1e-9 &&
              y <= t.top + t.size + 1e-9,
        );
        expect(hit, isTrue, reason: '($x, $y) not covered');
      }
    }
  });

  test('the route lies on the same pixels as its tile', () {
    // The tile that holds a point in world coordinates holds it on screen.
    final v = fitTileView(city, width: 312, height: 168, padding: 16);
    final p = city.first;
    final n = 1 << v.tileZoom;
    final tx = ((p.lon + 180) / 360 * n).floor();
    final latR = p.lat * math.pi / 180;
    final ty =
        ((1 - math.log(math.tan(latR) + 1 / math.cos(latR)) / math.pi) / 2 * n)
            .floor();
    final s = v.project(p);
    final t = v.tiles.firstWhere((t) => t.x == tx && t.y == ty);
    expect(s.x, inInclusiveRange(t.left, t.left + t.size));
    expect(s.y, inInclusiveRange(t.top, t.top + t.size));
  });

  test('a route that never moves sits in the centre at the max zoom', () {
    final v = fitTileView(
      [(lat: 51.5, lon: -0.12), (lat: 51.5, lon: -0.12)],
      width: 300,
      height: 160,
    );
    final s = v.project((lat: 51.5, lon: -0.12));
    expect(s.x, closeTo(150, 1e-6));
    expect(s.y, closeTo(80, 1e-6));
    expect(v.zoom, 17);
    expect(v.tileZoom, 17);
  });

  test('a long route is clamped to the min zoom', () {
    final v = fitTileView(
      [(lat: -40, lon: -100), (lat: 60, lon: 120)],
      width: 300,
      height: 160,
    );
    expect(v.zoom, 3);
    expect(v.tileZoom, 3);
  });

  test('tile rows outside the world are skipped and columns wrap', () {
    final v = fitTileView(
      [(lat: 80, lon: 179.9), (lat: 80, lon: 179.95)],
      width: 300,
      height: 300,
      maxZoom: 3,
    );
    final n = 1 << v.tileZoom;
    for (final t in v.tiles) {
      expect(t.y, inInclusiveRange(0, n - 1));
      expect(t.x, inInclusiveRange(0, n - 1));
    }
  });
}
