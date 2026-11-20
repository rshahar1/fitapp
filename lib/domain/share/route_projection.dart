/// Projection of a GPS route onto a drawing area (feature 027). Pure Dart.
library;

import 'dart:math' as math;

import 'package:fitapp/domain/tracking/geo.dart';

/// A point on the drawing area, origin top-left, y pointing down.
typedef ScreenPoint = ({double x, double y});

/// Projects [points] into a [width] × [height] box inset by [padding]:
/// north up, east right, the aspect ratio kept (longitude scaled by the cosine
/// of the mean latitude) and the route centred on the shorter axis. A route
/// that never moves is drawn in the centre.
List<ScreenPoint> projectRoute(
  List<GeoPoint> points, {
  required double width,
  required double height,
  double padding = 0,
}) {
  if (points.isEmpty) return const [];
  var minLat = points.first.lat;
  var maxLat = minLat;
  var minLon = points.first.lon;
  var maxLon = minLon;
  for (final p in points) {
    minLat = math.min(minLat, p.lat);
    maxLat = math.max(maxLat, p.lat);
    minLon = math.min(minLon, p.lon);
    maxLon = math.max(maxLon, p.lon);
  }
  final cosLat = math.cos((minLat + maxLat) / 2 * math.pi / 180);
  final w = (maxLon - minLon) * cosLat;
  final h = maxLat - minLat;
  final availW = math.max(width - 2 * padding, 0);
  final availH = math.max(height - 2 * padding, 0);
  final double scale;
  if (w <= 0 && h <= 0) {
    scale = 0;
  } else if (w <= 0) {
    scale = availH / h;
  } else if (h <= 0) {
    scale = availW / w;
  } else {
    scale = math.min(availW / w, availH / h);
  }
  final offX = (width - w * scale) / 2;
  final offY = (height - h * scale) / 2;
  return [
    for (final p in points)
      (
        x: offX + (p.lon - minLon) * cosLat * scale,
        y: offY + (maxLat - p.lat) * scale,
      ),
  ];
}
