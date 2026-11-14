/// Pure reducer turning GPS fixes into track metrics (feature 010).
library;

import 'package:fitapp/domain/tracking/geo.dart';
import 'package:fitapp/domain/tracking/track_profile.dart';
import 'package:fitapp/domain/tracking/track_sample.dart';
import 'package:fitapp/domain/tracking/track_state.dart';
import 'package:meta/meta.dart';

/// Fixes less accurate than this (in metres) are ignored.
const maxAccuracyMeters = 20.0;

/// Elevation changes smaller than this (in metres) are treated as noise.
const elevationHysteresisMeters = 3.0;

/// Window for [TrackState.currentSpeedMps].
const currentSpeedWindow = Duration(seconds: 30);

/// Window used to decide whether the user stands still.
const autoPauseWindow = Duration(seconds: 5);

/// A manual pause: [start] until [end] (null while still paused).
@immutable
class PauseInterval {
  const new({required this.start, this.end});

  final DateTime start;
  final DateTime? end;
}

/// A fresh state for a track started at [t].
TrackState start(DateTime t) => TrackState(startedAt: t);

/// Manually pauses at [t]. No-op when already paused.
TrackState pause(TrackState s, DateTime t) {
  if (s.manualPaused) return s;
  return s.copyWith(
    manualPaused: true,
    pausedAt: t,
    clearSlowSince: true,
    slowMovingSeconds: 0,
  );
}

/// Resumes at [t]. No-op when not manually paused.
TrackState resume(TrackState s, DateTime t) {
  if (!s.manualPaused) return s;
  final from = s.pausedAt ?? t;
  final last = s.lastAccepted;
  return s.copyWith(
    manualPaused: false,
    autoPaused: false,
    clearPausedAt: true,
    pausedTotal: s.pausedTotal + t.difference(from),
    window: last == null ? const [] : [(t: last.t, d: s.pathMeters)],
  );
}

/// Elapsed time at [now], excluding manual pauses.
Duration elapsedAt(TrackState s, DateTime now) {
  final open = s.pausedAt == null ? Duration.zero : now.difference(s.pausedAt!);
  final total = now.difference(s.startedAt) - s.pausedTotal - open;
  return total.isNegative ? Duration.zero : total;
}

/// Folds one fix into [s]. Rejected fixes (accuracy worse than
/// [maxAccuracyMeters], implied speed above the profile maximum, or a
/// non-increasing timestamp) return [s] unchanged.
TrackState accumulate(TrackState s, TrackSample p, TrackProfile profile) {
  if (p.accuracy > maxAccuracyMeters) return s;
  final prev = s.lastAccepted;
  if (prev == null) {
    return s.copyWith(
      lastAccepted: p,
      window: [(t: p.t, d: s.pathMeters)],
      elevationRef: p.alt,
    );
  }
  final dt = p.t.difference(prev.t).inMicroseconds / 1e6;
  if (dt <= 0) return s;
  final d = haversineMeters(prev.lat, prev.lon, p.lat, p.lon);
  if (d / dt > profile.maxSpeedMps) return s;

  if (s.manualPaused) {
    return s.copyWith(lastAccepted: p, window: [(t: p.t, d: s.pathMeters)]);
  }

  final path = s.pathMeters + d;
  final window = [...s.window, (t: p.t, d: path)];
  final cutoff = p.t.subtract(currentSpeedWindow);
  while (window.length > 2 && !window[1].t.isAfter(cutoff)) {
    window.removeAt(0);
  }
  final speed30 = _speed(window.first, window.last);

  final mark = p.t.subtract(autoPauseWindow);
  var ref = window.first;
  for (final m in window) {
    if (m.t.isAfter(mark)) break;
    ref = m;
  }
  final slow = _speed(ref, window.last) < profile.autoPauseSpeedMps;

  var moving = s.movingSeconds;
  var slowMoving = 0.0;
  DateTime? slowSince;
  var autoPaused = false;
  var counted = true;
  if (slow) {
    slowSince = s.slowSince ?? prev.t;
    autoPaused = p.t.difference(slowSince) >= profile.autoPauseDelay;
    if (autoPaused) {
      counted = false;
      if (!s.autoPaused) {
        moving = (moving - s.slowMovingSeconds).clamp(0, double.infinity);
      }
    } else {
      slowMoving = s.slowMovingSeconds + dt;
    }
  }

  var distance = s.distanceMeters;
  var splits = s.completedSplits;
  var lastSplitMoving = s.lastSplitMoving;
  var gain = s.elevationGainMeters;
  var elevRef = s.elevationRef;
  if (counted) {
    final before = distance;
    distance += d;
    var next = splits.length + 1;
    while (distance >= next * 1000) {
      final frac = d == 0 ? 0 : (next * 1000 - before) / d;
      final at = moving + dt * frac;
      splits = [...splits, (at - lastSplitMoving).clamp(0, 1e9).round()];
      lastSplitMoving = at;
      next++;
    }
    moving += dt;
    final alt = p.alt;
    if (alt != null) {
      if (elevRef == null) {
        elevRef = alt;
      } else if (alt - elevRef >= elevationHysteresisMeters) {
        gain += alt - elevRef;
        elevRef = alt;
      } else if (elevRef - alt >= elevationHysteresisMeters) {
        elevRef = alt;
      }
    }
  }

  return s.copyWith(
    distanceMeters: distance,
    movingSeconds: moving,
    autoPaused: autoPaused,
    completedSplits: splits,
    elevationGainMeters: gain,
    currentSpeedMps: autoPaused ? 0 : speed30,
    lastAccepted: p,
    pathMeters: path,
    window: window,
    slowSince: slowSince,
    clearSlowSince: slowSince == null,
    slowMovingSeconds: slowMoving,
    lastSplitMoving: lastSplitMoving,
    elevationRef: elevRef,
  );
}

double _speed(PathMark a, PathMark b) {
  final secs = b.t.difference(a.t).inMicroseconds / 1e6;
  return secs <= 0 ? 0 : (b.d - a.d) / secs;
}

/// Manual pauses derived from the `paused` flags of [samples]: a pause starts
/// at the first flagged fix and ends at the next unflagged one.
List<PauseInterval> pausesFromFlags(List<TrackSample> samples) {
  final out = <PauseInterval>[];
  DateTime? openedAt;
  for (final s in samples) {
    if (s.paused && openedAt == null) {
      openedAt = s.t;
    } else if (!s.paused && openedAt != null) {
      out.add(PauseInterval(start: openedAt, end: s.t));
      openedAt = null;
    }
  }
  if (openedAt != null) out.add(PauseInterval(start: openedAt));
  return out;
}

/// Rebuilds the state of a track that started at [startedAt] from its ordered
/// [samples]. Manual pauses come from [pauses] when given (exact), otherwise
/// from the samples' `paused` flags. An open last pause leaves the state
/// manually paused.
TrackState replay(
  DateTime startedAt,
  List<TrackSample> samples,
  TrackProfile profile, {
  List<PauseInterval>? pauses,
}) => _run(startedAt, samples, profile, pauses, null);

/// The samples of [samples] that [accumulate] accepts, in order.
List<TrackSample> acceptedSamples(
  DateTime startedAt,
  List<TrackSample> samples,
  TrackProfile profile, {
  List<PauseInterval>? pauses,
}) {
  final out = <TrackSample>[];
  _run(startedAt, samples, profile, pauses, out);
  return out;
}

TrackState _run(
  DateTime startedAt,
  List<TrackSample> samples,
  TrackProfile profile,
  List<PauseInterval>? pauses,
  List<TrackSample>? accepted,
) {
  final intervals = pauses ?? pausesFromFlags(samples);
  var s = start(startedAt);
  var next = 0;
  var open = false;

  // Applies pause/resume events up to [t] (all of them when null).
  void applyUntil(DateTime? t) {
    while (next < intervals.length) {
      final iv = intervals[next];
      if (!open) {
        if (t != null && iv.start.isAfter(t)) return;
        s = pause(s, iv.start);
        open = true;
      }
      final end = iv.end;
      if (end == null || (t != null && end.isAfter(t))) return;
      s = resume(s, end);
      open = false;
      next++;
    }
  }

  for (final p in samples) {
    applyUntil(p.t);
    s = accumulate(s, p, profile);
    if (accepted != null && identical(s.lastAccepted, p)) accepted.add(p);
  }
  applyUntil(null);
  return s;
}
