import 'dart:math' as math;

import 'package:fitapp/domain/share/route_projection.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fits inside the padded box', () {
    final out = projectRoute(
      [(lat: 0, lon: 0), (lat: 0.01, lon: 0.02), (lat: 0.02, lon: 0.01)],
      width: 300,
      height: 200,
      padding: 10,
    );
    expect(out, hasLength(3));
    for (final p in out) {
      expect(p.x, inInclusiveRange(10 - 1e-9, 290 + 1e-9));
      expect(p.y, inInclusiveRange(10 - 1e-9, 190 + 1e-9));
    }
  });

  test('north is up and east is right', () {
    final out = projectRoute(
      [(lat: 0, lon: 0), (lat: 0.01, lon: 0.01)],
      width: 100,
      height: 100,
      padding: 0,
    );
    expect(out[1].x, greaterThan(out[0].x));
    expect(out[1].y, lessThan(out[0].y));
  });

  test('keeps the aspect ratio with a cos(lat) correction', () {
    // At 60° N a degree of longitude is half as long as a degree of
    // latitude, so equal degree spans draw twice as tall as wide.
    final out = projectRoute(
      [(lat: 60, lon: 10), (lat: 60.01, lon: 10.01)],
      width: 400,
      height: 400,
      padding: 0,
    );
    final w = (out[1].x - out[0].x).abs();
    final h = (out[1].y - out[0].y).abs();
    expect(h / w, closeTo(1 / math.cos(60.005 * math.pi / 180), 0.01));
    expect(h, closeTo(400, 1e-6));
  });

  test('is centred on the shorter axis', () {
    final out = projectRoute(
      [(lat: 0, lon: 0), (lat: 0, lon: 0.01)],
      width: 200,
      height: 100,
      padding: 0,
    );
    expect(out[0].y, closeTo(50, 1e-9));
    expect(out[0].x, closeTo(0, 1e-9));
    expect(out[1].x, closeTo(200, 1e-9));
  });

  test('a route standing on one spot is drawn in the centre', () {
    final out = projectRoute(
      [(lat: 1, lon: 1), (lat: 1, lon: 1)],
      width: 100,
      height: 60,
      padding: 5,
    );
    expect(out.every((p) => p.x == 50 && p.y == 30), isTrue);
  });

  test('empty in, empty out', () {
    expect(projectRoute(const [], width: 10, height: 10), isEmpty);
  });
}
