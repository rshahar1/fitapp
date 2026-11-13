import 'dart:convert';

import 'package:fitapp/data/db/app_database.dart';
import 'package:fitapp/domain/calendar.dart' show dateOnly, dayKey;
import 'package:fitapp/domain/workout_dates.dart';
import 'package:meta/meta.dart';

/// Device-local facts about the workout in progress (feature 007), kept in
/// the settings table like the persisted rest timer.
@immutable
class LiveSession {
  const new({
    required this.workoutId,
    required this.liveSince,
    this.priorSeconds = 0,
    this.day,
  });

  /// The workout in progress.
  final String workoutId;

  /// When it last became live (start or resume), UTC.
  final DateTime liveSince;

  /// Duration accumulated before it was resumed; 0 for a new workout.
  final int priorSeconds;

  /// Local day chosen with the Date row; null keeps the start day.
  final DateTime? day;

  /// Whether this workout was resumed from history.
  bool get isResumed => priorSeconds > 0;

  /// Elapsed training time at [now].
  Duration elapsed(DateTime now) =>
      liveDuration(priorSeconds: priorSeconds, liveSince: liveSince, now: now);

  LiveSession withDay(DateTime? day) => LiveSession(
    workoutId: workoutId,
    liveSince: liveSince,
    priorSeconds: priorSeconds,
    day: day == null ? null : dateOnly(day),
  );

  String encode() => jsonEncode({
    'workoutId': workoutId,
    'liveSince': liveSince.toUtc().toIso8601String(),
    'priorSeconds': priorSeconds,
    if (day != null) 'day': dayKey(day!),
  });

  /// Parses [raw]; null when missing or malformed (never throws).
  static LiveSession? decode(String? raw) {
    if (raw == null) return null;
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      final since = DateTime.parse(m['liveSince'] as String).toUtc();
      final dayRaw = m['day'] as String?;
      return LiveSession(
        workoutId: m['workoutId'] as String,
        liveSince: since,
        priorSeconds: (m['priorSeconds'] as num?)?.toInt() ?? 0,
        day: dayRaw == null ? null : dateOnly(DateTime.parse(dayRaw)),
      );
    } on Object {
      return null;
    }
  }

  @override
  bool operator ==(Object other) =>
      other is LiveSession &&
      other.workoutId == workoutId &&
      other.liveSince == liveSince &&
      other.priorSeconds == priorSeconds &&
      other.day == day;

  @override
  int get hashCode => Object.hash(workoutId, liveSince, priorSeconds, day);
}

/// Reads and writes the live-session record. Callers own the transaction.
extension LiveSessionStore on AppDatabase {
  static const _key = 'live_workout';

  Future<LiveSession?> readLiveSession() async => LiveSession.decode(
    (await (select(
      settings,
    )..where((s) => s.key.equals(_key))).getSingleOrNull())?.value,
  );

  Stream<LiveSession?> watchLiveSession() =>
      (select(settings)..where((s) => s.key.equals(_key)))
          .watchSingleOrNull()
          .map((r) => LiveSession.decode(r?.value));

  Future<void> writeLiveSession(LiveSession session) => into(settings)
      .insertOnConflictUpdate(
        SettingsCompanion.insert(key: _key, value: session.encode()),
      );

  /// Removes the record when it belongs to [workoutId] (or always when null).
  Future<void> clearLiveSession([String? workoutId]) async {
    if (workoutId != null) {
      final current = await readLiveSession();
      if (current != null && current.workoutId != workoutId) return;
    }
    await (delete(settings)..where((s) => s.key.equals(_key))).go();
  }
}
