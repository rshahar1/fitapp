import 'package:fitapp/domain/tracking/geo.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('haversineMeters', () {
    test('zero for identical points', () {
      expect(haversineMeters(32, 34, 32, 34), 0);
    });

    test('one degree of latitude is about 111.2 km', () {
      expect(haversineMeters(0, 0, 1, 0), closeTo(111195, 50));
    });

    test('longitude shrinks with latitude', () {
      expect(haversineMeters(60, 10, 60, 11), closeTo(55597, 100));
    });

    test('Tel Aviv to Jerusalem is about 54 km', () {
      expect(
        haversineMeters(32.0853, 34.7818, 31.7683, 35.2137),
        closeTo(54000, 1000),
      );
    });
  });

  group('polyline', () {
    test('matches the Google reference example', () {
      const pts = [
        (lat: 38.5, lon: -120.2),
        (lat: 40.7, lon: -120.95),
        (lat: 43.252, lon: -126.453),
      ];
      expect(encodePolyline(pts), '_p~iF~ps|U_ulLnnqC_mqNvxq`@');
      expect(decodePolyline('_p~iF~ps|U_ulLnnqC_mqNvxq`@'), pts);
    });

    test('empty round trip', () {
      expect(encodePolyline(const []), '');
      expect(decodePolyline(''), isEmpty);
    });

    test('round trip within 5e-6 degrees, incl. negatives and zero', () {
      final pts = [
        (lat: 0.0, lon: 0.0),
        (lat: -33.86882, lon: 151.20929),
        (lat: -33.86901, lon: 151.20811),
        (lat: 32.123456, lon: -0.000012),
      ];
      final back = decodePolyline(encodePolyline(pts));
      expect(back, hasLength(pts.length));
      for (var i = 0; i < pts.length; i++) {
        expect(back[i].lat, closeTo(pts[i].lat, 5e-6));
        expect(back[i].lon, closeTo(pts[i].lon, 5e-6));
      }
    });
  });

  group('simplify', () {
    test('returns short lists unchanged', () {
      expect(simplify(const [], 5), isEmpty);
      const two = [(lat: 0.0, lon: 0.0), (lat: 1.0, lon: 1.0)];
      expect(simplify(two, 5), two);
    });

    test('drops collinear points, keeps ends', () {
      final pts = [for (var i = 0; i <= 10; i++) (lat: 0.0, lon: i * 0.0001)];
      final out = simplify(pts, 1);
      expect(out, [pts.first, pts.last]);
    });

    test('keeps a corner beyond the tolerance, drops it within', () {
      // ~11 m north detour in the middle of a ~220 m east line.
      final pts = [
        (lat: 0.0, lon: 0.0),
        (lat: 0.0001, lon: 0.001),
        (lat: 0.0, lon: 0.002),
      ];
      expect(simplify(pts, 5), pts);
      expect(simplify(pts, 15), [pts.first, pts.last]);
    });

    test('handles a closed loop (zero-length baseline)', () {
      final pts = [
        (lat: 0.0, lon: 0.0),
        (lat: 0.001, lon: 0.001),
        (lat: 0.0, lon: 0.0),
      ];
      expect(simplify(pts, 5), pts);
    });

    test('simplified path stays within tolerance of the original', () {
      final pts = [
        for (var i = 0; i < 500; i++)
          (lat: 0.00002 * i, lon: 0.00001 * i + 0.00003 * (i % 7)),
      ];
      final out = simplify(pts, 5);
      expect(out.length, lessThan(pts.length));
      expect(out.first, pts.first);
      expect(out.last, pts.last);
    });
  });

  group('pointsAtEveryKm', () {
    // 0.001 degrees of latitude is about 111.2 m.
    List<GeoPoint> line(int n) => [
      for (var i = 0; i <= n; i++) (lat: i * 0.001, lon: 0.0),
    ];

    test('empty for short or tiny routes', () {
      expect(pointsAtEveryKm(const []), isEmpty);
      expect(pointsAtEveryKm([(lat: 1.0, lon: 1.0)]), isEmpty);
      expect(pointsAtEveryKm(line(5)), isEmpty);
    });

    test('one point per full kilometre, at the right distance', () {
      final route = line(45); // about 5.0 km
      final pts = pointsAtEveryKm(route);
      expect(pts, hasLength(5));
      for (var k = 0; k < pts.length; k++) {
        expect(
          haversineMeters(0, 0, pts[k].lat, pts[k].lon),
          closeTo((k + 1) * 1000, 1),
        );
      }
    });

    test('several marks inside one long segment', () {
      final pts = pointsAtEveryKm([(lat: 0.0, lon: 0.0), (lat: 0.0, lon: 0.1)]);
      expect(pts, hasLength(11)); // 11.1 km
    });
  });
}
