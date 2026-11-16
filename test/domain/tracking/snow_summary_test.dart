import 'package:fitapp/domain/tracking/geo.dart';
import 'package:fitapp/domain/tracking/snow_reducer.dart';
import 'package:fitapp/domain/tracking/snow_state.dart';
import 'package:fitapp/domain/tracking/snow_summary.dart';
import 'package:fitapp/domain/tracking/track_sample.dart';
import 'package:flutter_test/flutter_test.dart';

import 'snow_fixtures.dart';

SnowSummary summaryOf(SnowFixture f) {
  final fed = [
    for (final p in f.samples)
      if (!p.paused) p,
  ];
  return summarizeSnow(replaySnow(f.samples), fed, startedAt: snowStart);
}

SnowRecord rec(
  SnowKind kind,
  int start,
  int duration, {
  int meters = 0,
  int vertical = 0,
  double maxSpeed = 0,
  int points = 2,
  int? a,
  int? b,
}) => SnowRecord(
  kind: kind,
  startSeconds: start,
  durationSeconds: duration,
  distanceMeters: meters,
  verticalMeters: vertical,
  maxSpeedMps: maxSpeed,
  pointCount: points,
  startAlt: a,
  endAlt: b,
);

void main() {
  group('summarizeSnow', () {
    final f = buildSnowDay(plainDay);
    final s = summaryOf(f);

    test('totals match the reference', () {
      expect(s.runCount, 3);
      expect(s.dropMeters, closeTo(f.dropMeters, f.dropMeters * 0.05));
      expect(s.rideSeconds, closeTo(f.rideSeconds, f.rideSeconds * 0.05));
      expect(s.liftSeconds, closeTo(f.liftSeconds, f.liftSeconds * 0.05));
      expect(s.restSeconds, closeTo(f.restSeconds, f.restSeconds * 0.05));
      expect(s.rideMeters, closeTo(f.rideMeters, f.rideMeters * 0.05));
      expect(s.maxSpeedMps, closeTo(f.maxSpeedMps, f.maxSpeedMps * 0.05));
      expect(s.avgSpeedMps, closeTo(f.rideMeters / f.rideSeconds, 0.6));
    });

    test('the open segment is closed and the records tile the day', () {
      expect(s.records.last.endSeconds, closeTo(f.samples.length - 1, 1));
      for (var i = 1; i < s.records.length; i++) {
        expect(
          s.records[i].startSeconds,
          closeTo(s.records[i - 1].endSeconds, 1),
        );
      }
      expect(s.records.first.startSeconds, 0);
    });

    test('route is the segments simplified one after another', () {
      final route = decodePolyline(s.route);
      expect(route.length, s.records.fold<int>(0, (a, r) => a + r.pointCount));
      // Each slice starts where the previous one ended.
      var offset = 0;
      for (var i = 0; i < s.records.length; i++) {
        final n = s.records[i].pointCount;
        expect(n, greaterThanOrEqualTo(2));
        if (i > 0) {
          expect(route[offset].lat, closeTo(route[offset - 1].lat, 1e-5));
          expect(route[offset].lon, closeTo(route[offset - 1].lon, 1e-5));
        }
        offset += n;
      }
    });

    test('runs carry speed and time per route point; others do not', () {
      for (final r in s.records) {
        if (r.kind == SnowKind.run) {
          expect(r.speedsKmh, hasLength(r.pointCount));
          expect(r.seconds, hasLength(r.pointCount));
          expect(r.altitudes, hasLength(r.pointCount));
          expect(r.altitudes.first, closeTo(r.startAlt!, 15));
          expect(r.altitudes.last, closeTo(r.endAlt!, 15));
          expect(r.seconds.first, 0);
          expect(r.seconds.last, closeTo(r.durationSeconds, 1));
          for (var i = 1; i < r.seconds.length; i++) {
            expect(r.seconds[i], greaterThanOrEqualTo(r.seconds[i - 1]));
          }
          expect(
            r.speedsKmh.reduce((a, b) => a > b ? a : b),
            closeTo(r.maxSpeedMps * 3.6, 6),
          );
        } else {
          expect(r.speedsKmh, isEmpty);
          expect(r.seconds, isEmpty);
          expect(r.altitudes, isEmpty);
          expect(r.maxSpeedMps, 0);
        }
      }
    });

    test('altitudes: lifts go up, runs come down', () {
      for (final r in s.records) {
        if (r.kind == SnowKind.lift) {
          expect(r.endAlt! - r.startAlt!, closeTo(420, 25));
        } else if (r.kind == SnowKind.run) {
          expect(r.startAlt! - r.endAlt!, closeTo(420, 25));
        }
      }
    });

    test('speed per point is derived when the device gives none', () {
      final g = buildSnowDay(plainDay, doppler: false);
      final run = summaryOf(g).records
          .firstWhere((r) => r.kind == SnowKind.run);
      expect(run.speedsKmh.reduce((a, b) => a > b ? a : b), greaterThan(30));
    });

    test('without altitude the runs carry no altitudes', () {
      final g = buildSnowDay(plainDay, altitude: false);
      final runs = summaryOf(g).records.where((r) => r.kind == SnowKind.run);
      expect(runs, isNotEmpty);
      for (final r in runs) {
        expect(r.altitudes, isEmpty);
        expect(r.speedsKmh, hasLength(r.pointCount));
      }
    });

    test('a single fix summarises to nothing', () {
      final one = [
        TrackSample(t: snowStart, lat: 46, lon: 7, accuracy: 5, alt: 1500),
      ];
      final t = summarizeSnow(replaySnow(one), one, startedAt: snowStart);
      expect(t.records, isEmpty);
      expect(t.route, isEmpty);
      expect(t.runCount, 0);
      expect(t.avgSpeedMps, isNull);
    });

    test('rejects a fix list of the wrong length', () {
      expect(
        () => summarizeSnow(
          replaySnow(f.samples),
          f.samples.sublist(1),
          startedAt: snowStart,
        ),
        throwsArgumentError,
      );
    });

    test('paused fixes are left out', () {
      final g = buildSnowDay(const [
        SnowLeg.stand(60),
        ...snowCycle,
        SnowLeg.pause(600),
        ...snowCycle,
      ]);
      final t = summaryOf(g);
      expect(t.runCount, 2);
      final total = t.records.fold<int>(0, (a, r) => a + r.durationSeconds);
      expect(total, closeTo(60 + 820 + 820, 5));
    });

    test('an 8-hour day stays small (SC-004)', () {
      final day = buildSnowDay(longDay(8));
      final watch = Stopwatch()..start();
      final t = summaryOf(day);
      expect(watch.elapsed, lessThan(const Duration(seconds: 5)));
      expect(t.runCount, 8 * 3600 ~/ 820);
      expect(t.route.length, lessThan(400 * 1024));
      expect(encodeSnowRecords(t.records).length, lessThan(100 * 1024));
    });
  });

  group('records JSON', () {
    test('round trip', () {
      final s = summaryOf(buildSnowDay(plainDay));
      final back = decodeSnowRecords(encodeSnowRecords(s.records));
      expect(back, hasLength(s.records.length));
      for (var i = 0; i < back.length; i++) {
        final a = s.records[i];
        final b = back[i];
        expect(b.kind, a.kind);
        expect(b.startSeconds, a.startSeconds);
        expect(b.durationSeconds, a.durationSeconds);
        expect(b.distanceMeters, a.distanceMeters);
        expect(b.verticalMeters, a.verticalMeters);
        expect(b.maxSpeedMps, closeTo(a.maxSpeedMps, 0.05));
        expect(b.pointCount, a.pointCount);
        expect(b.startAlt, a.startAlt);
        expect(b.endAlt, a.endAlt);
        expect(b.speedsKmh, a.speedsKmh);
        expect(b.seconds, a.seconds);
        expect(b.altitudes, a.altitudes);
      }
    });

    test('unknown altitude is left out and read back as null', () {
      final text = encodeSnowRecords([rec(SnowKind.rest, 0, 10)]);
      expect(text, isNot(contains('"a"')));
      expect(decodeSnowRecords(text).single.startAlt, isNull);
    });

    test('null, empty and unreadable text give an empty list', () {
      expect(decodeSnowRecords(null), isEmpty);
      expect(decodeSnowRecords(''), isEmpty);
      expect(decodeSnowRecords('not json'), isEmpty);
      expect(
        decodeSnowRecords('[{"k":"x","t":0,"d":1,"m":0,"v":0,"n":1}]'),
        isEmpty,
      );
      expect(decodeSnowRecords('{"k":"r"}'), isEmpty);
    });
  });

  group('snowDescents', () {
    test('groups runs and stops between lifts; skips small drops', () {
      final records = [
        rec(SnowKind.rest, 0, 60),
        rec(SnowKind.lift, 60, 400, vertical: 400, a: 1500, b: 1900),
        rec(SnowKind.rest, 460, 40),
        rec(
          SnowKind.run,
          500,
          100,
          meters: 1000,
          vertical: 200,
          maxSpeed: 15,
          points: 10,
          a: 1900,
          b: 1700,
        ),
        rec(SnowKind.rest, 600, 50),
        rec(
          SnowKind.run,
          650,
          110,
          meters: 1200,
          vertical: 200,
          maxSpeed: 18,
          points: 12,
          a: 1700,
          b: 1500,
        ),
        rec(SnowKind.rest, 760, 100),
        rec(SnowKind.lift, 860, 400, vertical: 400),
        rec(SnowKind.run, 1260, 30, meters: 150, vertical: 12),
        rec(SnowKind.lift, 1290, 400, vertical: 400),
        rec(SnowKind.rest, 1690, 20),
        rec(
          SnowKind.run,
          1710,
          200,
          meters: 2000,
          vertical: 400,
          maxSpeed: 20,
          points: 20,
        ),
      ];
      final d = snowDescents(records);
      expect(d, hasLength(2));
      final first = d[0];
      expect(first.number, 1);
      expect(first.firstRecord, 3);
      expect(first.lastRecord, 5);
      expect(first.routeOffset, 6);
      expect(first.pointCount, 24);
      expect(first.startSeconds, 500);
      expect(first.durationSeconds, 260);
      expect(first.rideSeconds, 210);
      expect(first.distanceMeters, 2200);
      expect(first.dropMeters, 400);
      expect(first.maxSpeedMps, 18);
      expect(first.topAlt, 1900);
      expect(first.bottomAlt, 1500);
      expect(first.avgSpeedMps, closeTo(2200 / 210, 1e-9));
      expect(d[1].number, 2);
      expect(d[1].firstRecord, 11);
      expect(d[1].dropMeters, 400);
    });

    test('no records, no descents; zero ride time has zero average', () {
      expect(snowDescents(const []), isEmpty);
      final d = snowDescents([rec(SnowKind.run, 0, 0, vertical: 50)]).single;
      expect(d.avgSpeedMps, 0);
    });

    test('agrees with the live run count on the fixtures', () {
      for (final legs in [plainDay, longDay(2)]) {
        final f = buildSnowDay(legs);
        expect(summaryOf(f).runCount, snowRunCount(replaySnow(f.samples)));
      }
    });
  });

  test('simplifyIndices keeps the ends and matches simplify', () {
    final pts = [
      (lat: 0.0, lon: 0.0),
      (lat: 0.0, lon: 0.0001),
      (lat: 0.001, lon: 0.0002),
      (lat: 0.0, lon: 0.0003),
    ];
    final idx = simplifyIndices(pts, 5);
    expect(idx.first, 0);
    expect(idx.last, 3);
    expect([for (final i in idx) pts[i]], simplify(pts, 5));
    expect(simplifyIndices(pts.sublist(0, 2), 5), [0, 1]);
    expect(simplifyIndices(const [], 5), isEmpty);
  });
}
