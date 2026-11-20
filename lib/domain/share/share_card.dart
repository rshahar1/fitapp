/// What goes on a shared workout image (feature 027): type-specific stats,
/// the route, the snowboarding time breakdown and compressed exercise lines.
///
/// Pure Dart. No Flutter, database or I/O imports (constitution principle II).
/// Zero or missing values are never shown; the view only renders this data.
library;

import 'dart:convert';

import 'package:fitapp/domain/activity_types.dart';
import 'package:fitapp/domain/progression.dart' show LoggedSet;
import 'package:fitapp/domain/stats.dart' show setVolume;
import 'package:fitapp/domain/tracking/geo.dart';
import 'package:fitapp/domain/tracking/snow_review.dart' show snowDayStats;
import 'package:fitapp/domain/tracking/snow_summary.dart';
import 'package:fitapp/domain/training_breakdown.dart' show gymTypeId;
import 'package:meta/meta.dart';

/// Most exercise lines on a card; with more, one line less plus "+N more".
const maxShareExerciseLines = 7;

/// How a card is laid out.
enum ShareLayout {
  /// Route drawing above the stats (GPS runs, rides).
  route,

  /// Speed-coloured route, ride/lift/rest bar and day stats.
  snow,

  /// Gym totals and one line per exercise.
  strength,

  /// Stats only.
  basic,
}

/// One figure on the card: "5.2" "km" under "Distance".
@immutable
class ShareStat {
  const new(this.label, this.value, [this.unit]);

  final String label;
  final String value;
  final String? unit;

  @override
  String toString() => unit == null ? value : '$value $unit';
}

/// Time of a snowboarding day split into riding, lifts and rest.
@immutable
class ShareTimeBreakdown {
  const new({
    required this.rideSeconds,
    required this.liftSeconds,
    required this.restSeconds,
  });

  final int rideSeconds;
  final int liftSeconds;
  final int restSeconds;

  int get totalSeconds => rideSeconds + liftSeconds + restSeconds;
}

/// One exercise on a gym card: "Bench press" — "3 × 8 · 60 kg".
@immutable
class ShareExerciseLine {
  const new(this.name, this.detail);

  final String name;
  final String detail;
}

/// Everything a share image shows.
@immutable
class ShareCardData {
  const new({
    required this.layout,
    required this.typeId,
    required this.title,
    required this.startedAt,
    this.stats = const [],
    this.route,
    this.segments,
    this.breakdown,
    this.exercises = const [],
    this.hiddenExercises = 0,
  });

  final ShareLayout layout;

  /// [gymTypeId] or an activity type id (for the icon).
  final String typeId;
  final String title;
  final DateTime startedAt;

  /// At most six, in display order.
  final List<ShareStat> stats;

  /// At least two points, or null.
  final List<GeoPoint>? route;

  /// Stored snowboarding segments (snow layout), for the speed colours.
  final String? segments;

  /// Snow layout only, and only when some time was recorded.
  final ShareTimeBreakdown? breakdown;

  /// Strength layout only.
  final List<ShareExerciseLine> exercises;

  /// Exercises left off the card ("+N more exercises").
  final int hiddenExercises;
}

/// The stored values of an activity that a card may show.
@immutable
class ActivityShareInput {
  const new({
    required this.typeId,
    required this.startedAt,
    this.source = 'manual',
    this.durationMinutes,
    this.distanceMeters,
    this.movingSeconds,
    this.elevationGainMeters,
    this.route,
    this.splits,
    this.maxSpeedMps,
    this.verticalDropMeters,
    this.runCount,
    this.liftSeconds,
    this.restSeconds,
    this.segments,
  });

  final String typeId;
  final DateTime startedAt;
  final String source;
  final int? durationMinutes;
  final int? distanceMeters;
  final int? movingSeconds;
  final int? elevationGainMeters;

  /// Encoded polyline.
  final String? route;

  /// JSON list of seconds per km.
  final String? splits;
  final double? maxSpeedMps;
  final int? verticalDropMeters;
  final int? runCount;
  final int? liftSeconds;
  final int? restSeconds;

  /// JSON snowboarding segments.
  final String? segments;
}

/// One exercise of a gym workout: its logged sets as (weight, reps).
@immutable
class ShareExercise {
  const new({required this.name, required this.sets, this.perHand = false});

  final String name;
  final bool perHand;
  final List<(double, int)> sets;
}

/// The values of a finished gym workout that a card may show.
@immutable
class WorkoutShareInput {
  const new({
    required this.startedAt,
    required this.exercises,
    this.name,
    this.endedAt,
  });

  final String? name;
  final DateTime startedAt;
  final DateTime? endedAt;
  final List<ShareExercise> exercises;
}

/// The card of an activity of any type.
ShareCardData activityShareCard(ActivityShareInput a) {
  final title = activityLabel(a.typeId);
  final route = _decodeRoute(a.route);
  final records = decodeSnowRecords(a.segments);
  if (a.typeId == 'snowboarding' &&
      a.source == 'gps' &&
      records.isNotEmpty &&
      route != null) {
    return _snowCard(a, title, route, records);
  }
  final meters = _positive(a.distanceMeters);
  final minutes = _positive(a.durationMinutes);
  final moving = _positive(a.movingSeconds);
  final climb = _positive(a.elevationGainMeters);
  final splits = _decodeSplits(a.splits);
  final stats = <ShareStat>[
    if (meters != null) ShareStat('Distance', distanceKmText(meters), 'km'),
    if (meters != null && minutes != null)
      ?switch (a.typeId) {
        'running' => ShareStat(
          'Avg pace',
          formatPace(meters, minutes).replaceAll(' /km', ''),
          '/km',
        ),
        'cycling' => ShareStat(
          'Avg speed',
          formatSpeed(meters, minutes).replaceAll(' km/h', ''),
          'km/h',
        ),
        _ => null,
      },
    if (minutes != null) ShareStat('Duration', _minutesText(minutes)),
    if (moving != null) ShareStat('Moving time', _clock(moving)),
    if (climb != null) ShareStat('Climb', formatGrouped(climb), 'm'),
    if (a.typeId == 'running' && splits.isNotEmpty)
      ShareStat(
        'Best km',
        _clock(splits.reduce((x, y) => x < y ? x : y)),
        '/km',
      ),
  ];
  return ShareCardData(
    layout: route == null ? ShareLayout.basic : ShareLayout.route,
    typeId: a.typeId,
    title: title,
    startedAt: a.startedAt,
    stats: List.unmodifiable(stats.take(6)),
    route: route,
  );
}

ShareCardData _snowCard(
  ActivityShareInput a,
  String title,
  List<GeoPoint> route,
  List<SnowRecord> records,
) {
  final top = a.maxSpeedMps;
  final drop = _positive(a.verticalDropMeters);
  final runs = _positive(a.runCount);
  final meters = _positive(a.distanceMeters);
  final minutes = _positive(a.durationMinutes);
  final longest = _positive(
    snowDayStats(records, snowDescents(records)).longestRunMeters,
  );
  final breakdown = ShareTimeBreakdown(
    rideSeconds: _nonNegative(a.movingSeconds),
    liftSeconds: _nonNegative(a.liftSeconds),
    restSeconds: _nonNegative(a.restSeconds),
  );
  return ShareCardData(
    layout: ShareLayout.snow,
    typeId: a.typeId,
    title: title,
    startedAt: a.startedAt,
    route: route,
    segments: a.segments,
    breakdown: breakdown.totalSeconds > 0 ? breakdown : null,
    stats: List.unmodifiable([
      if (top != null && top.isFinite && top > 0)
        ShareStat('Top speed', (top * 3.6).toStringAsFixed(1), 'km/h'),
      if (drop != null) ShareStat('Vertical', formatGrouped(drop), 'm'),
      if (runs != null) ShareStat('Runs', '$runs'),
      if (meters != null) ShareStat('Distance', distanceKmText(meters), 'km'),
      if (minutes != null) ShareStat('Total time', _minutesText(minutes)),
      if (longest != null)
        ShareStat('Longest run', distanceKmText(longest), 'km'),
    ]),
  );
}

/// The card of a finished gym workout. Exercises without sets are left out.
ShareCardData workoutShareCard(WorkoutShareInput w) {
  final done = [
    for (final e in w.exercises)
      if (e.sets.isNotEmpty) e,
  ];
  var sets = 0;
  var reps = 0;
  var volume = 0.0;
  for (final e in done) {
    for (final (weight, r) in e.sets) {
      sets++;
      reps += r;
      volume += setVolume(
        LoggedSet(setNo: 1, weight: weight, reps: r),
        perHand: e.perHand,
      );
    }
  }
  final end = w.endedAt;
  final minutes = end == null ? 0 : end.difference(w.startedAt).inMinutes;
  final fits = done.length <= maxShareExerciseLines;
  final shown = fits ? done : done.take(maxShareExerciseLines - 1).toList();
  final name = w.name?.trim();
  return ShareCardData(
    layout: ShareLayout.strength,
    typeId: gymTypeId,
    title: name == null || name.isEmpty ? 'Workout' : name,
    startedAt: w.startedAt,
    stats: List.unmodifiable([
      if (minutes > 0) ShareStat('Duration', _minutesText(minutes)),
      if (sets > 0) ShareStat('Sets', '$sets'),
      if (reps > 0) ShareStat('Reps', formatGrouped(reps)),
      if (volume.round() > 0)
        ShareStat('Volume', formatGrouped(volume.round()), 'kg'),
    ]),
    exercises: List.unmodifiable(shown.map(exerciseShareLine)),
    hiddenExercises: done.length - shown.length,
  );
}

/// "3 × 8 · 60 kg" when every set is the same, otherwise
/// "4 sets · top 85 kg × 5" (heaviest set, then most reps). Bodyweight sets
/// show reps only; per-hand weights end in "each".
ShareExerciseLine exerciseShareLine(ShareExercise e) {
  final sets = e.sets;
  final each = e.perHand ? ' each' : '';
  if (sets.isEmpty) return ShareExerciseLine(e.name, '');
  final (w0, r0) = sets.first;
  final uniform = sets.every((s) => s.$1 == w0 && s.$2 == r0);
  if (uniform) {
    final base = '${sets.length} × $r0';
    return ShareExerciseLine(e.name, w0 > 0 ? '$base · ${_kg(w0)}$each' : base);
  }
  var (topW, topR) = sets.first;
  for (final (w, r) in sets) {
    if (w > topW || (w == topW && r > topR)) (topW, topR) = (w, r);
  }
  final count = '${sets.length} sets';
  return ShareExerciseLine(
    e.name,
    topW > 0
        ? '$count · top ${_kg(topW)} × $topR$each'
        : '$count · best $topR reps',
  );
}

/// "fitapp-running-2026-03-07.png" (local date of [startedAt]).
String shareFileName(String typeId, DateTime startedAt) {
  final d = startedAt.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  final safe = typeId.replaceAll(RegExp('[^a-z0-9]+'), '-');
  return 'fitapp-$safe-${d.year}-${two(d.month)}-${two(d.day)}.png';
}

/// Text sent along with the image: the title and the first two stats.
String shareCaption(ShareCardData c) =>
    [c.title, ...c.stats.take(2).map((s) => s.toString())].join(' · ');

List<GeoPoint>? _decodeRoute(String? route) {
  if (route == null || route.isEmpty) return null;
  try {
    final points = decodePolyline(route);
    return points.length >= 2 ? List.unmodifiable(points) : null;
  } on Object {
    return null;
  }
}

List<int> _decodeSplits(String? raw) {
  if (raw == null || raw.isEmpty) return const [];
  try {
    final v = jsonDecode(raw);
    if (v is! List) return const [];
    return [
      for (final s in v)
        if (s is num && s > 0) s.round(),
    ];
  } on FormatException {
    return const [];
  }
}

int? _positive(int? v) => v != null && v > 0 ? v : null;

int _nonNegative(int? v) => v != null && v > 0 ? v : 0;

String _two(int n) => n.toString().padLeft(2, '0');

/// "26:40", "1:02:05".
String _clock(int seconds) {
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  final s = seconds % 60;
  return h > 0 ? '$h:${_two(m)}:${_two(s)}' : '$m:${_two(s)}';
}

/// "45 min", "1 h 30 min", "2 h" (as on the activity screens).
String _minutesText(int minutes) {
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (h == 0) return '$m min';
  if (m == 0) return '$h h';
  return '$h h $m min';
}

/// "60 kg", "42.5 kg", "22.25 kg".
String _kg(double kg) {
  if (kg == kg.roundToDouble()) return '${kg.toInt()} kg';
  var s = kg.toStringAsFixed(2);
  if (s.endsWith('0')) s = s.substring(0, s.length - 1);
  return '$s kg';
}
