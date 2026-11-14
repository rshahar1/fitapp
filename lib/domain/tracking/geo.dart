/// Geometry helpers for GPS tracks (feature 010). Pure Dart.
library;

import 'dart:math' as math;

/// A latitude/longitude pair in degrees.
typedef GeoPoint = ({double lat, double lon});

const _earthRadiusMeters = 6371008.8;

double _rad(double deg) => deg * math.pi / 180;

/// Great-circle distance in metres between two coordinates (haversine).
double haversineMeters(double lat1, double lon1, double lat2, double lon2) {
  final dLat = _rad(lat2 - lat1);
  final dLon = _rad(lon2 - lon1);
  final a =
      math.pow(math.sin(dLat / 2), 2) +
      math.cos(_rad(lat1)) *
          math.cos(_rad(lat2)) *
          math.pow(math.sin(dLon / 2), 2);
  return 2 * _earthRadiusMeters * math.asin(math.sqrt(a));
}

/// Encodes [points] as a Google encoded polyline with 5-digit precision.
String encodePolyline(Iterable<GeoPoint> points) {
  final out = StringBuffer();
  var prevLat = 0;
  var prevLon = 0;
  for (final p in points) {
    final lat = (p.lat * 1e5).round();
    final lon = (p.lon * 1e5).round();
    _encodeValue(lat - prevLat, out);
    _encodeValue(lon - prevLon, out);
    prevLat = lat;
    prevLon = lon;
  }
  return out.toString();
}

void _encodeValue(int delta, StringBuffer out) {
  var v = delta < 0 ? ~(delta << 1) : delta << 1;
  while (v >= 0x20) {
    out.writeCharCode((0x20 | (v & 0x1f)) + 63);
    v >>= 5;
  }
  out.writeCharCode(v + 63);
}

/// Decodes a Google encoded polyline (precision 5).
List<GeoPoint> decodePolyline(String encoded) {
  final points = <GeoPoint>[];
  var i = 0;
  var lat = 0;
  var lon = 0;
  int next() {
    var result = 0;
    var shift = 0;
    int b;
    do {
      b = encoded.codeUnitAt(i++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    return result.isOdd ? ~(result >> 1) : result >> 1;
  }

  while (i < encoded.length) {
    lat += next();
    lon += next();
    points.add((lat: lat / 1e5, lon: lon / 1e5));
  }
  return points;
}

/// Douglas-Peucker simplification with [toleranceMeters], computed in a local
/// equirectangular projection. Keeps the first and last point.
List<GeoPoint> simplify(List<GeoPoint> points, double toleranceMeters) {
  if (points.length < 3) return List.of(points);
  final lat0 = points.map((p) => p.lat).reduce((a, b) => a + b) / points.length;
  final kx = _earthRadiusMeters * math.cos(_rad(lat0)) * math.pi / 180;
  const ky = _earthRadiusMeters * math.pi / 180;
  final xs = [for (final p in points) p.lon * kx];
  final ys = [for (final p in points) p.lat * ky];

  double distToSegment(int i, int a, int b) {
    final dx = xs[b] - xs[a];
    final dy = ys[b] - ys[a];
    final len2 = dx * dx + dy * dy;
    var t = 0.0;
    if (len2 > 0) {
      t = (((xs[i] - xs[a]) * dx + (ys[i] - ys[a]) * dy) / len2).clamp(
        0.0,
        1.0,
      );
    }
    final px = xs[a] + t * dx - xs[i];
    final py = ys[a] + t * dy - ys[i];
    return math.sqrt(px * px + py * py);
  }

  final keep = List.filled(points.length, false);
  keep[0] = true;
  keep[points.length - 1] = true;
  final stack = <(int, int)>[(0, points.length - 1)];
  while (stack.isNotEmpty) {
    final (a, b) = stack.removeLast();
    var maxD = -1.0;
    var idx = -1;
    for (var i = a + 1; i < b; i++) {
      final d = distToSegment(i, a, b);
      if (d > maxD) {
        maxD = d;
        idx = i;
      }
    }
    if (idx != -1 && maxD > toleranceMeters) {
      keep[idx] = true;
      stack
        ..add((a, idx))
        ..add((idx, b));
    }
  }
  return [
    for (var i = 0; i < points.length; i++)
      if (keep[i]) points[i],
  ];
}
