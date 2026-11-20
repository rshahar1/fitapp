import 'package:fitapp/app/theme/tokens.dart';
import 'package:fitapp/domain/share/route_projection.dart';
import 'package:fitapp/domain/tracking/geo.dart';
import 'package:fitapp/features/tracking/widgets/route_map.dart' show RouteSpan;
import 'package:flutter/foundation.dart' show listEquals;
import 'package:material_ui/material_ui.dart';

/// Draws a route without map tiles for the share image (feature 027): the
/// line in [color], optional coloured [spans] on top (snowboarding speed
/// heatmap and lifts), a start dot and a finish dot.
class ShareRoutePainter extends CustomPainter {
  const new({
    required this.points,
    this.spans = const [],
    this.color = AppColors.accent,
  });

  /// At least two points.
  final List<GeoPoint> points;

  /// Stretches by route index, drawn over the base line.
  final List<RouteSpan> spans;

  /// Base line colour.
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2 || size.isEmpty) return;
    final xy = projectRoute(
      points,
      width: size.width,
      height: size.height,
      padding: Space.m,
    );
    Offset at(int i) => Offset(xy[i].x, xy[i].y);
    Path pathOf(int from, int to) {
      final p = Path()..moveTo(at(from).dx, at(from).dy);
      for (var i = from + 1; i <= to; i++) {
        p.lineTo(at(i).dx, at(i).dy);
      }
      return p;
    }

    Paint stroke(Color c, double width) => Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final all = pathOf(0, xy.length - 1);
    // A soft halo keeps the line readable on any background.
    canvas
      ..drawPath(all, stroke(AppColors.background, Sizes.routeStroke + 3))
      ..drawPath(all, stroke(color, Sizes.routeStroke));
    for (final s in spans) {
      if (s.from < 0 || s.to >= xy.length || s.to <= s.from) continue;
      canvas.drawPath(pathOf(s.from, s.to), stroke(s.color, Sizes.routeStroke));
    }
    void dot(Offset o, Color fill) {
      canvas
        ..drawCircle(
          o,
          Sizes.mapMarker / 2,
          Paint()..color = AppColors.background,
        )
        ..drawCircle(o, Sizes.mapMarker / 2 - 2.5, Paint()..color = fill);
    }

    dot(at(0), AppColors.accent);
    dot(at(xy.length - 1), AppColors.textPrimary);
  }

  @override
  bool shouldRepaint(ShareRoutePainter old) =>
      !listEquals(old.points, points) ||
      !listEquals(old.spans, spans) ||
      old.color != color;
}
