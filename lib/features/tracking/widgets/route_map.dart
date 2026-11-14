import 'dart:math' as math;

import 'package:fitapp/app/theme/tokens.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart' show LatLng;
import 'package:material_ui/material_ui.dart';

/// The MapTiler key, injected with `--dart-define-from-file=env/dev.json`.
const mapTilesKey = String.fromEnvironment('MAP_TILES_KEY');

/// Whether real map tiles are drawn. False without a key; tests override it.
final mapTilesEnabledProvider = Provider<bool>((ref) => mapTilesKey.isNotEmpty);

/// What a [RouteMarker] marks.
enum RouteMarkerKind { start, finish, km }

/// A point of interest drawn on a [RouteMap].
class RouteMarker {
  const new(this.point, this.kind, {this.label});

  final LatLng point;
  final RouteMarkerKind kind;

  /// Short text for km markers (e.g. "3").
  final String? label;
}

/// A recorded route on a dark map (MapTiler tiles when a key exists) or a
/// plain drawing of the route on the theme surface. Never throws for 0 or 1
/// points.
class RouteMap extends ConsumerWidget {
  const new({
    required this.route,
    this.current,
    this.interactive = false,
    this.markers = const [],
    this.fitToRoute = true,
    this.followCurrent = false,
    super.key,
  });

  final List<LatLng> route;

  /// Latest position, drawn as a dot.
  final LatLng? current;
  final bool interactive;
  final List<RouteMarker> markers;

  /// Keep the whole route in view as it grows.
  final bool fitToRoute;

  /// Keep [current] centered.
  final bool followCurrent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tiles = ref.watch(mapTilesEnabledProvider);
    return Semantics(
      container: true,
      label: 'Route map',
      child: ClipRRect(
        borderRadius: const BorderRadius.all(Radius.circular(Radii.card)),
        child: ColoredBox(
          color: AppColors.surface,
          child: tiles
              ? _TileMap(
                  route: route,
                  current: current,
                  interactive: interactive,
                  markers: markers,
                  fitToRoute: fitToRoute,
                  followCurrent: followCurrent,
                )
              : CustomPaint(
                  size: Size.infinite,
                  painter: _RoutePainter(
                    route: route,
                    current: current,
                    markers: markers,
                  ),
                ),
        ),
      ),
    );
  }
}

class _TileMap extends StatefulWidget {
  const new({
    required this.route,
    required this.current,
    required this.interactive,
    required this.markers,
    required this.fitToRoute,
    required this.followCurrent,
  });

  final List<LatLng> route;
  final LatLng? current;
  final bool interactive;
  final List<RouteMarker> markers;
  final bool fitToRoute;
  final bool followCurrent;

  @override
  State<_TileMap> createState() => _TileMapState();
}

class _TileMapState extends State<_TileMap> {
  final _controller = MapController();
  bool _ready = false;

  /// Whether the camera sits on a real point (not the empty world view).
  late bool _placed = _firstPoint != null;

  static const _padding = EdgeInsets.all(Space.l);
  static const _fallbackZoom = 16.0;

  List<LatLng> get _all => [
    ...widget.route,
    if (widget.current != null) widget.current!,
  ];

  LatLng? get _firstPoint => widget.current ?? widget.route.lastOrNull;

  CameraFit? _fit() {
    final all = _all;
    if (all.length < 2) return null;
    return CameraFit.coordinates(coordinates: all, padding: _padding);
  }

  @override
  void didUpdateWidget(_TileMap old) {
    super.didUpdateWidget(old);
    if (!_ready) return;
    _placeCamera();
    final current = widget.current;
    if (widget.followCurrent && current != null && current != old.current) {
      _controller.move(current, _controller.camera.zoom);
    } else if (widget.fitToRoute &&
        !widget.followCurrent &&
        (widget.route.length != old.route.length ||
            widget.current != old.current)) {
      final fit = _fit();
      if (fit != null) {
        _controller.fitCamera(fit);
      } else if (_firstPoint case final p?) {
        _controller.move(p, _fallbackZoom);
      }
    }
  }

  /// Leaves the empty world view once the first real point exists.
  void _placeCamera() {
    if (_placed) return;
    final p = _firstPoint;
    if (p == null) return;
    _placed = true;
    _controller.move(p, _fallbackZoom);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final centre = widget.current ?? widget.route.lastOrNull;
    final fit = widget.followCurrent ? null : _fit();
    return FlutterMap(
      mapController: _controller,
      options: MapOptions(
        initialCenter: centre ?? const LatLng(0, 0),
        initialZoom: centre == null ? 2 : _fallbackZoom,
        initialCameraFit: fit,
        backgroundColor: AppColors.surface,
        onMapReady: () {
          _ready = true;
          if (!_placed) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _placeCamera();
            });
          }
        },
        interactionOptions: InteractionOptions(
          flags: widget.interactive
              ? InteractiveFlag.all & ~InteractiveFlag.rotate
              : InteractiveFlag.none,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate:
              'https://api.maptiler.com/maps/dataviz-dark/256/{z}/{x}/{y}.png'
              '?key=$mapTilesKey',
          userAgentPackageName: 'com.fitapp.app',
          maxNativeZoom: 20,
        ),
        if (widget.route.length >= 2)
          PolylineLayer(
            polylines: [
              Polyline(
                points: widget.route,
                strokeWidth: Sizes.routeStroke,
                color: AppColors.accent,
              ),
            ],
          ),
        MarkerLayer(
          markers: [
            for (final m in widget.markers)
              Marker(
                point: m.point,
                width: Sizes.mapMarker * 2,
                height: Sizes.mapMarker * 2,
                child: _Dot(kind: m.kind, label: m.label),
              ),
            if (widget.current != null)
              Marker(
                point: widget.current!,
                width: Sizes.mapMarker,
                height: Sizes.mapMarker,
                child: const _Dot(kind: RouteMarkerKind.finish),
              ),
          ],
        ),
        const SimpleAttributionWidget(
          source: Text('© MapTiler © OpenStreetMap contributors'),
          backgroundColor: AppColors.backdropBottomScrim,
        ),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  const new({required this.kind, this.label});

  final RouteMarkerKind kind;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final color = switch (kind) {
      RouteMarkerKind.start => AppColors.textPrimary,
      RouteMarkerKind.finish => AppColors.accent,
      RouteMarkerKind.km => AppColors.surfaceHigh,
    };
    return Center(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color,
          shape: kind == RouteMarkerKind.km
              ? BoxShape.rectangle
              : BoxShape.circle,
          borderRadius: kind == RouteMarkerKind.km
              ? const BorderRadius.all(Radius.circular(Radii.chip))
              : null,
          border: Border.all(),
        ),
        child: SizedBox(
          width: kind == RouteMarkerKind.km ? null : Sizes.mapMarker,
          height: Sizes.mapMarker,
          child: label == null
              ? null
              : Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Space.xs),
                  child: Text(
                    label!,
                    style: Theme.of(context).textTheme.labelSmall
                        ?.copyWith(color: AppColors.textPrimary),
                  ),
                ),
        ),
      ),
    );
  }
}

/// Draws the route fitted to the box (equirectangular projection).
class _RoutePainter extends CustomPainter {
  const new({
    required this.route,
    required this.current,
    required this.markers,
  });

  final List<LatLng> route;
  final LatLng? current;
  final List<RouteMarker> markers;

  @override
  void paint(Canvas canvas, Size size) {
    final pts = [...route, ?current, for (final m in markers) m.point];
    if (pts.isEmpty || size.isEmpty) return;
    var minLat = pts.first.latitude;
    var maxLat = minLat;
    var minLon = pts.first.longitude;
    var maxLon = minLon;
    for (final p in pts) {
      minLat = math.min(minLat, p.latitude);
      maxLat = math.max(maxLat, p.latitude);
      minLon = math.min(minLon, p.longitude);
      maxLon = math.max(maxLon, p.longitude);
    }
    final cosLat = math.cos((minLat + maxLat) / 2 * math.pi / 180);
    final w = (maxLon - minLon) * cosLat;
    final h = maxLat - minLat;
    const pad = Space.l;
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
    Offset at(LatLng p) => Offset(
      offX + (p.longitude - minLon) * cosLat * scale,
      offY + (maxLat - p.latitude) * scale,
    );

    if (route.length >= 2) {
      final path = Path()..moveTo(at(route.first).dx, at(route.first).dy);
      for (final p in route.skip(1)) {
        final o = at(p);
        path.lineTo(o.dx, o.dy);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = AppColors.accent
          ..style = PaintingStyle.stroke
          ..strokeWidth = Sizes.routeStroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }
    void dot(LatLng p, Color color) {
      canvas
        ..drawCircle(
          at(p),
          Sizes.mapMarker / 2 + 2,
          Paint()..color = AppColors.background,
        )
        ..drawCircle(at(p), Sizes.mapMarker / 2, Paint()..color = color);
    }

    if (route.isNotEmpty) dot(route.first, AppColors.textPrimary);
    final end = current ?? (route.length > 1 ? route.last : null);
    if (end != null) dot(end, AppColors.accent);
  }

  @override
  bool shouldRepaint(_RoutePainter old) =>
      old.route.length != route.length ||
      old.current != current ||
      old.markers.length != markers.length ||
      (route.isNotEmpty && old.route.last != route.last);
}
