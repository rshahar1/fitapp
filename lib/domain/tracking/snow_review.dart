/// Review tools for a stored snowboarding day (feature 017): day stats,
/// best-run badges, run comparison, speed heatmap and run replay. Pure Dart.
library;

import 'package:fitapp/domain/tracking/geo.dart';
import 'package:fitapp/domain/tracking/snow_state.dart';
import 'package:fitapp/domain/tracking/snow_summary.dart';
import 'package:meta/meta.dart';

/// Extremes of the day.
@immutable
class SnowDayStats {
  const new({this.highestAlt, this.lowestAlt, this.longestRunMeters});

  final int? highestAlt;
  final int? lowestAlt;
  final int? longestRunMeters;
}

/// Highest and lowest altitude over all [records] and the longest of the
/// [descents].
SnowDayStats snowDayStats(
  List<SnowRecord> records,
  List<SnowDescent> descents,
) {
  int? high;
  int? low;
  for (final r in records) {
    for (final alt in [r.startAlt, r.endAlt]) {
      if (alt == null) continue;
      if (high == null || alt > high) high = alt;
      if (low == null || alt < low) low = alt;
    }
  }
  int? longest;
  for (final d in descents) {
    if (longest == null || d.distanceMeters > longest) {
      longest = d.distanceMeters;
    }
  }
  return SnowDayStats(
    highestAlt: high,
    lowestAlt: low,
    longestRunMeters: longest,
  );
}

/// A metric runs are compared by.
enum RunMetric { maxSpeed, avgSpeed, vertical, distance, duration }

/// The value of [metric] for [d]: speeds in m/s, lengths in metres, time in
/// seconds.
double runMetricValue(SnowDescent d, RunMetric metric) => switch (metric) {
  RunMetric.maxSpeed => d.maxSpeedMps,
  RunMetric.avgSpeed => d.avgSpeedMps,
  RunMetric.vertical => d.dropMeters.toDouble(),
  RunMetric.distance => d.distanceMeters.toDouble(),
  RunMetric.duration => d.durationSeconds.toDouble(),
};

/// [descents] ordered for the comparison: best [metric] first when
/// [byMetric], else in the order they were ridden. Equal values keep the
/// riding order.
List<SnowDescent> compareRuns(
  List<SnowDescent> descents,
  RunMetric metric, {
  bool byMetric = true,
}) {
  final out = [...descents]..sort((a, b) => a.number.compareTo(b.number));
  if (!byMetric) return out;
  return out..sort((a, b) {
    final byValue = runMetricValue(
      b,
      metric,
    ).compareTo(runMetricValue(a, metric));
    return byValue != 0 ? byValue : a.number.compareTo(b.number);
  });
}

/// A distinction a run can earn.
enum RunBadge { fastest, longest, mostVertical }

/// The badges of each run number. Empty with fewer than two runs: a badge
/// needs something to beat. Ties go to the earlier run.
Map<int, Set<RunBadge>> snowBadges(List<SnowDescent> descents) {
  if (descents.length < 2) return const {};
  final out = <int, Set<RunBadge>>{};
  void award(RunBadge badge, RunMetric metric) {
    final best = compareRuns(descents, metric).first;
    out.putIfAbsent(best.number, () => {}).add(badge);
  }

  award(RunBadge.fastest, RunMetric.maxSpeed);
  award(RunBadge.longest, RunMetric.distance);
  award(RunBadge.mostVertical, RunMetric.vertical);
  return out;
}

/// A slice of the stored route with what is known about it.
@immutable
class SnowRoutePart {
  const new({
    required this.kind,
    required this.offset,
    required this.count,
    this.speedsKmh = const [],
  });

  final SnowKind kind;

  /// The slice `route[offset]` to `route[offset + count - 1]`.
  final int offset;
  final int count;

  /// Speed at each point of the slice (runs only).
  final List<int> speedsKmh;
}

/// The route slices of [records], in order.
List<SnowRoutePart> snowRouteParts(List<SnowRecord> records) {
  final out = <SnowRoutePart>[];
  var offset = 0;
  for (final r in records) {
    out.add(
      SnowRoutePart(
        kind: r.kind,
        offset: offset,
        count: r.pointCount,
        speedsKmh: r.speedsKmh,
      ),
    );
    offset += r.pointCount;
  }
  return out;
}

/// Number of colours of the speed heatmap.
const heatmapBuckets = 5;

/// Top of the heatmap scale for [records]: their highest point speed,
/// rounded up to a multiple of 5 km/h (at least 5).
int heatmapMaxKmh(List<SnowRecord> records) {
  var max = 0;
  for (final r in records) {
    for (final v in r.speedsKmh) {
      if (v > max) max = v;
    }
  }
  return max <= 5 ? 5 : ((max + 4) ~/ 5) * 5;
}

/// The upper limit in km/h of each heatmap bucket, slowest first.
List<int> speedColorStops(int maxKmh, {int buckets = heatmapBuckets}) => [
  for (var i = 1; i <= buckets; i++) (maxKmh * i / buckets).round(),
];

/// The bucket (0 = slowest) of [kmh] on a scale up to [maxKmh].
int speedBucket(int kmh, int maxKmh, {int buckets = heatmapBuckets}) {
  if (maxKmh <= 0 || kmh <= 0) return 0;
  final i = (kmh * buckets / maxKmh).floor();
  return i >= buckets ? buckets - 1 : i;
}

/// One point of a run's replay track.
@immutable
class ReplayPoint {
  const new({
    required this.point,
    required this.seconds,
    required this.speedKmh,
    this.altitude,
  });

  final GeoPoint point;

  /// Seconds since the run set off.
  final int seconds;
  final int speedKmh;
  final int? altitude;
}

/// The replay track of [descent]: the route points of its run segments with
/// their time, speed and altitude. Stops between them are bridged in time.
/// Empty when the stored data does not fit [route] (e.g. a damaged row).
List<ReplayPoint> replayTrack(
  List<SnowRecord> records,
  List<GeoPoint> route,
  SnowDescent descent,
) {
  final out = <ReplayPoint>[];
  var offset = 0;
  for (var i = 0; i < records.length; i++) {
    final r = records[i];
    final inside = i >= descent.firstRecord && i <= descent.lastRecord;
    if (inside && r.kind == SnowKind.run) {
      if (offset + r.pointCount > route.length ||
          r.speedsKmh.length != r.pointCount ||
          r.seconds.length != r.pointCount) {
        return const [];
      }
      final base = r.startSeconds - descent.startSeconds;
      final hasAlt = r.altitudes.length == r.pointCount;
      for (var j = 0; j < r.pointCount; j++) {
        out.add(
          ReplayPoint(
            point: route[offset + j],
            seconds: base + r.seconds[j],
            speedKmh: r.speedsKmh[j],
            altitude: hasAlt ? r.altitudes[j] : null,
          ),
        );
      }
    }
    offset += r.pointCount;
  }
  return out;
}

/// The replay at one moment.
@immutable
class ReplayFrame {
  const new({
    required this.point,
    required this.speedKmh,
    required this.seconds,
    required this.index,
    this.altitude,
  });

  final GeoPoint point;
  final double speedKmh;
  final double seconds;

  /// Index of the last track point reached (the trail drawn so far).
  final int index;
  final double? altitude;
}

/// The replay of [track] at [seconds] since the run set off, interpolated
/// between the two points around it and clamped to the track. Null for an
/// empty track.
ReplayFrame? replayAt(List<ReplayPoint> track, double seconds) {
  if (track.isEmpty) return null;
  ReplayFrame at(int i) => ReplayFrame(
    point: track[i].point,
    speedKmh: track[i].speedKmh.toDouble(),
    seconds: track[i].seconds.toDouble(),
    index: i,
    altitude: track[i].altitude?.toDouble(),
  );
  if (seconds <= track.first.seconds) return at(0);
  if (seconds >= track.last.seconds) return at(track.length - 1);
  // Binary search for the last point at or before [seconds].
  var lo = 0;
  var hi = track.length - 1;
  while (hi - lo > 1) {
    final mid = (lo + hi) ~/ 2;
    if (track[mid].seconds <= seconds) {
      lo = mid;
    } else {
      hi = mid;
    }
  }
  final a = track[lo];
  final b = track[hi];
  final span = b.seconds - a.seconds;
  final f = span <= 0 ? 0.0 : (seconds - a.seconds) / span;
  double mix(num x, num y) => x + (y - x) * f;
  final altA = a.altitude;
  final altB = b.altitude;
  return ReplayFrame(
    point: (
      lat: mix(a.point.lat, b.point.lat),
      lon: mix(a.point.lon, b.point.lon),
    ),
    speedKmh: mix(a.speedKmh, b.speedKmh),
    seconds: seconds,
    index: lo,
    altitude: altA == null || altB == null ? null : mix(altA, altB),
  );
}

/// Length of [track] in seconds.
int replayDuration(List<ReplayPoint> track) =>
    track.isEmpty ? 0 : track.last.seconds - track.first.seconds;
