import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:fitapp/data/db/app_database.dart';
import 'package:fitapp/domain/activity_types.dart';
import 'package:fitapp/domain/tracking/track_profile.dart';
import 'package:fitapp/domain/tracking/track_reducer.dart';
import 'package:fitapp/domain/tracking/track_sample.dart';
import 'package:fitapp/domain/tracking/track_state.dart';
import 'package:fitapp/domain/tracking/track_summary.dart';
import 'package:uuid/uuid.dart';

/// The in-progress GPS tracking session and its raw points (feature 010).
class TrackingRepository {
  new(this._db);

  final AppDatabase _db;
  static const _uuid = Uuid();

  /// Starts a session. Throws [ArgumentError] when [typeId] has no live
  /// tracking, [StateError] when a session or a gym workout is in progress.
  Future<String> start({required String typeId, required DateTime startedAt}) {
    if (activityTypeById(typeId)?.hasLiveTracking != true) {
      throw ArgumentError.value(typeId, 'typeId', 'no live tracking');
    }
    return _db.transaction(() async {
      if (await session() != null) {
        throw StateError('A tracking session is already in progress');
      }
      final workout = await (_db.select(
        _db.workouts,
      )..where((w) => w.endedAt.isNull())).get();
      if (workout.isNotEmpty) {
        throw StateError('A workout is already in progress');
      }
      final id = _uuid.v4();
      await _db
          .into(_db.trackingSessions)
          .insert(
            TrackingSessionsCompanion.insert(
              id: id,
              typeId: typeId,
              state: 'active',
              startedAt: startedAt.toUtc(),
              updatedAt: _db.now(),
            ),
          );
      return id;
    });
  }

  /// The current session, or null.
  Future<TrackingSessionRow?> session() =>
      (_db.select(_db.trackingSessions)..limit(1)).getSingleOrNull();

  Stream<TrackingSessionRow?> watchSession() =>
      (_db.select(_db.trackingSessions)..limit(1)).watchSingleOrNull();

  Future<TrackingSessionRow> _require(String sessionId) async {
    final row = await (_db.select(
      _db.trackingSessions,
    )..where((s) => s.id.equals(sessionId))).getSingleOrNull();
    if (row == null) throw StateError('Tracking session not found');
    return row;
  }

  /// Appends [samples] in one transaction, continuing the sequence numbers.
  Future<void> appendPoints(String sessionId, List<TrackSample> samples) {
    if (samples.isEmpty) return Future.value();
    return _db.transaction(() async {
      await _require(sessionId);
      final maxSeq = _db.trackPoints.seq.max();
      final last =
          await (_db.selectOnly(_db.trackPoints)
                ..addColumns([maxSeq])
                ..where(_db.trackPoints.sessionId.equals(sessionId)))
              .map((r) => r.read(maxSeq))
              .getSingle();
      var seq = (last ?? -1) + 1;
      await _db.batch((b) {
        b.insertAll(_db.trackPoints, [
          for (final s in samples)
            TrackPointsCompanion.insert(
              sessionId: sessionId,
              seq: seq++,
              t: s.t.toUtc(),
              lat: s.lat,
              lon: s.lon,
              alt: Value(s.alt),
              accuracy: s.accuracy,
              speed: Value(s.speed),
              paused: Value(s.paused),
            ),
        ]);
      });
    });
  }

  /// Pauses or resumes at [at]. No-op when already in that state.
  Future<void> setPaused(
    String sessionId, {
    required bool paused,
    required DateTime at,
  }) => _db.transaction(() async {
    final row = await _require(sessionId);
    final isPaused = row.state == 'paused';
    if (isPaused == paused) return;
    final now = _db.now();
    if (paused) {
      await (_db.update(
        _db.trackingSessions,
      )..where((s) => s.id.equals(sessionId))).write(
        TrackingSessionsCompanion(
          state: const Value('paused'),
          pausedAt: Value(at.toUtc()),
          updatedAt: Value(now),
        ),
      );
    } else {
      final from = row.pausedAt ?? at;
      final add = at.difference(from).inMilliseconds;
      await (_db.update(
        _db.trackingSessions,
      )..where((s) => s.id.equals(sessionId))).write(
        TrackingSessionsCompanion(
          state: const Value('active'),
          pausedAt: const Value(null),
          pausedMs: Value(row.pausedMs + (add < 0 ? 0 : add)),
          updatedAt: Value(now),
        ),
      );
    }
  });

  /// The stored points of [sessionId], in order.
  Future<List<TrackSample>> loadPoints(String sessionId) async {
    final rows =
        await (_db.select(_db.trackPoints)
              ..where((p) => p.sessionId.equals(sessionId))
              ..orderBy([(p) => OrderingTerm.asc(p.seq)]))
            .get();
    return [
      for (final r in rows)
        TrackSample(
          t: r.t.toUtc(),
          lat: r.lat,
          lon: r.lon,
          alt: r.alt,
          accuracy: r.accuracy,
          speed: r.speed,
          paused: r.paused,
        ),
    ];
  }

  /// Manual pauses of [row]: derived from the points' flags, with a pause
  /// still open at `row.pausedAt` starting exactly there.
  static List<PauseInterval> pausesOf(
    TrackingSessionRow row,
    List<TrackSample> points,
  ) {
    final pauses = pausesFromFlags(points);
    final at = row.pausedAt?.toUtc();
    if (row.state == 'paused' && at != null) {
      if (pauses.isNotEmpty && pauses.last.end == null) {
        pauses[pauses.length - 1] = PauseInterval(start: at);
      } else {
        pauses.add(PauseInterval(start: at));
      }
    }
    return pauses;
  }

  /// Rebuilds the metrics of [row] from its [points].
  static TrackState replayState(
    TrackingSessionRow row,
    List<TrackSample> points,
  ) => replay(
    row.startedAt.toUtc(),
    points,
    TrackProfile.forType(row.typeId),
    pauses: pausesOf(row, points),
  );

  /// Turns the session into an activity (source 'gps') and deletes its
  /// points and the session, all in one transaction. Returns the activity id.
  Future<String> finish(
    String sessionId, {
    required DateTime endedAt,
    String? notes,
  }) => _db.transaction(() async {
    final row = await _require(sessionId);
    final points = await loadPoints(sessionId);
    final profile = TrackProfile.forType(row.typeId);
    final started = row.startedAt.toUtc();
    final pauses = pausesOf(row, points);
    final state = replay(started, points, profile, pauses: pauses);
    final accepted = acceptedSamples(started, points, profile, pauses: pauses);
    final summary = summarize(state, accepted, endedAt: endedAt.toUtc());
    final now = _db.now();
    final distance = summary.distanceMeters;
    final v = validateActivity(
      typeId: row.typeId,
      startedAt: started,
      now: now,
      durationMinutes: summary.durationMinutes,
      distanceMeters: distance > 0 ? distance : null,
      notes: notes,
    );
    final id = _uuid.v4();
    await _db
        .into(_db.activities)
        .insert(
          ActivitiesCompanion.insert(
            id: id,
            typeId: v.typeId,
            startedAt: v.startedAt.toUtc(),
            durationMinutes: Value(v.durationMinutes),
            distanceMeters: Value(v.distanceMeters),
            notes: Value(v.notes),
            source: const Value('gps'),
            movingSeconds: Value(summary.movingSeconds),
            elevationGainMeters: Value(summary.elevationGainMeters),
            route: Value(summary.route),
            splits: Value(jsonEncode(summary.splits)),
            updatedAt: now,
          ),
        );
    await _deleteSession(sessionId);
    return id;
  });

  /// Throws the session and its points away.
  Future<void> discard(String sessionId) =>
      _db.transaction(() => _deleteSession(sessionId));

  Future<void> _deleteSession(String sessionId) async {
    await (_db.delete(
      _db.trackPoints,
    )..where((p) => p.sessionId.equals(sessionId))).go();
    await (_db.delete(
      _db.trackingSessions,
    )..where((s) => s.id.equals(sessionId))).go();
  }
}
