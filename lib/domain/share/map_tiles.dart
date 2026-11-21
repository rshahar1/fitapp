/// Web Mercator tile maths for the map behind a shared route (feature 035).
/// Pure Dart.
library;

import 'dart:math' as math;

import 'package:fitapp/domain/share/route_projection.dart' show ScreenPoint;
import 'package:fitapp/domain/tracking/geo.dart';

/// Pixels per side of one map tile at its own zoom (logical pixels; the
/// image itself may be a 2× tile).
const tilePixels = 256.0;

/// Web Mercator stops here; beyond it tiles do not exist.
const _maxLat = 85.05112878;

/// One map tile and where it lands in the drawing area (origin top-left).
typedef MapTile = ({int x, int y, int z, double left, double top, double size});

/// A map view of a drawing area: the fitted (fractional) [zoom], the whole
/// [tileZoom] whose tiles are drawn scaled by [tileScale], and the world pixel
/// at the area's top-left corner.
class TileView {
  const new _({
    required this.zoom,
    required this.tileZoom,
    required this.width,
    required this.height,
    required this._originX,
    required this._originY,
  });

  /// Fitted zoom (may be fractional).
  final double zoom;

  /// Zoom level of the tiles that are drawn.
  final int tileZoom;

  /// Size of the drawing area.
  final double width;
  final double height;

  final double _originX;
  final double _originY;

  /// Scale applied to each [tilePixels] tile: 2^(zoom − tileZoom).
  double get tileScale => math.pow(2, zoom - tileZoom).toDouble();

  double get _worldSize => tilePixels * math.pow(2, zoom);

  /// Where [p] lands in the drawing area.
  ScreenPoint project(GeoPoint p) {
    final (u, v) = _mercator(p);
    return (x: u * _worldSize - _originX, y: v * _worldSize - _originY);
  }

  /// Every tile that overlaps the drawing area, row by row. Columns wrap
  /// round the antimeridian; rows outside the world are left out.
  List<MapTile> get tiles {
    final size = tilePixels * tileScale;
    final n = 1 << tileZoom;
    final x0 = (_originX / size).floor();
    final x1 = ((_originX + width) / size).ceil() - 1;
    final y0 = math.max((_originY / size).floor(), 0);
    final y1 = math.min(((_originY + height) / size).ceil() - 1, n - 1);
    return [
      for (var ty = y0; ty <= y1; ty++)
        for (var tx = x0; tx <= x1; tx++)
          (
            x: tx % n,
            y: ty,
            z: tileZoom,
            left: tx * size - _originX,
            top: ty * size - _originY,
            size: size,
          ),
    ];
  }
}

/// Fits [points] into a [width] × [height] area inset by [padding], centred,
/// north up, at a zoom between [minZoom] and [maxZoom]. A route that never
/// moves is centred at [maxZoom].
TileView fitTileView(
  List<GeoPoint> points, {
  required double width,
  required double height,
  double padding = 0,
  int minZoom = 3,
  int maxZoom = 17,
}) {
  assert(points.isNotEmpty, 'fitTileView needs at least one point');
  var minU = double.infinity;
  var maxU = -double.infinity;
  var minV = double.infinity;
  var maxV = -double.infinity;
  for (final p in points) {
    final (u, v) = _mercator(p);
    minU = math.min(minU, u);
    maxU = math.max(maxU, u);
    minV = math.min(minV, v);
    maxV = math.max(maxV, v);
  }
  final du = maxU - minU;
  final dv = maxV - minV;
  final availW = math.max(width - 2 * padding, 1);
  final availH = math.max(height - 2 * padding, 1);
  final world = math.min(
    du > 0 ? availW / du : double.infinity,
    dv > 0 ? availH / dv : double.infinity,
  );
  final fitted = world.isFinite
      ? math.log(world / tilePixels) / math.ln2
      : maxZoom.toDouble();
  final zoom = fitted.clamp(minZoom.toDouble(), maxZoom.toDouble());
  final tileZoom = zoom.round().clamp(minZoom, maxZoom);
  final worldSize = tilePixels * math.pow(2, zoom);
  return TileView._(
    zoom: zoom,
    tileZoom: tileZoom,
    width: width,
    height: height,
    originX: (minU + maxU) / 2 * worldSize - width / 2,
    originY: (minV + maxV) / 2 * worldSize - height / 2,
  );
}

/// Web Mercator position of [p] in the unit square (0, 0 at the north-west).
(double, double) _mercator(GeoPoint p) {
  final lat = p.lat.clamp(-_maxLat, _maxLat) * math.pi / 180;
  final u = (p.lon + 180) / 360;
  final v = (1 - math.log(math.tan(lat) + 1 / math.cos(lat)) / math.pi) / 2;
  return (u, v);
}
