/// One session at a time (feature 011): names the session in progress (a gym
/// workout or a GPS tracking session) and decides whether a new gym or GPS
/// start is allowed. Every start entry point (hub, Train hero, templates)
/// uses this guard.
///
/// Pure Dart. No Flutter, database or I/O imports (constitution principle II).
library;

import 'package:fitapp/domain/activity_types.dart';
import 'package:meta/meta.dart';

/// Kind of session in progress.
enum SessionKind { gym, tracking }

/// The session in progress: a gym workout or a GPS session of a sport.
@immutable
class SessionInProgress {
  /// A gym workout without end time.
  const new gym() : kind = SessionKind.gym, typeId = null;

  /// A live GPS session of activity type [typeId].
  const new tracking(String this.typeId) : kind = SessionKind.tracking;

  final SessionKind kind;

  /// Activity type id; only for [SessionKind.tracking].
  final String? typeId;

  /// "Workout", or the sport name ("Activity" for unknown ids).
  String get label => switch (kind) {
    SessionKind.gym => 'Workout',
    SessionKind.tracking => activityLabel(typeId!),
  };

  /// "Continue workout" / "Continue running".
  String get continueLabel => 'Continue ${label.toLowerCase()}';

  /// Shown when a start is refused because this session is in progress.
  String get blockedMessage => '$label in progress. Finish it first.';

  @override
  bool operator ==(Object other) =>
      other is SessionInProgress &&
      other.kind == kind &&
      other.typeId == typeId;

  @override
  int get hashCode => Object.hash(kind, typeId);

  @override
  String toString() => 'SessionInProgress($kind, $typeId)';
}

/// The session in progress, or null. A tracking session wins if both exist
/// (the repositories refuse that state, so it only guards against bad data).
SessionInProgress? sessionInProgress({
  required bool hasActiveWorkout,
  String? trackingTypeId,
}) {
  if (trackingTypeId != null) return SessionInProgress.tracking(trackingTypeId);
  if (hasActiveWorkout) return const SessionInProgress.gym();
  return null;
}

/// Whether a new gym or GPS session may start while [current] is in progress.
bool canStart(SessionInProgress? current) => current == null;
