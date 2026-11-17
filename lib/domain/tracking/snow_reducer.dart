/// Pure reducer classifying GPS fixes of a snowboarding day into runs, lifts
/// and rests (feature 017, see specs/017-snowboard-live-tracking/plan.md).
library;

import 'package:fitapp/domain/tracking/geo.dart';
import 'package:fitapp/domain/tracking/snow_state.dart';
import 'package:fitapp/domain/tracking/track_sample.dart';
import 'package:meta/meta.dart';

/// Thresholds of the classification. Speeds in m/s, heights in metres.
@immutable
class SnowTuning {
  const new({
    this.speedWindow = const Duration(seconds: 5),
    this.altWindow = const Duration(seconds: 15),
    this.rateWindow = const Duration(seconds: 30),
    this.minRateSpan = const Duration(seconds: 10),
    this.shortRateWindow = const Duration(seconds: 10),
    this.gap = const Duration(seconds: 10),
    this.liftClimbRate = 0.25,
    this.liftMinSpeed = 0.8,
    this.runMinSpeed = 2.0,
    this.runMaxClimbRate = 0.10,
    this.restMaxSpeed = 1.0,
    this.liftConfirmGain = 15,
    this.runConfirm = const Duration(seconds: 10),
    this.runConfirmDrop = 6,
    this.runConfirmMeters = 60,
    this.restConfirm = const Duration(seconds: 10),
    this.liftRestConfirm = const Duration(seconds: 120),
    this.hysteresis = 5,
    this.minRunDrop = 30,
    this.falseRunMax = const Duration(seconds: 60),
    this.falseRunMaxDrop = 5,
  });

  /// Window of the speed computed from positions (no device speed).
  final Duration speedWindow;

  /// Window of the altitude median.
  final Duration altWindow;

  /// Window of the vertical rate, and the shortest span it needs.
  final Duration rateWindow;
  final Duration minRateSpan;

  /// Window telling whether the altitude is still rising right now.
  final Duration shortRateWindow;

  /// A longer silence between two fixes is a gap.
  final Duration gap;

  /// A fix is on a lift when climbing at least this fast, while moving.
  final double liftClimbRate;
  final double liftMinSpeed;

  /// A fix is riding at this speed or more, unless climbing faster than
  /// [runMaxClimbRate].
  final double runMinSpeed;
  final double runMaxClimbRate;

  /// A fix is resting below this speed.
  final double restMaxSpeed;

  /// Net gain that confirms a lift.
  final double liftConfirmGain;

  /// A run is confirmed after [runConfirm] and either drop or distance.
  final Duration runConfirm;
  final double runConfirmDrop;
  final double runConfirmMeters;

  /// How long standing still must last: on the slope, and on a lift.
  final Duration restConfirm;
  final Duration liftRestConfirm;

  /// Altitude changes smaller than this are noise.
  final double hysteresis;

  /// A descent counts as a run from this drop.
  final double minRunDrop;

  /// A "run" this short and flat right before a lift is the lift's start.
  final Duration falseRunMax;
  final double falseRunMaxDrop;
}

/// The default thresholds.
const snowTuning = SnowTuning();

/// A fresh state.
SnowState startSnow() => const SnowState();

double _seconds(Duration d) => d.inMicroseconds / 1e6;

double _median(Iterable<double> values) {
  final v = values.toList()..sort();
  final mid = v.length ~/ 2;
  return v.length.isOdd ? v[mid] : (v[mid - 1] + v[mid]) / 2;
}

/// [marks] plus [m], without the marks older than [window] (the newest of
/// those is kept so the window is always fully covered).
List<SnowMark> _slide(List<SnowMark> marks, SnowMark m, Duration window) {
  final out = [...marks, m];
  final cutoff = m.t.subtract(window);
  while (out.length > 2 && !out[1].t.isAfter(cutoff)) {
    out.removeAt(0);
  }
  return out;
}

double? _rate(List<SnowMark> marks, Duration window, Duration minSpan) {
  if (marks.length < 2) return null;
  final cutoff = marks.last.t.subtract(window);
  var first = marks.first;
  for (final m in marks) {
    if (m.t.isAfter(cutoff)) break;
    first = m;
  }
  // The oldest mark inside the window, or the newest one before it.
  final span = _seconds(marks.last.t.difference(first.t));
  return span < _seconds(minSpan) ? null : (marks.last.v - first.v) / span;
}

/// Number of runs so far: descents (everything between two lifts) with at
/// least [SnowTuning.minRunDrop] of vertical drop.
int snowRunCount(SnowState s, [SnowTuning k = snowTuning]) =>
    s.closedRuns + (s.currentDescentDropMeters >= k.minRunDrop ? 1 : 0);

/// Ends the segment in progress at its last fix, e.g. for a manual pause or
/// to summarise. The next fix starts a new rest; nothing is measured across.
SnowState pauseSnow(SnowState s) {
  final cur = s.current;
  if (cur == null) return s;
  return _closed(s, cur);
}

SnowState _closed(SnowState s, SnowSegment cur) {
  final t = _Totals.of(s)..add(cur);
  return SnowState(
    segments: t.segments,
    count: s.count,
    closedRideSeconds: t.ride,
    closedLiftSeconds: t.lift,
    closedRestSeconds: t.rest,
    closedRideMeters: t.meters,
    closedDropMeters: t.drop,
    closedMaxSpeedMps: t.maxSpeed,
    closedRuns: s.closedRuns,
    descentDropMeters: t.descentDrop,
  );
}

/// Mutable totals while one fix closes segments.
class _Totals {
  new of(SnowState s)
    : segments = s.segments,
      ride = s.closedRideSeconds,
      lift = s.closedLiftSeconds,
      rest = s.closedRestSeconds,
      meters = s.closedRideMeters,
      drop = s.closedDropMeters,
      maxSpeed = s.closedMaxSpeedMps,
      runs = s.closedRuns,
      descentDrop = s.descentDropMeters;

  List<SnowSegment> segments;
  double ride;
  double lift;
  double rest;
  double meters;
  double drop;
  double maxSpeed;
  int runs;
  double descentDrop;

  /// Appends [open] as a finished segment (zero-length ones are skipped).
  void add(SnowSegment open) {
    if (open.lastIndex == open.firstIndex) return;
    final seg = open.sealed();
    segments = [...segments, seg];
    switch (seg.kind) {
      case SnowKind.run:
        ride += seg.seconds;
        meters += seg.distanceMeters;
        drop += seg.descentMeters;
        descentDrop += seg.descentMeters;
        if (seg.maxSpeedMps > maxSpeed) maxSpeed = seg.maxSpeedMps;
      case SnowKind.lift:
        lift += seg.seconds;
      case SnowKind.rest:
        rest += seg.seconds;
    }
  }

  /// A lift begins: the descent before it is over.
  void endDescent(SnowTuning k) {
    if (descentDrop >= k.minRunDrop) runs++;
    descentDrop = 0;
  }
}

/// Folds one fix into [s]. Feed only fixes the track reducer accepted while
/// not manually paused, in order; a fix not after the previous one is
/// ignored.
SnowState accumulateSnow(
  SnowState s,
  TrackSample p, [
  SnowTuning k = snowTuning,
]) {
  final prev = s.last;
  final index = s.count;
  var dt = 0.0;
  var meters = 0.0;
  if (prev != null) {
    dt = _seconds(p.t.difference(prev.t));
    if (dt <= 0) return s;
    meters = haversineMeters(prev.lat, prev.lon, p.lat, p.lon);
  }
  final gap = dt > _seconds(k.gap);

  // --- Signals -------------------------------------------------------------
  final path = s.pathMeters + meters;
  final pathMark = (t: p.t, v: path);
  final speedWindow = gap
      ? [pathMark]
      : _slide(s.speedWindow, pathMark, k.speedWindow);
  final speed =
      p.speed ??
      (gap ? 0.0 : _rate(speedWindow, k.speedWindow, Duration.zero) ?? 0.0);

  final rawAlt = p.alt;
  final altWindow = rawAlt == null
      ? (gap ? const <SnowMark>[] : s.altWindow)
      : gap
      ? [(t: p.t, v: rawAlt)]
      : _slide(s.altWindow, (t: p.t, v: rawAlt), k.altWindow);
  final recentAlts = [
    for (final m in altWindow)
      if (m.t.isAfter(p.t.subtract(k.altWindow))) m.v,
  ];
  final alt = recentAlts.isEmpty ? null : _median(recentAlts);

  final smoothWindow = alt == null
      ? (gap ? const <SnowMark>[] : s.smoothWindow)
      : gap
      ? [(t: p.t, v: alt)]
      : _slide(s.smoothWindow, (t: p.t, v: alt), k.rateWindow);
  final rate = _rate(smoothWindow, k.rateWindow, k.minRateSpan);
  final shortRate = _rate(
    smoothWindow,
    k.shortRateWindow,
    k.shortRateWindow ~/ 2,
  );

  final recentSpeeds = [if (!gap) ...s.recentSpeeds, speed];
  if (recentSpeeds.length > 3) recentSpeeds.removeAt(0);
  // A lone spike never sets the maximum: with fewer than three speeds the
  // lowest counts.
  final filtered = recentSpeeds.length == 3
      ? _median(recentSpeeds)
      : recentSpeeds.reduce((a, b) => a < b ? a : b);

  SnowState next({
    required _Totals totals,
    required SnowSegment current,
    SnowSegment? candidate,
    SnowSegment? beforeCandidate,
    SnowSegment? liftMark,
    SnowSegment? moveMark,
  }) => SnowState(
    segments: totals.segments,
    current: current,
    candidate: candidate,
    beforeCandidate: beforeCandidate,
    liftMark: liftMark,
    moveMark: moveMark,
    count: index + 1,
    last: p,
    pathMeters: path,
    speedWindow: speedWindow,
    altWindow: altWindow,
    smoothWindow: smoothWindow,
    recentSpeeds: recentSpeeds,
    speedMps: speed,
    closedRideSeconds: totals.ride,
    closedLiftSeconds: totals.lift,
    closedRestSeconds: totals.rest,
    closedRideMeters: totals.meters,
    closedDropMeters: totals.drop,
    closedMaxSpeedMps: totals.maxSpeed,
    closedRuns: totals.runs,
    descentDropMeters: totals.descentDrop,
  );

  final totals = _Totals.of(s);
  final before = s.current;
  if (before == null) {
    // First fix, or first after a pause: a rest begins here.
    return next(
      totals: totals,
      current: SnowSegment.at(SnowKind.rest, index, p.t, alt),
    );
  }

  SnowSegment stepped(SnowSegment seg) => seg.step(
    index: index,
    t: p.t,
    meters: meters,
    alt: alt,
    speed: filtered,
    hysteresis: k.hysteresis,
  );

  // --- Raw label -----------------------------------------------------------
  final SnowKind? label;
  if (gap) {
    // Silence: resting, unless a lift carried on climbing through it.
    final from = before.endAlt;
    final climbed =
        before.kind == SnowKind.lift &&
        alt != null &&
        from != null &&
        alt - from >= k.liftConfirmGain;
    label = climbed ? SnowKind.lift : SnowKind.rest;
  } else if (rate != null &&
      rate >= k.liftClimbRate &&
      speed >= k.liftMinSpeed &&
      (shortRate == null || shortRate > 0)) {
    label = SnowKind.lift;
  } else if (speed >= k.runMinSpeed &&
      (rate == null || rate <= k.runMaxClimbRate)) {
    label = SnowKind.run;
  } else if (speed < k.restMaxSpeed) {
    label = SnowKind.rest;
  } else {
    label = null;
  }

  // --- Advance the open segments ------------------------------------------
  final current = stepped(before);
  var candidate = s.candidate == null ? null : stepped(s.candidate!);
  var beforeCandidate = s.beforeCandidate;

  // Where the rider started moving out of a rest (a lift is backdated there).
  SnowSegment? moveMark;
  if (before.kind == SnowKind.rest && !gap && speed >= k.liftMinSpeed) {
    moveMark = s.moveMark ?? before;
  }
  // The lift as of its last climbing fix at a new height: the smoothed
  // altitude keeps rising for a few seconds after the top.
  final SnowSegment? liftMark;
  if (current.kind != SnowKind.lift) {
    liftMark = null;
  } else {
    final mark = s.liftMark;
    final high = mark?.endAlt;
    final now = current.endAlt;
    final higher = high == null || now == null || now >= high;
    liftMark = label == SnowKind.lift && higher ? current : mark;
  }

  if (label == current.kind) {
    candidate = null;
    beforeCandidate = null;
  } else if (label != null) {
    if (candidate == null || candidate.kind != label) {
      if (gap) {
        // The silence itself belongs to the rest.
        beforeCandidate = before;
        candidate = stepped(
          SnowSegment.at(label, before.lastIndex, before.end, before.endAlt),
        );
      } else if (label == SnowKind.lift && moveMark != null) {
        beforeCandidate = moveMark;
        candidate = _since(current, moveMark, label, k);
      } else {
        beforeCandidate = current;
        candidate = SnowSegment.at(label, index, p.t, alt);
      }
    }
    if (_confirmed(candidate, current.kind, k)) {
      return _switch(
        totals: totals,
        from: beforeCandidate!,
        to: candidate,
        liftMark: liftMark,
        k: k,
        build: next,
      );
    }
  }

  return next(
    totals: totals,
    current: current,
    candidate: candidate,
    beforeCandidate: beforeCandidate,
    liftMark: liftMark,
    moveMark: moveMark,
  );
}

/// The part of [current] after [mark], as a segment of [kind].
SnowSegment _since(
  SnowSegment current,
  SnowSegment mark,
  SnowKind kind,
  SnowTuning k,
) {
  final from = mark.endAlt;
  final to = current.endAlt;
  var up = 0.0;
  var ref = from;
  if (from != null && to != null && to - from >= k.hysteresis) {
    up = to - from;
    ref = to;
  }
  return SnowSegment(
    kind: kind,
    firstIndex: mark.lastIndex,
    lastIndex: current.lastIndex,
    start: mark.end,
    end: current.end,
    distanceMeters: current.distanceMeters - mark.distanceMeters,
    ascentMeters: up,
    startAlt: from ?? to,
    endAlt: to,
    altRef: ref ?? to,
  );
}

bool _confirmed(SnowSegment c, SnowKind from, SnowTuning k) {
  switch (c.kind) {
    case SnowKind.lift:
      return -c.netDropMeters >= k.liftConfirmGain;
    case SnowKind.run:
      if (c.seconds < _seconds(k.runConfirm)) return false;
      if (c.netDropMeters >= k.runConfirmDrop) return true;
      // Off a lift only a real drop counts: cabins also cross flat ground.
      return from != SnowKind.lift && c.distanceMeters >= k.runConfirmMeters;
    case SnowKind.rest:
      final need = from == SnowKind.lift ? k.liftRestConfirm : k.restConfirm;
      return c.seconds >= _seconds(need);
  }
}

/// Closes [from] and makes [to] the segment in progress.
SnowState _switch({
  required _Totals totals,
  required SnowSegment from,
  required SnowSegment to,
  required SnowSegment? liftMark,
  required SnowTuning k,
  required SnowState Function({
    required _Totals totals,
    required SnowSegment current,
    SnowSegment? candidate,
    SnowSegment? beforeCandidate,
    SnowSegment? liftMark,
    SnowSegment? moveMark,
  })
  build,
}) {
  var closing = from;
  var opening = to;

  if (from.kind == SnowKind.lift) {
    // A lift ends at its last climbing fix; what follows is standing at the
    // top station.
    final top = liftMark ?? from;
    if (top.lastIndex < from.lastIndex) {
      final wait = SnowSegment(
        kind: SnowKind.rest,
        firstIndex: top.lastIndex,
        lastIndex: from.lastIndex,
        start: top.end,
        end: from.end,
        distanceMeters: from.distanceMeters - top.distanceMeters,
        startAlt: top.endAlt,
        endAlt: from.endAlt,
        altRef: from.endAlt,
      );
      closing = top;
      if (to.kind == SnowKind.rest) {
        opening = to.copyWith(
          firstIndex: wait.firstIndex,
          start: wait.start,
          distanceMeters: wait.distanceMeters + to.distanceMeters,
          startAlt: wait.startAlt,
        );
      } else if (wait.seconds >= _seconds(k.restConfirm)) {
        totals
          ..add(top)
          ..add(wait);
        // Both are stored already: nothing is left to close (zero-length
        // segments are skipped).
        closing = SnowSegment.at(SnowKind.rest, 0, to.start, null);
      } else {
        // Straight off the lift: the run began at the top.
        final high = wait.startAlt;
        final low = to.startAlt;
        opening = to.copyWith(
          firstIndex: wait.firstIndex,
          start: wait.start,
          distanceMeters: wait.distanceMeters + to.distanceMeters,
          descentMeters:
              to.descentMeters +
              (high != null && low != null && high > low ? high - low : 0),
          startAlt: high,
        );
      }
    }
  } else if (from.kind == SnowKind.run && to.kind == SnowKind.rest) {
    // By the time a stop is confirmed the smoothed altitude has caught up
    // with where the run ended.
    final settled = to.endAlt;
    if (settled != null) {
      closing = from.settledAt(settled);
      opening = SnowSegment(
        kind: SnowKind.rest,
        firstIndex: to.firstIndex,
        lastIndex: to.lastIndex,
        start: to.start,
        end: to.end,
        distanceMeters: to.distanceMeters,
        startAlt: settled,
        endAlt: settled,
        altRef: settled,
      );
    }
  }

  final falseRun =
      to.kind == SnowKind.lift &&
      closing.kind == SnowKind.run &&
      closing.lastIndex > closing.firstIndex &&
      closing.seconds < _seconds(k.falseRunMax) &&
      closing.netDropMeters < k.falseRunMaxDrop;
  if (falseRun) {
    // The first seconds of a lift look like riding on the flat.
    final from0 = closing.startAlt ?? opening.startAlt;
    final lower = opening.startAlt;
    final extra = from0 != null && lower != null && lower > from0
        ? lower - from0
        : 0.0;
    opening = opening.copyWith(
      firstIndex: closing.firstIndex,
      start: closing.start,
      distanceMeters: closing.distanceMeters + opening.distanceMeters,
      ascentMeters: opening.ascentMeters + extra,
      startAlt: from0,
    );
  } else {
    totals.add(closing);
  }
  if (opening.kind == SnowKind.lift) totals.endDescent(k);

  return build(
    totals: totals,
    current: opening,
    liftMark: opening.kind == SnowKind.lift ? opening : null,
  );
}

/// Rebuilds the state from the fixes the track reducer accepted, in order.
/// Fixes flagged `paused` are skipped and end the segment in progress.
SnowState replaySnow(
  Iterable<TrackSample> accepted, [
  SnowTuning k = snowTuning,
]) {
  var s = startSnow();
  for (final p in accepted) {
    s = p.paused ? pauseSnow(s) : accumulateSnow(s, p, k);
  }
  return s;
}
