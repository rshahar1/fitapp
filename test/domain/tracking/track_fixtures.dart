import 'dart:io';

import 'package:fitapp/domain/tracking/track_sample.dart';

/// Start of every fixture track.
final fixtureStart = DateTime.utc(2026, 1, 1, 8);

/// A parsed CSV track fixture.
class TrackFixture {
  const new(this.samples, this.meta);

  final List<TrackSample> samples;

  /// `# key=value` header comments.
  final Map<String, String> meta;

  double get referenceMeters => double.parse(meta['reference_distance_m']!);
}

/// Parses `t_ms,lat,lon,alt,accuracy,speed` CSV text (lines starting with
/// `#` are metadata comments).
TrackFixture parseTrackCsv(String text) {
  final samples = <TrackSample>[];
  final meta = <String, String>{};
  for (final line in text.split('\n')) {
    final l = line.trim();
    if (l.isEmpty || l.startsWith('t_ms')) continue;
    if (l.startsWith('#')) {
      for (final kv in l.substring(1).trim().split(' ')) {
        final i = kv.indexOf('=');
        if (i > 0) meta[kv.substring(0, i)] = kv.substring(i + 1);
      }
      continue;
    }
    final f = l.split(',');
    samples.add(
      TrackSample(
        t: fixtureStart.add(Duration(milliseconds: int.parse(f[0]))),
        lat: double.parse(f[1]),
        lon: double.parse(f[2]),
        alt: f[3].isEmpty ? null : double.parse(f[3]),
        accuracy: double.parse(f[4]),
        speed: f[5].isEmpty ? null : double.parse(f[5]),
      ),
    );
  }
  return TrackFixture(samples, meta);
}

/// Loads `test/fixtures/tracks/[name].csv`.
TrackFixture loadTrack(String name) =>
    parseTrackCsv(File('test/fixtures/tracks/$name.csv').readAsStringSync());
