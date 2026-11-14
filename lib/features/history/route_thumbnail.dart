import 'dart:math' as math;

import 'package:fitapp/app/theme/tokens.dart';
import 'package:fitapp/domain/tracking/geo.dart';
import 'package:material_ui/material_ui.dart';

final _decoded = <String, List<GeoPoint>?>{};
const _cacheLimit = 64;

/// Decodes [route] once per distinct string (small memo). Null when absent,
/// malformed or too short to draw (fewer than 2 points).
List<GeoPoint>? decodeRouteOrNull(String? route) {
  if (route == null || route.isEmpty) return null;
  if (_decoded.containsKey(route)) return _decoded[route];
  List<GeoPoint>? points;
  try {
    final p = decodePolyline(route);
    points = p.length >= 2 ? p : null;
  } on Object {
    points = null;
  }
  if (_decoded.length >= _cacheLimit) _decoded.remove(_decoded.keys.first);
  return _decoded[route] = points;
}

/// A tiny, tile-free drawing of a route on a rounded theme surface.
class RouteThumbnail extends StatelessWidget {
  /// Creates a thumbnail of [points] (at least two).
  const new({required this.points, this.size = Sizes.tap - Space.s, super.key});

  /// Decoded route.
  final List<GeoPoint> points;

  /// Side length of the square.
  final double size;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.surfaceHigh,
            borderRadius: BorderRadius.circular(Radii.chip),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(Radii.chip),
            child: CustomPaint(painter: _ThumbnailPainter(points)),
          ),
        ),
      ),
    );
  }
}

class _ThumbnailPainter extends CustomPainter {
  const new(this.points);

  final List<GeoPoint> points;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2 || size.isEmpty) return;
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
    const pad = Space.s;
    final availW = math.max(size.width - 2 * pad, 1);
    final availH = math.max(size.height - 2 * pad, 1);
    final scale = (w <= 0 && h <= 0)
        ? 1.0
        : math.min(
            w <= 0 ? double.infinity : availW / w,
            h <= 0 ? double.infinity : availH / h,
          );
    final offX = (size.width - w * scale) / 2;
    final offY = (size.height - h * scale) / 2;
    Offset at(GeoPoint p) => Offset(
      offX + (p.lon - minLon) * cosLat * scale,
      offY + (maxLat - p.lat) * scale,
    );
    final path = Path()..moveTo(at(points.first).dx, at(points.first).dy);
    for (final p in points.skip(1)) {
      final o = at(p);
      path.lineTo(o.dx, o.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_ThumbnailPainter old) => old.points != points;
}
