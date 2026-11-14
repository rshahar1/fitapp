/// Summary of a finished live track (feature 010). Pure Dart.
library;

import 'package:fitapp/domain/tracking/geo.dart';
import 'package:fitapp/domain/tracking/track_reducer.dart';
import 'package:fitapp/domain/tracking/track_sample.dart';
import 'package:fitapp/domain/tracking/track_state.dart';
import 'package:meta/meta.dart';

/// Route simplification tolerance in metres.
const routeToleranceMeters = 5.0;

/// What is kept of a track once its raw points are deleted.
@immutable
class TrackSummary {
  const new({
    required this.distanceMeters,
    required this.durationMinutes,
    required this.movingSeconds,
    required this.elevationGainMeters,
    required this.route,
    required this.splits,
  });

  final int distanceMeters;

  /// Elapsed time (excluding manual pauses) rounded to minutes, at least 1.
  final int durationMinutes;
  final int movingSeconds;
  final int elevationGainMeters;

  /// Encoded polyline (precision 5) of the simplified route.
  final String route;

  /// Seconds of each completed full kilometre.
  final List<int> splits;
}

/// Summarises [state] with the accepted [samples]. The elapsed time ends at
/// [endedAt], defaulting to the last sample's time.
TrackSummary summarize(
  TrackState state,
  List<TrackSample> samples, {
  DateTime? endedAt,
}) {
  final end = endedAt ?? (samples.isEmpty ? state.startedAt : samples.last.t);
  final minutes = (elapsedAt(state, end).inSeconds / 60).round();
  final points = simplify([
    for (final s in samples) (lat: s.lat, lon: s.lon),
  ], routeToleranceMeters);
  return TrackSummary(
    distanceMeters: state.distanceMeters.round(),
    durationMinutes: minutes < 1 ? 1 : minutes,
    movingSeconds: state.movingSeconds.round(),
    elevationGainMeters: state.elevationGainMeters.round(),
    route: encodePolyline(points),
    splits: List.unmodifiable(state.completedSplits),
  );
}
