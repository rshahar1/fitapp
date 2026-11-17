// Rebuilds tool/val_thorens/geometry.json: the lift lines and pistes of the
// simulated Val Thorens session, with terrain elevations.
//
//   dart run tool/val_thorens/fetch_geometry.dart
//
// Sources (see tool/val_thorens/README.md for licences and attribution):
//  * way geometry: OpenStreetMap through the Overpass API (ODbL 1.0)
//  * elevations: IGN RGE ALTI through the Géoplateforme altimetry service
//    (Licence Ouverte / Open Licence 2.0)
//
// Only public coordinates are sent, with a generic User-Agent. The result is
// committed, so the fixture generator works offline and deterministically.
// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

const _userAgent = 'osm-geometry-fetch/1.0';
const _overpass = [
  'https://overpass-api.de/api/interpreter',
  'https://overpass.kumi.systems/api/interpreter',
];
const _altimetry =
    'https://data.geopf.fr/altimetrie/1.0/calcul/alti/rest/elevation.json';

/// Distance between two elevation samples along a leg, in metres.
const _spacing = 12.0;

/// One OSM way of a leg, walked in its own direction. [untilNext] cuts it
/// at the node closest to the start of the following way.
class _Part {
  const new(this.way, {this.untilNext = false});

  final int way;
  final bool untilNext;
}

class _Leg {
  const new(this.id, this.kind, this.name, this.parts);

  final String id;

  /// 'lift', 'run' or 'walk'.
  final String kind;
  final String name;
  final List<_Part> parts;
}

/// The session's legs, in the order they are travelled.
const _legs = [
  _Leg('boismint_lift', 'lift', 'Boismint', [_Part(22463109)]),
  _Leg('boismint_run', 'run', 'Boismint', [
    // Blanchot links the top station to the start of the Boismint piste.
    _Part(47829378, untilNext: true),
    _Part(104703255),
    _Part(104703259),
    _Part(104703252),
    _Part(1463415343),
    _Part(729236076),
    _Part(47829377),
    _Part(107201711),
  ]),
  _Leg('caron_gondola', 'lift', 'Caron', [_Part(22462907)]),
  _Leg('cime_caron_cable_car', 'lift', 'Cime Caron', [_Part(22462908)]),
  _Leg('cime_caron_run', 'run', "Col de l'Audzin / Gentiane", [
    _Part(1222284611),
    _Part(256848047),
    _Part(23455204),
    _Part(31091703),
  ]),
];

typedef _P = ({double lat, double lon});

const _r = 6371008.8;

double _rad(double d) => d * math.pi / 180;

double _haversine(_P a, _P b) {
  final h =
      math.pow(math.sin(_rad(b.lat - a.lat) / 2), 2) +
      math.cos(_rad(a.lat)) *
          math.cos(_rad(b.lat)) *
          math.pow(math.sin(_rad(b.lon - a.lon) / 2), 2);
  return 2 * _r * math.asin(math.sqrt(h));
}

Future<String> _request(
  HttpClient client,
  String method,
  Uri uri, {
  String? body,
}) async {
  final req = await client.openUrl(method, uri);
  req.headers.set(HttpHeaders.userAgentHeader, _userAgent);
  if (body != null) {
    req.headers.contentType = ContentType(
      'application',
      'x-www-form-urlencoded',
      charset: 'utf-8',
    );
    req.write(body);
  }
  final res = await req.close().timeout(const Duration(seconds: 120));
  final text = await utf8.decodeStream(res);
  if (res.statusCode != 200) {
    throw HttpException('HTTP ${res.statusCode} from ${uri.host}');
  }
  return text;
}

Future<Map<int, Map<String, dynamic>>> _fetchWays(HttpClient client) async {
  final ids = {for (final l in _legs) ...l.parts.map((p) => p.way)}.join(',');
  final query = '[out:json][timeout:60];way(id:$ids);out tags geom;';
  Object? last;
  for (final url in _overpass) {
    try {
      final text = await _request(
        client,
        'POST',
        Uri.parse(url),
        body: 'data=${Uri.encodeQueryComponent(query)}',
      );
      final json = jsonDecode(text) as Map<String, dynamic>;
      return {
        for (final e in (json['elements'] as List).cast<Map<String, dynamic>>())
          e['id'] as int: e,
      };
    } on Object catch (e) {
      last = e;
      print('overpass ${Uri.parse(url).host}: $e');
    }
  }
  throw StateError('No Overpass server answered: $last');
}

List<_P> _nodes(Map<String, dynamic> way) => [
  for (final g in (way['geometry'] as List).cast<Map<String, dynamic>>())
    (lat: (g['lat'] as num).toDouble(), lon: (g['lon'] as num).toDouble()),
];

/// Points every [_spacing] metres along [line], ends included.
List<_P> _densify(List<_P> line) {
  final out = <_P>[line.first];
  for (var i = 1; i < line.length; i++) {
    final a = line[i - 1];
    final b = line[i];
    final d = _haversine(a, b);
    if (d < 0.5) continue;
    final n = (d / _spacing).ceil();
    for (var k = 1; k <= n; k++) {
      final f = k / n;
      out.add((
        lat: a.lat + (b.lat - a.lat) * f,
        lon: a.lon + (b.lon - a.lon) * f,
      ));
    }
  }
  return out;
}

Future<List<double>> _elevations(HttpClient client, List<_P> points) async {
  final out = <double>[];
  for (var i = 0; i < points.length; i += 100) {
    final batch = points.sublist(i, math.min(i + 100, points.length));
    final uri = Uri.parse(_altimetry).replace(
      queryParameters: {
        'lon': batch.map((p) => p.lon.toStringAsFixed(6)).join('|'),
        'lat': batch.map((p) => p.lat.toStringAsFixed(6)).join('|'),
        'resource': 'ign_rge_alti_wld',
        'zonly': 'true',
      },
    );
    final json =
        jsonDecode(await _request(client, 'GET', uri)) as Map<String, dynamic>;
    final values = (json['elevations'] as List).cast<num>();
    if (values.length != batch.length || values.any((v) => v < -1000)) {
      throw StateError('Bad elevation answer for batch $i');
    }
    out.addAll(values.map((v) => v.toDouble()));
    await Future<void>.delayed(const Duration(milliseconds: 300));
  }
  return out;
}

Future<void> main() async {
  final client = HttpClient();
  try {
    final ways = await _fetchWays(client);
    final legs = <Map<String, dynamic>>[];
    for (final leg in _legs) {
      final lines = [
        for (final p in leg.parts)
          _nodes(ways[p.way] ?? (throw StateError('way ${p.way} is missing'))),
      ];
      final line = <_P>[];
      for (var i = 0; i < lines.length; i++) {
        var part = lines[i];
        if (leg.parts[i].untilNext) {
          final target = lines[i + 1].first;
          var best = 0;
          for (var k = 1; k < part.length; k++) {
            if (_haversine(part[k], target) < _haversine(part[best], target)) {
              best = k;
            }
          }
          part = part.sublist(0, best + 1);
        }
        if (line.isNotEmpty) {
          final gap = _haversine(line.last, part.first);
          if (gap > 80) throw StateError('${leg.id}: gap of $gap m at part $i');
        }
        line.addAll(part);
      }
      final dense = _densify(line);
      final ele = await _elevations(client, dense);
      final tags = ways[leg.parts.first.way]!['tags'] as Map<String, dynamic>;
      legs.add({
        'id': leg.id,
        'kind': leg.kind,
        'name': leg.name,
        if (leg.kind == 'lift') 'aerialway': tags['aerialway'],
        'osm_ways': [for (final p in leg.parts) p.way],
        'points': [
          for (var i = 0; i < dense.length; i++)
            [
              double.parse(dense[i].lat.toStringAsFixed(6)),
              double.parse(dense[i].lon.toStringAsFixed(6)),
              double.parse(ele[i].toStringAsFixed(1)),
            ],
        ],
      });
      print(
        '${leg.id}: ${dense.length} points, '
        '${ele.first.toStringAsFixed(0)} m -> ${ele.last.toStringAsFixed(0)} m',
      );
    }
    final out = StringBuffer()
      ..writeln('{')
      ..writeln('  "place": "Val Thorens, Savoie, France",')
      ..writeln(
        '  "geometry_source": "OpenStreetMap contributors, ODbL 1.0, '
        'https://www.openstreetmap.org/copyright",',
      )
      ..writeln(
        '  "elevation_source": "IGN RGE ALTI, Licence Ouverte 2.0, '
        'https://geoservices.ign.fr/rgealti",',
      )
      ..writeln('  "point_format": "[lat, lon, terrain elevation in m]",')
      ..writeln('  "legs": [');
    for (var i = 0; i < legs.length; i++) {
      final leg = Map<String, dynamic>.of(legs[i]);
      final points = leg.remove('points') as List;
      final head = jsonEncode(leg);
      out
        ..writeln('    ${head.substring(0, head.length - 1)},"points":[')
        ..writeAll([for (final p in points) '      ${jsonEncode(p)}'], ',\n')
        ..writeln()
        ..writeln('    ]}${i == legs.length - 1 ? '' : ','}');
    }
    out
      ..writeln('  ]')
      ..writeln('}');
    File('tool/val_thorens/geometry.json').writeAsStringSync(out.toString());
    print('wrote tool/val_thorens/geometry.json');
  } finally {
    client.close(force: true);
  }
}
