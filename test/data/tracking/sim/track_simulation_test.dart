import 'dart:async';

import 'package:fitapp/data/tracking/location_source.dart';
import 'package:fitapp/data/tracking/sim/simulated_location_source.dart';
import 'package:fitapp/data/tracking/sim/track_simulation.dart';
import 'package:fitapp/domain/tracking/track_sample.dart';
import 'package:flutter_test/flutter_test.dart';

final _t0 = DateTime.utc(2026);
final _real0 = DateTime.utc(2026, 11, 17, 9);

/// A straight track of [n] fixes one second apart, 10 m/s north.
List<TrackSample> _track(int n) => [
  for (var i = 0; i < n; i++)
    TrackSample(
      t: _t0.add(Duration(seconds: i)),
      lat: 45.28 + i * 0.00009,
      lon: 6.56,
      alt: 2000.0 + i,
      accuracy: 5,
      speed: 10,
    ),
];

void main() {
  late DateTime real;
  late TrackSimulation sim;
  late List<TrackSample> sent;
  late StreamSubscription<TrackSample> sub;

  void advance(Duration d) {
    real = real.add(d);
    sim.poll();
  }

  setUp(() {
    real = _real0;
    sim = TrackSimulation(_track(61), realClock: () => real);
    sent = [];
    sub = sim.fixes.listen(sent.add);
  });
  tearDown(() async {
    await sub.cancel();
    sim.dispose();
  });

  test('the clock follows the real clock while parked', () {
    expect(sim.now(), _real0);
    advance(const Duration(seconds: 3));
    expect(sim.now(), _real0.add(const Duration(seconds: 3)));
  });

  test('parked: the first position once a second, stamped in order', () {
    advance(const Duration(milliseconds: 2500));
    expect(sent, hasLength(2));
    expect(sent.map((p) => p.lat), everyElement(_track(1).first.lat));
    expect(sent.map((p) => p.speed), everyElement(0));
    expect(sent[1].t.difference(sent[0].t), const Duration(seconds: 1));
    expect(sim.phase, SimPhase.parked);
  });

  test('a replay runs the clock at the chosen speed without a jump', () {
    sim.setSpeed(10);
    advance(const Duration(seconds: 1));
    final before = sim.now();
    sim.startReplay('s1');
    expect(sim.now(), before);
    advance(const Duration(seconds: 2));
    expect(sim.now(), before.add(const Duration(seconds: 20)));
  });

  test('replayed fixes keep the track spacing on the virtual clock', () {
    sent.clear();
    sim
      ..setSpeed(5)
      ..startReplay('s1');
    final start = sim.now();
    // Fix 0 at start, then 5 fixes per real second.
    advance(const Duration(seconds: 2));
    expect(sent, hasLength(11));
    for (var i = 0; i < sent.length; i++) {
      expect(sent[i].t, start.add(Duration(seconds: i)));
      expect(sent[i].lat, _track(61)[i].lat);
      expect(sent[i].speed, 10);
    }
    expect(sim.index, 11);
    expect(sim.position, const Duration(seconds: 10));
  });

  test('changing speed mid-replay keeps time monotonic and spacing', () {
    sim.startReplay('s1');
    final start = sim.now();
    advance(const Duration(seconds: 3));
    sim.setSpeed(30);
    advance(const Duration(seconds: 1));
    sim.setSpeed(1);
    advance(const Duration(seconds: 2));
    final times = [for (final p in sent.skipWhile((p) => p.speed == 0)) p.t];
    expect(times.first, start);
    for (var i = 1; i < times.length; i++) {
      expect(times[i].difference(times[i - 1]), const Duration(seconds: 1));
    }
    expect(sim.now(), start.add(const Duration(seconds: 3 + 30 + 2)));
    expect(sim.index, 36);
  });

  test('the end of the track holds the last position at 1x', () {
    sim
      ..setSpeed(30)
      ..startReplay('s1');
    advance(const Duration(seconds: 3));
    expect(sim.phase, SimPhase.holding);
    expect(sim.index, 61);
    final last = sent.last;
    final clock = sim.now();
    advance(const Duration(seconds: 2));
    // 1x again: two more seconds of virtual time, two more fixes.
    expect(sim.now(), clock.add(const Duration(seconds: 2)));
    final held = sent.skipWhile((p) => !identical(p, last)).skip(1).toList();
    expect(held, isNotEmpty);
    expect(held.map((p) => p.lat), everyElement(_track(61).last.lat));
    expect(held.first.t.isAfter(last.t), isTrue);
    expect(sim.speed, 30, reason: 'the chosen speed is kept for next time');
  });

  test('park returns to the start; the same session is not restarted', () {
    sim.startReplay('s1');
    advance(const Duration(seconds: 5));
    sim.startReplay('s1');
    expect(sim.index, 6);
    sim.park();
    expect(sim.phase, SimPhase.parked);
    expect(sim.index, 0);
    expect(sim.sessionId, isNull);
    final clock = sim.now();
    advance(const Duration(seconds: 1));
    expect(sim.now(), clock.add(const Duration(seconds: 1)));
    expect(sent.last.lat, _track(1).first.lat);
  });

  test('timestamps never go backwards across every phase', () {
    advance(const Duration(seconds: 2));
    sim
      ..setSpeed(10)
      ..startReplay('s1');
    advance(const Duration(seconds: 4));
    advance(const Duration(seconds: 4));
    sim.park();
    advance(const Duration(seconds: 3));
    sim.startReplay('s2');
    advance(const Duration(seconds: 1));
    for (var i = 1; i < sent.length; i++) {
      expect(sent[i].t.isBefore(sent[i - 1].t), isFalse, reason: 'fix $i');
    }
  });

  test('the location source grants everything and streams the fixes', () async {
    final source = SimulatedLocationSource(sim);
    expect(await source.checkPermission(), LocationPermissionState.granted);
    expect(await source.requestPermission(), LocationPermissionState.granted);
    expect(await source.serviceEnabled(), isTrue);
    expect((await source.lastKnownPosition())!.lat, _track(1).first.lat);
    await source.openAppSettings();
    await source.openLocationSettings();
    final got = <TrackSample>[];
    final s = source
        .positions(notificationTitle: 't', notificationText: 'x')
        .listen(got.add);
    advance(const Duration(seconds: 1));
    expect(got, hasLength(1));
    await s.cancel();
  });

  test('an empty track is refused and speed must be positive', () {
    expect(() => TrackSimulation(const []), throwsArgumentError);
    expect(() => sim.setSpeed(0), throwsArgumentError);
  });

  test('start runs a periodic timer that polls', () async {
    final live = TrackSimulation(
      _track(3),
      tick: const Duration(milliseconds: 10),
    );
    final got = <TrackSample>[];
    final s = live.fixes.listen(got.add);
    live
      ..start()
      ..startReplay('s1');
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(got, isNotEmpty);
    await s.cancel();
    live.dispose();
  });
}
