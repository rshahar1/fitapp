/// What is kept of a tracked snowboarding day once its raw points are
/// deleted (feature 017). Pure Dart.
library;

import 'dart:convert';

import 'package:fitapp/domain/tracking/geo.dart';
import 'package:fitapp/domain/tracking/snow_reducer.dart';
import 'package:fitapp/domain/tracking/snow_state.dart';
import 'package:fitapp/domain/tracking/track_sample.dart';
import 'package:meta/meta.dart';

/// Route simplification tolerance in metres: moving, and standing (where
/// the points are mostly GPS jitter).
const snowRouteToleranceMeters = 5.0;
const snowRestToleranceMeters = 15.0;

/// One stored segment of a snowboarding day.
@immutable
class SnowRecord {
  const new({
    required this.kind,
    required this.startSeconds,
    required this.durationSeconds,
    required this.distanceMeters,
    required this.verticalMeters,
    required this.pointCount,
    this.maxSpeedMps = 0,
    this.startAlt,
    this.endAlt,
    this.speedsKmh = const [],
    this.seconds = const [],
  });

  final SnowKind kind;

  /// Start, in seconds since the activity started.
  final int startSeconds;
  final int durationSeconds;
  final int distanceMeters;

  /// Drop of a run, gain of a lift, 0 for a rest.
  final int verticalMeters;

  /// Highest speed in m/s (runs only).
  final double maxSpeedMps;

  /// How many points of the activity's route belong to this segment.
  final int pointCount;

  /// Altitude in metres at the start and end, if known.
  final int? startAlt;
  final int? endAlt;

  /// Runs only, one entry per route point: the speed there in km/h and the
  /// seconds since the run began.
  final List<int> speedsKmh;
  final List<int> seconds;

  int get endSeconds => startSeconds + durationSeconds;

  Map<String, Object> toJson() => {
    'k': _codes[kind]!,
    't': startSeconds,
    'd': durationSeconds,
    'm': distanceMeters,
    'v': verticalMeters,
    if (kind == SnowKind.run) 's': (maxSpeedMps * 10).round() / 10,
    'n': pointCount,
    'a': ?startAlt,
    'b': ?endAlt,
    if (speedsKmh.isNotEmpty) 'p': speedsKmh,
    if (seconds.isNotEmpty) 'q': seconds,
  };
}

const _codes = {SnowKind.run: 'r', SnowKind.lift: 'l', SnowKind.rest: 's'};

/// The JSON text stored in `activities.segments`.
String encodeSnowRecords(List<SnowRecord> records) =>
    jsonEncode([for (final r in records) r.toJson()]);

/// Parses `activities.segments`. Empty for null or anything unreadable
/// (e.g. written by a newer app version).
List<SnowRecord> decodeSnowRecords(String? text) {
  if (text == null || text.isEmpty) return const [];
  try {
    final list = jsonDecode(text) as List<Object?>;
    return [
      for (final item in list.cast<Map<String, Object?>>())
        SnowRecord(
          kind: _codes.entries.firstWhere((e) => e.value == item['k']).key,
          startSeconds: (item['t']! as num).toInt(),
          durationSeconds: (item['d']! as num).toInt(),
          distanceMeters: (item['m']! as num).toInt(),
          verticalMeters: (item['v']! as num).toInt(),
          maxSpeedMps: (item['s'] as num? ?? 0).toDouble(),
          pointCount: (item['n']! as num).toInt(),
          startAlt: (item['a'] as num?)?.toInt(),
          endAlt: (item['b'] as num?)?.toInt(),
          speedsKmh: _ints(item['p']),
          seconds: _ints(item['q']),
        ),
    ];
  } on Object {
    return const [];
  }
}

List<int> _ints(Object? v) => v == null
    ? const []
    : List.unmodifiable([
        for (final x in v as List<Object?>) (x! as num).toInt(),
      ]);

/// A descent: the runs (and the stops between them) from one lift to the
/// next. Counted as a run when its drop is at least the tuning's minimum.
@immutable
class SnowDescent {
  const new({
    required this.number,
    required this.firstRecord,
    required this.lastRecord,
    required this.routeOffset,
    required this.pointCount,
    required this.startSeconds,
    required this.durationSeconds,
    required this.rideSeconds,
    required this.distanceMeters,
    required this.dropMeters,
    required this.maxSpeedMps,
    this.topAlt,
    this.bottomAlt,
  });

  /// 1 for the first run of the day.
  final int number;

  /// Indices into the record list: the first and last run segment.
  final int firstRecord;
  final int lastRecord;

  /// The slice of the route this descent covers.
  final int routeOffset;
  final int pointCount;

  final int startSeconds;

  /// From setting off to arriving, stops included.
  final int durationSeconds;

  /// Time actually riding.
  final int rideSeconds;
  final int distanceMeters;
  final int dropMeters;
  final double maxSpeedMps;
  final int? topAlt;
  final int? bottomAlt;

  /// Average speed while riding, in m/s.
  double get avgSpeedMps => rideSeconds > 0 ? distanceMeters / rideSeconds : 0;
}

/// The counted runs of [records], in order.
List<SnowDescent> snowDescents(
  List<SnowRecord> records, {
  double minDropMeters = 30,
}) {
  final out = <SnowDescent>[];
  final offsets = <int>[];
  var offset = 0;
  for (final r in records) {
    offsets.add(offset);
    offset += r.pointCount;
  }

  void close(int first, int last) {
    var drop = 0;
    var meters = 0;
    var ride = 0;
    var maxSpeed = 0.0;
    var points = 0;
    for (var i = first; i <= last; i++) {
      final r = records[i];
      points += r.pointCount;
      if (r.kind != SnowKind.run) continue;
      drop += r.verticalMeters;
      meters += r.distanceMeters;
      ride += r.durationSeconds;
      if (r.maxSpeedMps > maxSpeed) maxSpeed = r.maxSpeedMps;
    }
    if (drop < minDropMeters) return;
    out.add(
      SnowDescent(
        number: out.length + 1,
        firstRecord: first,
        lastRecord: last,
        routeOffset: offsets[first],
        pointCount: points,
        startSeconds: records[first].startSeconds,
        durationSeconds: records[last].endSeconds - records[first].startSeconds,
        rideSeconds: ride,
        distanceMeters: meters,
        dropMeters: drop,
        maxSpeedMps: maxSpeed,
        topAlt: records[first].startAlt,
        bottomAlt: records[last].endAlt,
      ),
    );
  }

  int? first;
  int? last;
  for (var i = 0; i <= records.length; i++) {
    final kind = i < records.length ? records[i].kind : SnowKind.lift;
    if (kind == SnowKind.run) {
      first ??= i;
      last = i;
    } else if (kind == SnowKind.lift) {
      if (first != null) close(first, last!);
      first = null;
      last = null;
    }
  }
  return out;
}

/// The stored form of a snowboarding day.
@immutable
class SnowSummary {
  const new({
    required this.rideMeters,
    required this.rideSeconds,
    required this.liftSeconds,
    required this.restSeconds,
    required this.dropMeters,
    required this.runCount,
    required this.maxSpeedMps,
    required this.route,
    required this.records,
  });

  final int rideMeters;
  final int rideSeconds;
  final int liftSeconds;
  final int restSeconds;
  final int dropMeters;
  final int runCount;
  final double maxSpeedMps;

  /// Encoded polyline (precision 5) of the whole day, segment after segment.
  final String route;
  final List<SnowRecord> records;

  /// Average speed while riding, in m/s; null without any riding.
  double? get avgSpeedMps =>
      rideSeconds > 0 && rideMeters > 0 ? rideMeters / rideSeconds : null;
}

/// Summarises [state] with the [fed] fixes: exactly the fixes given to the
/// snow reducer, in order. Throws [ArgumentError] when their number differs.
SnowSummary summarizeSnow(
  SnowState state,
  List<TrackSample> fed, {
  required DateTime startedAt,
  SnowTuning tuning = snowTuning,
}) {
  if (fed.length != state.count) {
    throw ArgumentError.value(fed.length, 'fed', 'expected ${state.count}');
  }
  final done = pauseSnow(state);
  final route = <GeoPoint>[];
  final records = <SnowRecord>[];
  for (final seg in done.segments) {
    final slice = fed.sublist(seg.firstIndex, seg.lastIndex + 1);
    final points = [for (final s in slice) (lat: s.lat, lon: s.lon)];
    final kept = simplifyIndices(
      points,
      seg.kind == SnowKind.rest
          ? snowRestToleranceMeters
          : snowRouteToleranceMeters,
    );
    route.addAll([for (final i in kept) points[i]]);
    final isRun = seg.kind == SnowKind.run;
    records.add(
      SnowRecord(
        kind: seg.kind,
        startSeconds: seg.start.difference(startedAt).inSeconds,
        durationSeconds: seg.seconds.round(),
        distanceMeters: seg.distanceMeters.round(),
        verticalMeters: seg.verticalMeters.round(),
        maxSpeedMps: isRun ? seg.maxSpeedMps : 0,
        pointCount: kept.length,
        startAlt: seg.startAlt?.round(),
        endAlt: seg.endAlt?.round(),
        speedsKmh: isRun
            ? [for (final i in kept) (_speedAt(slice, i) * 3.6).round()]
            : const [],
        seconds: isRun
            ? [for (final i in kept) slice[i].t.difference(seg.start).inSeconds]
            : const [],
      ),
    );
  }
  return SnowSummary(
    rideMeters: done.rideMeters.round(),
    rideSeconds: done.rideSeconds.round(),
    liftSeconds: done.liftSeconds.round(),
    restSeconds: done.restSeconds.round(),
    dropMeters: done.dropMeters.round(),
    runCount: snowDescents(records, minDropMeters: tuning.minRunDrop).length,
    maxSpeedMps: done.maxSpeedMps,
    route: encodePolyline(route),
    records: List.unmodifiable(records),
  );
}

/// Speed at fix [i] of [slice] in m/s: the device speed, else from the
/// neighbouring fix.
double _speedAt(List<TrackSample> slice, int i) {
  final own = slice[i].speed;
  if (own != null) return own;
  if (slice.length < 2) return 0;
  final a = slice[i == 0 ? 0 : i - 1];
  final b = slice[i == 0 ? 1 : i];
  final dt = b.t.difference(a.t).inMicroseconds / 1e6;
  return dt <= 0 ? 0 : haversineMeters(a.lat, a.lon, b.lat, b.lon) / dt;
}
