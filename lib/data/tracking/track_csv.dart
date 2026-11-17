import 'package:fitapp/domain/tracking/track_sample.dart';

/// A parsed CSV track: fixes plus the `# key=value` metadata.
class TrackCsv {
  const new(this.samples, this.meta);

  final List<TrackSample> samples;

  /// `# key=value` header comments.
  final Map<String, String> meta;

  /// The metadata value [key] as a number; throws when missing.
  double number(String key) => double.parse(
    meta[key] ?? (throw ArgumentError.value(key, 'key', 'not in metadata')),
  );
}

/// Parses `t_ms,lat,lon,alt,accuracy,speed` CSV text. `t_ms` counts from
/// [start] (UTC). Lines starting with `#` hold space-separated `key=value`
/// metadata; empty `alt` or `speed` fields are unknown.
TrackCsv parseTrackCsv(String text, {required DateTime start}) {
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
        t: start.add(Duration(milliseconds: int.parse(f[0]))),
        lat: double.parse(f[1]),
        lon: double.parse(f[2]),
        alt: f[3].isEmpty ? null : double.parse(f[3]),
        accuracy: double.parse(f[4]),
        speed: f[5].isEmpty ? null : double.parse(f[5]),
      ),
    );
  }
  return TrackCsv(samples, meta);
}
