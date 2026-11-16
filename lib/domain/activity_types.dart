/// Sport activities other than gym workouts (feature 006): a code-level
/// registry of activity types and the validation of a logged activity.
///
/// Pure Dart. No Flutter, database or I/O imports (constitution principle II).
/// To add a sport, add an entry to [activityTypes] (with a new stable id)
/// and an icon in `lib/features/activities/activity_icons.dart`.
library;

import 'package:meta/meta.dart';

/// One kind of activity. [id] is stored in the database and never changes.
@immutable
class ActivityType {
  const new(
    this.id,
    this.label, {
    this.hasDistance = false,
    this.hasLiveTracking = false,
  });

  /// Stable id stored with each activity.
  final String id;

  /// Display name.
  final String label;

  /// Whether a distance can be logged for this type (feature 009).
  final bool hasDistance;

  /// Whether this type can be recorded live with GPS (feature 010).
  final bool hasLiveTracking;
}

/// All activity types, in display order.
const activityTypes = [
  ActivityType('functional', 'Functional training'),
  ActivityType('cycling', 'Cycling', hasDistance: true, hasLiveTracking: true),
  ActivityType(
    'snowboarding',
    'Snowboarding',
    hasDistance: true,
    hasLiveTracking: true,
  ),
  ActivityType('running', 'Running', hasDistance: true, hasLiveTracking: true),
  ActivityType('pilates', 'Pilates'),
];

/// The type with [id], or null if unknown (e.g. from a newer app version).
ActivityType? activityTypeById(String id) {
  for (final t in activityTypes) {
    if (t.id == id) return t;
  }
  return null;
}

/// Display label for [typeId]; "Activity" for unknown ids.
String activityLabel(String typeId) =>
    activityTypeById(typeId)?.label ?? 'Activity';

/// Longest duration that can be logged (one day), in minutes.
const maxActivityMinutes = 1440;

/// Longest distance that can be logged, in metres (1000 km).
const maxActivityDistanceMeters = 1000000;

/// Longest note, in characters.
const maxActivityNoteLength = 200;

/// A validated activity.
@immutable
class ValidActivity {
  const new({
    required this.typeId,
    required this.startedAt,
    this.durationMinutes,
    this.distanceMeters,
    this.notes,
  });

  final String typeId;
  final DateTime startedAt;
  final int? durationMinutes;

  /// Whole metres; only for types with a distance.
  final int? distanceMeters;

  /// Trimmed; null when empty.
  final String? notes;
}

/// Validates an activity. Throws [ArgumentError] when the type is unknown
/// (unless [allowUnknownType], used when editing an entry of a retired
/// type), the local day of [startedAt] is after the local day of [now], the
/// duration is outside 1..[maxActivityMinutes], the distance is outside
/// 1..[maxActivityDistanceMeters] or given for a known type without
/// distance, or the note is too long.
ValidActivity validateActivity({
  required String typeId,
  required DateTime startedAt,
  required DateTime now,
  int? durationMinutes,
  int? distanceMeters,
  String? notes,
  bool allowUnknownType = false,
}) {
  if (!allowUnknownType && activityTypeById(typeId) == null) {
    throw ArgumentError.value(typeId, 'typeId', 'unknown activity type');
  }
  final day = _day(startedAt.toLocal());
  if (day.isAfter(_day(now.toLocal()))) {
    throw ArgumentError.value(startedAt, 'startedAt', 'is in the future');
  }
  final d = durationMinutes;
  if (d != null && (d < 1 || d > maxActivityMinutes)) {
    throw ArgumentError.value(d, 'durationMinutes', '1..$maxActivityMinutes');
  }
  final m = distanceMeters;
  if (m != null) {
    if (m < 1 || m > maxActivityDistanceMeters) {
      throw ArgumentError.value(
        m,
        'distanceMeters',
        '1..$maxActivityDistanceMeters',
      );
    }
    final type = activityTypeById(typeId);
    if (type != null && !type.hasDistance) {
      throw ArgumentError.value(
        typeId,
        'distanceMeters',
        'this activity type has no distance',
      );
    }
  }
  final clean = notes?.trim();
  if (clean != null && clean.length > maxActivityNoteLength) {
    throw ArgumentError.value(
      clean.length,
      'notes',
      'max $maxActivityNoteLength characters',
    );
  }
  return ValidActivity(
    typeId: typeId,
    startedAt: startedAt,
    durationMinutes: d,
    distanceMeters: m,
    notes: clean == null || clean.isEmpty ? null : clean,
  );
}

/// Parses a distance typed in kilometres ("5.2" or "5,2") into whole metres,
/// rounded to the nearest 10 m. Null for empty, non-numeric, non-positive
/// (after rounding) or above [maxActivityDistanceMeters].
int? parseDistanceKm(String input) {
  final t = input.trim().replaceAll(',', '.');
  if (t.isEmpty) return null;
  final km = double.tryParse(t);
  if (km == null || !km.isFinite) return null;
  final meters = (km * 100).round() * 10;
  if (meters <= 0 || meters > maxActivityDistanceMeters) return null;
  return meters;
}

/// "5.2 km", "36.75 km", "10 km": up to two decimals, trailing zeros dropped.
String formatDistanceKm(int meters) => '${_kmText(meters)} km';

/// Kilometres as text without trailing zeros (also used to pre-fill input).
String distanceKmText(int meters) => _kmText(meters);

String _kmText(int meters) {
  var s = (meters / 1000).toStringAsFixed(2);
  if (s.contains('.')) {
    s = s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  }
  return s;
}

/// Average pace, "5:23 /km".
String formatPace(int meters, int minutes) {
  final secPerKm = (minutes * 60 * 1000 / meters).round();
  final s = (secPerKm % 60).toString().padLeft(2, '0');
  return '${secPerKm ~/ 60}:$s /km';
}

/// Average speed, "24.5 km/h".
String formatSpeed(int meters, int minutes) =>
    '${(meters / 1000 / (minutes / 60)).toStringAsFixed(1)} km/h';

/// Speed in km/h from metres per second, one decimal: 17.4 -> "62.6 km/h".
String formatSpeedKmh(double mps) => '${(mps * 3.6).toStringAsFixed(1)} km/h';

/// Whole metres with a comma thousands separator: 3240 -> "3,240 m".
String formatMetersGrouped(int meters) {
  final digits = meters.abs().toString();
  final out = StringBuffer(meters < 0 ? '-' : '');
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) out.write(',');
    out.write(digits[i]);
  }
  return '$out m';
}

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);
