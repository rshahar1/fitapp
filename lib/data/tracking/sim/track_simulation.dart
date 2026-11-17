import 'dart:async';

import 'package:fitapp/domain/tracking/track_sample.dart';
import 'package:flutter/foundation.dart';

/// What the simulation is doing.
enum SimPhase {
  /// Waiting at the session's first position, one fix a second.
  parked,

  /// Replaying the session at [TrackSimulation.speed].
  replaying,

  /// The session is over: the last position, one fix a second.
  holding,
}

/// Dev-only replay of a recorded or generated track (feature 019) with its
/// own virtual clock.
///
/// The virtual clock [now] is meant to replace the app clock. It equals the
/// real clock until a replay starts, then runs [speed] times faster; it
/// never jumps and never goes backwards. Replayed fixes are stamped on that
/// clock with the track's own spacing, so elapsed time, speeds and the
/// reducers agree at any speed. Outside a replay the clock runs at 1x and
/// the current position is repeated every second, so the tracking watchdog
/// never fires.
class TrackSimulation extends ChangeNotifier {
  /// [track] needs at least one fix, in time order. [realClock] and [tick]
  /// can be replaced in tests.
  new(
    List<TrackSample> track, {
    DateTime Function()? realClock,
    this.tick = const Duration(milliseconds: 50),
  }) : _track = List.unmodifiable(track),
       _real = realClock ?? DateTime.now {
    if (_track.isEmpty) throw ArgumentError.value(track, 'track', 'empty');
    _anchorReal = _real().toUtc();
    _anchorVirtual = _anchorReal;
    _lastEmit = _anchorVirtual;
  }

  /// Replay speeds offered in the UI.
  static const speeds = [1, 5, 10, 30];

  /// How often the timer started by [start] calls [poll].
  final Duration tick;

  final List<TrackSample> _track;
  final DateTime Function() _real;
  final _fixes = StreamController<TrackSample>.broadcast(sync: true);
  Timer? _timer;

  late DateTime _anchorReal;
  late DateTime _anchorVirtual;
  double _rate = 1;
  int _speed = 1;
  SimPhase _phase = SimPhase.parked;
  String? _sessionId;

  /// Virtual time of the replay's first fix.
  DateTime? _t0;
  int _index = 0;

  /// Timestamp of the last fix sent while parked or holding.
  late DateTime _lastEmit;

  /// Every fix sent, as the location source's position stream.
  Stream<TrackSample> get fixes => _fixes.stream;

  SimPhase get phase => _phase;

  /// The chosen replay speed (the clock runs at 1x outside a replay).
  int get speed => _speed;

  /// The tracking session being replayed into, if any.
  String? get sessionId => _sessionId;

  /// Fixes of the track sent so far in this replay, and their total.
  int get index => _index;
  int get length => _track.length;

  /// Track time reached and the track's whole duration.
  Duration get position => _index == 0
      ? Duration.zero
      : _track[_index - 1].t.difference(_track.first.t);
  Duration get duration => _track.last.t.difference(_track.first.t);

  /// The first fix of the track, as the last known position.
  TrackSample get firstFix => _track.first;

  /// The virtual clock (UTC).
  DateTime now() {
    final real = _real().toUtc().difference(_anchorReal);
    return _anchorVirtual.add(
      Duration(microseconds: (real.inMicroseconds * _rate).round()),
    );
  }

  void _setRate(double rate) {
    final at = now();
    _anchorReal = _real().toUtc();
    _anchorVirtual = at;
    _rate = rate;
  }

  /// Changes the replay speed without moving the clock.
  void setSpeed(int speed) {
    if (speed < 1) throw ArgumentError.value(speed, 'speed');
    if (speed == _speed) return;
    _speed = speed;
    if (_phase == SimPhase.replaying) _setRate(speed.toDouble());
    notifyListeners();
  }

  /// Replays the track from its start into session [sessionId]. No-op when
  /// that session is already being replayed.
  void startReplay(String sessionId) {
    if (_sessionId == sessionId) return;
    _sessionId = sessionId;
    _phase = SimPhase.replaying;
    _setRate(_speed.toDouble());
    _t0 = now();
    _index = 0;
    poll();
    notifyListeners();
  }

  /// Back to the track's first position, waiting for the next session.
  void park() {
    if (_phase == SimPhase.parked && _sessionId == null) return;
    _sessionId = null;
    _t0 = null;
    _index = 0;
    _toOneX(SimPhase.parked);
  }

  void _toOneX(SimPhase phase) {
    _setRate(1);
    _phase = phase;
    _lastEmit = now();
    notifyListeners();
  }

  /// Starts the timer that sends fixes.
  void start() => _timer ??= Timer.periodic(tick, (_) => poll());

  /// Sends every fix that is due on the virtual clock.
  void poll() {
    final at = now();
    if (_phase == SimPhase.replaying) {
      final t0 = _t0!;
      final first = _track.first.t;
      final before = _index;
      while (_index < _track.length) {
        final p = _track[_index];
        final due = t0.add(p.t.difference(first));
        if (due.isAfter(at)) break;
        _index++;
        _send(p, due);
      }
      if (_index == _track.length) {
        _toOneX(SimPhase.holding);
        _lastEmit = t0.add(_track.last.t.difference(first));
      } else if (_index != before) {
        notifyListeners();
      }
      return;
    }
    // Parked or holding: the same position once a second.
    final p = _phase == SimPhase.parked ? _track.first : _track.last;
    while (!_lastEmit.add(const Duration(seconds: 1)).isAfter(at)) {
      _lastEmit = _lastEmit.add(const Duration(seconds: 1));
      _send(p, _lastEmit, still: true);
    }
  }

  void _send(TrackSample p, DateTime t, {bool still = false}) {
    if (!_fixes.hasListener) return;
    _fixes.add(
      TrackSample(
        t: t,
        lat: p.lat,
        lon: p.lon,
        alt: p.alt,
        accuracy: p.accuracy,
        speed: still ? 0 : p.speed,
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
    unawaited(_fixes.close());
    super.dispose();
  }
}
