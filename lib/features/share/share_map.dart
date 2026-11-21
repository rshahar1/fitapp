import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:fitapp/app/theme/tokens.dart';
import 'package:fitapp/domain/share/map_tiles.dart';
import 'package:fitapp/domain/tracking/geo.dart';
import 'package:fitapp/features/tracking/widgets/route_map.dart'
    show MapStyle, mapTilesEnabledProvider;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// Map tiles drawn under a shared route (feature 035): the [view] the route
/// is projected with and every tile image that loaded.
class ShareMapImages {
  const new({required this.view, required this.tiles});

  final TileView view;
  final List<({MapTile tile, ui.Image image})> tiles;

  /// Frees the tile images.
  void dispose() {
    for (final t in tiles) {
      t.image.dispose();
    }
  }
}

/// Fetches the bytes of one tile, or null when it cannot be loaded.
typedef TileFetcher = Future<Uint8List?> Function(Uri url);

/// Longest wait for the tiles of one share image.
const shareTilesTimeout = Duration(seconds: 8);

Future<Uint8List?> _httpFetch(Uri url) async {
  final client = HttpClient()..userAgent = 'com.fitapp.app';
  try {
    final req = await client.getUrl(url);
    final res = await req.close();
    if (res.statusCode != HttpStatus.ok) return null;
    final builder = BytesBuilder(copy: false);
    await res.forEach(builder.add);
    return builder.takeBytes();
  } on Object {
    return null;
  } finally {
    client.close(force: true);
  }
}

/// How tiles are fetched; tests override it.
final tileFetcherProvider = Provider<TileFetcher>((ref) => _httpFetch);

/// Loads the map behind [route] for a [width] × [height] box in [style], or
/// null when map tiles are off or none loaded. Waits at most
/// [shareTilesTimeout]; tiles that fail are left out.
Future<ShareMapImages?> loadShareMap(
  Ref ref, {
  required List<GeoPoint> route,
  required double width,
  required double height,
  required MapStyle style,
}) async {
  if (route.length < 2 || !ref.read(mapTilesEnabledProvider)) return null;
  final fetch = ref.read(tileFetcherProvider);
  final view = fitTileView(
    route,
    width: width,
    height: height,
    padding: Space.m,
  );

  Future<({MapTile tile, ui.Image image})?> one(MapTile t) async {
    final bytes = await fetch(style.retinaTile(t.z, t.x, t.y));
    if (bytes == null) return null;
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      codec.dispose();
      return (tile: t, image: frame.image);
    } on Object {
      return null;
    }
  }

  final loaded = <({MapTile tile, ui.Image image})>[];
  var expired = false;
  Future<void> keep(MapTile t) async {
    final r = await one(t);
    if (r == null) return;
    // A tile that arrives after the deadline is freed, never drawn.
    if (expired) {
      r.image.dispose();
    } else {
      loaded.add(r);
    }
  }

  try {
    await Future.wait([for (final t in view.tiles) keep(t)])
        .timeout(shareTilesTimeout);
  } on TimeoutException {
    // Keep what arrived in time.
  }
  expired = true;
  if (loaded.isEmpty) return null;
  return ShareMapImages(view: view, tiles: loaded);
}

/// Inputs of [shareMapProvider]. Compared by identity of the route list,
/// which comes from the frozen share card.
@immutable
class ShareMapRequest {
  const new({
    required this.route,
    required this.width,
    required this.height,
    required this.style,
  });

  final List<GeoPoint> route;
  final double width;
  final double height;
  final MapStyle style;

  @override
  bool operator ==(Object other) =>
      other is ShareMapRequest &&
      identical(other.route, route) &&
      other.width == width &&
      other.height == height &&
      other.style == style;

  @override
  int get hashCode =>
      Object.hash(identityHashCode(route), width, height, style);
}

/// The loaded map of one share preview; freed when the preview closes.
final shareMapProvider = FutureProvider.autoDispose
    .family<ShareMapImages?, ShareMapRequest>((ref, r) async {
      final map = await loadShareMap(
        ref,
        route: r.route,
        width: r.width,
        height: r.height,
        style: r.style,
      );
      // The preview may close while tiles load: free them, never draw them.
      if (!ref.mounted) {
        map?.dispose();
        return null;
      }
      ref.onDispose(() => map?.dispose());
      return map;
    });

/// Paints the tile images of a [ShareMapImages].
class ShareTilesPainter extends CustomPainter {
  const new(this.map);

  final ShareMapImages map;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..filterQuality = FilterQuality.medium;
    for (final (:tile, :image) in map.tiles) {
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        // Half a pixel of overlap hides hairline seams between tiles.
        Rect.fromLTWH(tile.left, tile.top, tile.size + 0.5, tile.size + 0.5),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(ShareTilesPainter old) => !identical(old.map, map);
}
