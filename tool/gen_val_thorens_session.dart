// Generates the simulated Val Thorens snowboarding session from the cached
// open-data geometry in tool/val_thorens/geometry.json. Offline and
// deterministic:
//
//   dart run tool/gen_val_thorens_session.dart
//       [--csv <file>] [--gpx <file>]
//
// Writes lib/data/tracking/sim/val_thorens_session.dart (the fixture CSV as
// a Dart constant, used by the tests and by the dev-only GPS simulation).
// --csv also writes the plain CSV; --gpx writes a GPX track for route
// playback in the Android emulator.
//
// The session, one fix per second:
//   rest at the Boismint base -> Boismint chairlift -> stand at the top ->
//   run 1 (Blanchot link, Boismint, Boulevard Boismint) -> break at the Caron
//   base -> Caron gondola -> walk and wait at the mid station -> Cime Caron
//   cable car -> stand at the summit -> run 2 (Col de l'Audzin, Gentiane)
//   with one stop on the way -> rest at the Boismint base.
// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

const _r = 6371008.8;
const _lat0 = 45.28;
const _lon0 = 6.56;
const _seed = 2026;
const _outDart = 'lib/data/tracking/sim/val_thorens_session.dart';

double _rad(double d) => d * math.pi / 180;
final _kx = _r * math.cos(_rad(_lat0)) * math.pi / 180;
const _ky = _r * math.pi / 180;

/// A leg's centreline in local metres (x east, y north) with elevation.
class _Line {
  new(List<List<num>> points) {
    for (final p in points) {
      final x = (p[1] - _lon0) * _kx;
      final y = (p[0] - _lat0) * _ky;
      if (xs.isNotEmpty) {
        final d = math.sqrt(
          math.pow(x - xs.last, 2) + math.pow(y - ys.last, 2),
        );
        if (d < 0.01) continue;
        ss.add(ss.last + d);
      } else {
        ss.add(0);
      }
      xs.add(x);
      ys.add(y);
      zs.add(p[2].toDouble());
    }
  }

  final xs = <double>[];
  final ys = <double>[];
  final zs = <double>[];
  final ss = <double>[];

  double get length => ss.last;

  int _seg(double s) {
    var lo = 0;
    var hi = ss.length - 2;
    while (lo < hi) {
      final mid = (lo + hi + 1) ~/ 2;
      if (ss[mid] <= s) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    return lo;
  }

  /// Position, terrain elevation and unit tangent at distance [s].
  ({double x, double y, double z, double tx, double ty}) at(double s) {
    final c = s.clamp(0, length).toDouble();
    final i = _seg(c);
    final d = ss[i + 1] - ss[i];
    final f = (c - ss[i]) / d;
    return (
      x: xs[i] + (xs[i + 1] - xs[i]) * f,
      y: ys[i] + (ys[i + 1] - ys[i]) * f,
      z: zs[i] + (zs[i + 1] - zs[i]) * f,
      tx: (xs[i + 1] - xs[i]) / d,
      ty: (ys[i + 1] - ys[i]) / d,
    );
  }

  /// Terrain elevation averaged over [half] metres either side of [s].
  double smooth(double s, double half) {
    var sum = 0.0;
    const n = 8;
    for (var k = -n; k <= n; k++) {
      sum += at(s + half * k / n).z;
    }
    return sum / (2 * n + 1);
  }
}

enum _Kind { rest, lift, run }

class _Truth {
  new(this.x, this.y, this.alt, this.kind);

  final double x;
  final double y;
  final double alt;

  /// What the rider did during the second ending at this fix.
  final _Kind kind;
}

class _LegSpan {
  new(this.kind, this.name, this.from, this.to);

  final _Kind kind;
  final String name;
  final int from;
  final int to;
}

class _Session {
  new(this.x, this.y, this.alt) {
    truth.add(_Truth(x, y, alt, _Kind.rest));
  }

  double x;
  double y;
  double alt;
  final truth = <_Truth>[];
  final legs = <_LegSpan>[];

  int get now => truth.length - 1;

  void _add(_Kind kind) => truth.add(_Truth(x, y, alt, kind));

  void _leg(_Kind kind, String name, void Function() body) {
    final from = now;
    body();
    legs.add(_LegSpan(kind, name, from, now));
  }

  void stand(String name, int seconds) => _leg(_Kind.rest, name, () {
    for (var i = 0; i < seconds; i++) {
      _add(_Kind.rest);
    }
  });

  /// Walks in a straight line to ([tx], [ty], [talt]), then stands.
  void walk(
    String name,
    double tx,
    double ty,
    double talt, {
    required int thenStand,
    double speed = 1.2,
  }) => _leg(_Kind.rest, name, () {
    final x0 = x;
    final y0 = y;
    final a0 = alt;
    final d = math.sqrt(math.pow(tx - x0, 2) + math.pow(ty - y0, 2));
    final n = math.max(1, (d / speed).ceil());
    for (var i = 1; i <= n; i++) {
      x = x0 + (tx - x0) * i / n;
      y = y0 + (ty - y0) * i / n;
      alt = a0 + (talt - a0) * i / n;
      _add(_Kind.rest);
    }
    for (var i = 0; i < thenStand; i++) {
      _add(_Kind.rest);
    }
  });

  /// A lift ride along [line] at [lineSpeed] m/s, slowing in the stations.
  /// A cable car hangs on a straight cable; chairs and gondolas follow the
  /// terrain a few metres up, evened out by the towers.
  void lift(
    String name,
    _Line line, {
    required double lineSpeed,
    required bool cableCar,
  }) => _leg(_Kind.lift, name, () {
    const accel = 0.6;
    final length = line.length;
    final z0 = line.at(0).z;
    final z1 = line.at(length).z;
    var s = 0.0;
    var v = 0.0;
    while (s < length - 0.05) {
      final brake = math.sqrt(2 * accel * (length - s)) + 0.3;
      v = math.min(math.min(v + accel, lineSpeed), brake);
      s = math.min(length, s + v);
      final p = line.at(s);
      final edge = math.min(1, math.min(s, length - s) / 60);
      final follow = line.smooth(s, 75) + 9 * edge;
      if (cableCar) {
        final f = s / length;
        final cable = z0 + (z1 - z0) * f - 14 * math.sin(math.pi * f);
        alt = math.max(cable, follow);
      } else {
        alt = follow;
      }
      // Ends exactly on the station's ground.
      if (edge < 1) alt = p.z + (alt - p.z) * edge;
      x = p.x;
      y = p.y;
      _add(_Kind.lift);
    }
  });

  /// Riding down [line]: speed follows the slope, with carved turns across
  /// the centreline. Stops for [stopFor] seconds at fraction [stopAt].
  void run(String name, _Line line, {double? stopAt, int stopFor = 0}) {
    final length = line.length;
    final stopS = stopAt == null ? null : stopAt * length;
    var stopped = stopS == null;
    var s = 0.0;
    var v = 0.0;
    var from = now;
    var part = 1;
    const period = 6.5;
    const omega = 2 * math.pi / period;
    var tick = 0;
    void close() {
      final label = stopS == null ? name : '$name (part $part)';
      legs.add(_LegSpan(_Kind.run, label, from, now));
      part++;
    }

    while (s < length - 0.5) {
      tick++;
      final grade = -(line.at(s + 30).z - line.at(s - 30).z) / 60;
      var target = (3.5 + 45 * grade).clamp(2.5, 14.0);
      target = math.min(target, math.max(1, (length - s) / 4));
      if (!stopped) target = math.min(target, math.max(1, (stopS! - s) / 4));
      v += (target - v).clamp(-3.0, 1.5);
      final speed = v * (1 + 0.1 * math.sin(2 * math.pi * tick / 11));
      final amp = math.min(7, 0.45 * speed / omega).toDouble();
      final lateral = amp * omega * math.cos(omega * tick);
      final along = math.sqrt(
        math.max(speed * speed - lateral * lateral, 0.25 * speed * speed),
      );
      s = math.min(length, s + along);
      final p = line.at(s);
      final offset = amp * math.sin(omega * tick);
      x = p.x - p.ty * offset;
      y = p.y + p.tx * offset;
      alt = line.smooth(s, 10);
      _add(_Kind.run);
      if (!stopped && s >= stopS! - 2) {
        stopped = true;
        close();
        stand('$name (stop)', stopFor);
        from = now;
        v = 0;
      }
    }
    // The last metre onto the end of the piste.
    final end = line.at(length);
    x = end.x;
    y = end.y;
    alt = end.z;
    _add(_Kind.run);
    close();
  }
}

/// Slowly drifting noise, like real GPS error: standard deviation [sigma],
/// correlated from one second to the next.
class _Drift {
  new(this._rnd, this.sigma);

  static const _rho = 0.99;
  final math.Random _rnd;
  final double sigma;
  double _v = 0;

  double next() =>
      _v = _rho * _v + math.sqrt(1 - _rho * _rho) * sigma * _gauss(_rnd);
}

double _gauss(math.Random r) {
  final u = 1 - r.nextDouble();
  final v = r.nextDouble();
  return math.sqrt(-2 * math.log(u)) * math.cos(2 * math.pi * v);
}

double _lat(double y) => _lat0 + y / _ky;
double _lon(double x) => _lon0 + x / _kx;

double _haversine(double la1, double lo1, double la2, double lo2) {
  final a =
      math.pow(math.sin(_rad(la2 - la1) / 2), 2) +
      math.cos(_rad(la1)) *
          math.cos(_rad(la2)) *
          math.pow(math.sin(_rad(lo2 - lo1) / 2), 2);
  return 2 * _r * math.asin(math.sqrt(a));
}

String _slug(String name) => name.replaceAll(RegExp("[ ,;:=']+"), '_');

void main(List<String> args) {
  String? option(String name) {
    final i = args.indexOf(name);
    return i >= 0 && i + 1 < args.length ? args[i + 1] : null;
  }

  final json = jsonDecode(
    File('tool/val_thorens/geometry.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final lines = {
    for (final leg in (json['legs'] as List).cast<Map<String, dynamic>>())
      leg['id'] as String: _Line([
        for (final p in leg['points'] as List) (p as List).cast<num>(),
      ]),
  };
  final boismint = lines['boismint_lift']!;
  final run1 = lines['boismint_run']!;
  final gondola = lines['caron_gondola']!;
  final cableCar = lines['cime_caron_cable_car']!;
  final run2 = lines['cime_caron_run']!;

  final base = boismint.at(0);
  final session = _Session(base.x, base.y, base.z)
    ..stand('Boismint base', 75)
    ..lift('Boismint chairlift', boismint, lineSpeed: 5, cableCar: false)
    ..stand('Boismint top', 35)
    ..run('Boismint', run1)
    ..stand('Caron base (break)', 210)
    ..lift('Caron gondola', gondola, lineSpeed: 6, cableCar: false);
  final mid = cableCar.at(0);
  session
    ..walk('Caron mid station', mid.x, mid.y, mid.z, thenStand: 150)
    ..lift('Cime Caron cable car', cableCar, lineSpeed: 8, cableCar: true)
    ..stand('Cime Caron summit', 60)
    ..run("Col de l'Audzin / Gentiane", run2, stopAt: 0.55, stopFor: 45)
    ..stand('Boismint base', 120);

  // --- Reference totals from the noise-free truth -----------------------------
  final truth = session.truth;
  final seconds = {for (final k in _Kind.values) k: 0};
  var rideMeters = 0.0;
  var drop = 0.0;
  var maxSpeed = 0.0;
  final speeds = <double>[0];
  for (var i = 1; i < truth.length; i++) {
    final a = truth[i - 1];
    final b = truth[i];
    final d = _haversine(_lat(a.y), _lon(a.x), _lat(b.y), _lon(b.x));
    speeds.add(d);
    seconds[b.kind] = seconds[b.kind]! + 1;
    if (b.kind == _Kind.run) {
      rideMeters += d;
      if (a.alt > b.alt) drop += a.alt - b.alt;
      if (d > maxSpeed) maxSpeed = d;
    }
  }
  final runs = session.legs
      .where((l) => l.kind == _Kind.run && !l.name.contains('(part 2)'))
      .length;

  // --- Noisy fixes ------------------------------------------------------------
  final rnd = math.Random(_seed);
  final nx = _Drift(rnd, 3);
  final ny = _Drift(rnd, 3);
  final na = _Drift(rnd, 4);
  final rows = <String>[];
  final gpx = <String>[];
  final gpxStart = DateTime.utc(2026, 1, 10, 9);
  for (var i = 0; i < truth.length; i++) {
    final p = truth[i];
    final lat = _lat(p.y + ny.next());
    final lon = _lon(p.x + nx.next());
    final alt = p.alt + na.next();
    final accuracy = 4 + 4 * rnd.nextDouble();
    final speed = math.max(0, speeds[i] + 0.2 * _gauss(rnd));
    rows.add(
      '${i * 1000},${lat.toStringAsFixed(6)},${lon.toStringAsFixed(6)},'
      '${alt.toStringAsFixed(1)},${accuracy.toStringAsFixed(1)},'
      '${speed.toStringAsFixed(2)}',
    );
    final time = gpxStart.add(Duration(seconds: i)).toIso8601String();
    gpx.add(
      [
        '<trkpt lat="${lat.toStringAsFixed(6)}" lon="${lon.toStringAsFixed(6)}">',
        '<ele>${alt.toStringAsFixed(1)}</ele>',
        '<time>$time</time></trkpt>',
      ].join(),
    );
  }

  final legs = [
    for (final l in session.legs)
      '${l.kind.name}:${l.from}:${l.to}:${_slug(l.name)}',
  ].join(',');
  final csv = StringBuffer()
    ..writeln('# Val Thorens simulated snowboarding session (not a recording)')
    ..writeln('# generated by tool/gen_val_thorens_session.dart, seed $_seed')
    ..writeln('# geometry (c) OpenStreetMap contributors, ODbL 1.0')
    ..writeln('# elevation IGN RGE ALTI, Licence Ouverte 2.0')
    ..writeln(
      '# reference_runs=$runs '
      'reference_ride_s=${seconds[_Kind.run]} '
      'reference_lift_s=${seconds[_Kind.lift]} '
      'reference_rest_s=${seconds[_Kind.rest]}',
    )
    ..writeln(
      '# reference_drop_m=${drop.toStringAsFixed(1)} '
      'reference_ride_m=${rideMeters.toStringAsFixed(1)} '
      'reference_max_speed_mps=${maxSpeed.toStringAsFixed(2)}',
    )
    ..writeln('# legs=$legs')
    ..writeln('t_ms,lat,lon,alt,accuracy,speed')
    ..writeAll(rows, '\n')
    ..writeln();

  File(_outDart)
    ..createSync(recursive: true)
    ..writeAsStringSync('''
// GENERATED by tool/gen_val_thorens_session.dart from
// tool/val_thorens/geometry.json. Do not edit by hand.
//
// Lift lines and pistes: (c) OpenStreetMap contributors, ODbL 1.0.
// Elevations: IGN RGE ALTI, Licence Ouverte 2.0.
// See tool/val_thorens/README.md.

/// A simulated snowboarding session on real Val Thorens geography, as
/// fixture CSV (`t_ms,lat,lon,alt,accuracy,speed`, `# key=value` metadata
/// with the reference totals). Only referenced by tests and by the dev-only
/// GPS simulation, so release builds do not contain it.
const valThorensSessionCsv = \'\'\'
$csv\'\'\';
''');
  print('wrote $_outDart: ${rows.length} fixes');
  final csvPath = option('--csv');
  if (csvPath != null) File(csvPath).writeAsStringSync(csv.toString());
  final gpxPath = option('--gpx');
  if (gpxPath != null) {
    File(gpxPath).writeAsStringSync(
      '<?xml version="1.0" encoding="UTF-8"?>\n'
      '<gpx version="1.1" creator="gen_val_thorens_session" '
      'xmlns="http://www.topografix.com/GPX/1/1">\n'
      '<metadata><copyright author="OpenStreetMap contributors">\n'
      '<license>https://opendatacommons.org/licenses/odbl/1-0/</license>\n'
      '</copyright></metadata>\n'
      '<trk><name>Val Thorens simulated session</name><trkseg>\n'
      '${gpx.join('\n')}\n'
      '</trkseg></trk>\n</gpx>\n',
    );
  }
  for (final l in session.legs) {
    final a = truth[l.from];
    final b = truth[l.to];
    print(
      '${l.kind.name.padRight(5)} ${l.from.toString().padLeft(5)}'
      '-${l.to.toString().padLeft(5)} s  '
      '${a.alt.toStringAsFixed(0)} -> ${b.alt.toStringAsFixed(0)} m  '
      '${l.name}',
    );
  }
  print(
    'runs $runs, ride ${seconds[_Kind.run]} s, lift ${seconds[_Kind.lift]} s, '
    'rest ${seconds[_Kind.rest]} s, drop ${drop.toStringAsFixed(0)} m, '
    'ride ${rideMeters.toStringAsFixed(0)} m, '
    'max ${(maxSpeed * 3.6).toStringAsFixed(1)} km/h',
  );
}
