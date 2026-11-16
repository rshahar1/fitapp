import 'package:fitapp/domain/tracking/geo.dart';
import 'package:fitapp/domain/tracking/live_route.dart';
import 'package:flutter_test/flutter_test.dart';

/// A point [meters] north of the origin.
GeoPoint north(double meters) => (lat: meters / 111194.93, lon: 0);

void main() {
  test('short tracks keep every point, even identical ones', () {
    final r = LiveRoute();
    for (var i = 0; i < 100; i++) {
      r.add(north(i.isEven ? 0 : 1), i);
    }
    expect(r.length, 100);
    expect(r.spacingMeters, 0);
    expect(r.points, hasLength(100));
  });

  test('past the limit it halves and then spaces new points out', () {
    final r = LiveRoute(maxPoints: 10, firstSpacingMeters: 10);
    for (var i = 0; i <= 10; i++) {
      r.add(north(i * 3.0), i);
    }
    // 11 points: even positions 0,2,..,10 are kept.
    expect(r.length, 6);
    expect(r.spacingMeters, 10);
    expect(r.points.first, north(0));
    expect(r.points.last, north(30));
    r
      ..add(north(33), 11) // 3 m from the last: skipped
      ..add(north(39), 12) // 9 m: skipped
      ..add(north(41), 13); // 11 m: kept
    expect(r.length, 7);
    expect(r.points.last, north(41));
  });

  test('never exceeds the limit over a long track; spacing doubles', () {
    final r = LiveRoute(maxPoints: 50, firstSpacingMeters: 10);
    for (var i = 0; i < 20000; i++) {
      r.add(north(i * 5.0), i);
      expect(r.length, lessThanOrEqualTo(50));
    }
    expect(r.spacingMeters, greaterThan(10));
    expect(r.points.first, north(0));
  });

  test('the newest point survives a halving at an odd position', () {
    final r = LiveRoute(maxPoints: 3);
    for (var i = 0; i < 4; i++) {
      r.add(north(i * 20.0), i);
    }
    expect(r.points, [north(0), north(40), north(60)]);
  });

  test('clear starts over', () {
    final r = LiveRoute(maxPoints: 4);
    for (var i = 0; i < 6; i++) {
      r.add(north(i * 20.0), i);
    }
    r.clear();
    expect(r.length, 0);
    expect(r.spacingMeters, 0);
  });

  group('spans', () {
    test('maps tag ranges to point ranges; neighbours share a point', () {
      final r = LiveRoute();
      for (var i = 0; i < 10; i++) {
        r.add(north(i * 10.0), i);
      }
      expect(r.spans([(first: 2, last: 5), (first: 5, last: 8)]), [
        (from: 2, to: 5),
        (from: 5, to: 8),
      ]);
    });

    test('works on thinned tags and skips ranges under two points', () {
      final r = LiveRoute();
      for (final tag in [0, 4, 8, 12, 16, 20]) {
        r.add(north(tag * 10.0), tag);
      }
      expect(
        r.spans([
          (first: 1, last: 3), // no point
          (first: 4, last: 6), // one point
          (first: 7, last: 17), // 8, 12, 16
          (first: 30, last: 40), // beyond the end
        ]),
        [(from: 2, to: 4)],
      );
      expect(r.spans(const []), isEmpty);
      expect(LiveRoute().spans([(first: 0, last: 5)]), isEmpty);
    });
  });
}
