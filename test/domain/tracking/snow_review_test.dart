import 'package:fitapp/domain/tracking/geo.dart';
import 'package:fitapp/domain/tracking/snow_reducer.dart';
import 'package:fitapp/domain/tracking/snow_review.dart';
import 'package:fitapp/domain/tracking/snow_state.dart';
import 'package:fitapp/domain/tracking/snow_summary.dart';
import 'package:flutter_test/flutter_test.dart';

import 'snow_fixtures.dart';

SnowDescent run(
  int number, {
  double maxSpeed = 10,
  int meters = 1000,
  int drop = 300,
  int duration = 200,
  int ride = 100,
}) => SnowDescent(
  number: number,
  firstRecord: 0,
  lastRecord: 0,
  routeOffset: 0,
  pointCount: 0,
  startSeconds: number * 1000,
  durationSeconds: duration,
  rideSeconds: ride,
  distanceMeters: meters,
  dropMeters: drop,
  maxSpeedMps: maxSpeed,
);

/// Three runs of clearly different speed, length and drop.
final threeRuns = buildSnowDay(const [
  SnowLeg.stand(60),
  SnowLeg.lift(420),
  SnowLeg.stand(40),
  SnowLeg.run(240, speed: 8), // most vertical
  SnowLeg.stand(120),
  SnowLeg.lift(300),
  SnowLeg.stand(40),
  SnowLeg.run(150, speed: 18, vertical: 2), // fastest
  SnowLeg.stand(120),
  SnowLeg.lift(300),
  SnowLeg.stand(40),
  SnowLeg.run(300, speed: 11, vertical: 1), // longest
  SnowLeg.stand(60),
]);

void main() {
  final summary = summarizeSnow(
    replaySnow(threeRuns.samples),
    threeRuns.samples,
    startedAt: snowStart,
  );
  final records = summary.records;
  final descents = snowDescents(records);
  final route = decodePolyline(summary.route);

  group('snowDayStats', () {
    test('extremes of a fixture day', () {
      final s = snowDayStats(records, descents);
      expect(s.highestAlt, closeTo(1920, 20));
      expect(s.lowestAlt, closeTo(1500, 20));
      expect(
        s.longestRunMeters,
        descents.map((d) => d.distanceMeters).reduce((a, b) => a > b ? a : b),
      );
    });

    test('nothing known', () {
      final s = snowDayStats(const [], const []);
      expect(s.highestAlt, isNull);
      expect(s.lowestAlt, isNull);
      expect(s.longestRunMeters, isNull);
    });
  });

  group('compareRuns and badges', () {
    test('badges land on the expected runs of the fixture', () {
      expect(descents, hasLength(3));
      expect(snowBadges(descents), {
        1: {RunBadge.mostVertical},
        2: {RunBadge.fastest},
        3: {RunBadge.longest},
      });
    });

    test('every metric sorts best first; by time keeps riding order', () {
      final a = run(1, meters: 3000, duration: 100);
      final b = run(2, maxSpeed: 20, drop: 500, duration: 300);
      final c = run(3, maxSpeed: 15, meters: 2000, drop: 400);
      final all = [c, a, b];
      List<int> order(RunMetric m) => [
        for (final d in compareRuns(all, m)) d.number,
      ];
      expect(order(RunMetric.maxSpeed), [2, 3, 1]);
      expect(order(RunMetric.distance), [1, 3, 2]);
      expect(order(RunMetric.vertical), [2, 3, 1]);
      expect(order(RunMetric.duration), [2, 3, 1]);
      expect(order(RunMetric.avgSpeed), [1, 3, 2]);
      expect(
        [
          for (final d in compareRuns(all, RunMetric.maxSpeed, byMetric: false))
            d.number,
        ],
        [1, 2, 3],
      );
    });

    test('ties go to the earlier run; one run earns no badge', () {
      final same = [run(2), run(1)];
      expect(snowBadges(same), {
        1: {RunBadge.fastest, RunBadge.longest, RunBadge.mostVertical},
      });
      expect(snowBadges([run(1)]), isEmpty);
      expect(snowBadges(const []), isEmpty);
    });
  });

  group('heatmap', () {
    test('route parts tile the route', () {
      final parts = snowRouteParts(records);
      expect(parts, hasLength(records.length));
      var offset = 0;
      for (final (i, p) in parts.indexed) {
        expect(p.offset, offset);
        expect(p.kind, records[i].kind);
        expect(p.speedsKmh, records[i].speedsKmh);
        offset += p.count;
      }
      expect(offset, route.length);
    });

    test('scale tops out at the day maximum rounded up to 5', () {
      final max = heatmapMaxKmh(records);
      expect(max % 5, 0);
      final top = records
          .expand((r) => r.speedsKmh)
          .reduce((a, b) => a > b ? a : b);
      expect(max, greaterThanOrEqualTo(top));
      expect(max - top, lessThan(5));
      expect(heatmapMaxKmh(const []), 5);
    });

    test('stops and buckets', () {
      expect(speedColorStops(50), [10, 20, 30, 40, 50]);
      expect(speedColorStops(60, buckets: 3), [20, 40, 60]);
      expect(speedBucket(0, 50), 0);
      expect(speedBucket(9, 50), 0);
      expect(speedBucket(10, 50), 1);
      expect(speedBucket(49, 50), 4);
      expect(speedBucket(50, 50), 4);
      expect(speedBucket(80, 50), 4);
      expect(speedBucket(10, 0), 0);
      expect(speedBucket(-3, 50), 0);
    });
  });

  group('replay', () {
    test('track covers the run with rising time', () {
      final track = replayTrack(records, route, descents[1]);
      expect(track.length, greaterThan(2));
      expect(track.first.seconds, 0);
      expect(replayDuration(track), closeTo(150, 8));
      for (var i = 1; i < track.length; i++) {
        expect(track[i].seconds, greaterThanOrEqualTo(track[i - 1].seconds));
      }
      expect(track.first.altitude! - track.last.altitude!, closeTo(300, 25));
    });

    test('a stop inside a descent is bridged in time', () {
      final f = buildSnowDay(const [
        SnowLeg.stand(60),
        SnowLeg.lift(420),
        SnowLeg.stand(40),
        SnowLeg.run(120),
        SnowLeg.stand(60),
        SnowLeg.run(120),
        SnowLeg.stand(60),
      ]);
      final s = summarizeSnow(
        replaySnow(f.samples),
        f.samples,
        startedAt: snowStart,
      );
      final d = snowDescents(s.records).single;
      final track = replayTrack(s.records, decodePolyline(s.route), d);
      expect(replayDuration(track), closeTo(300, 10));
    });

    test('frame is interpolated between the two points around it', () {
      const track = [
        ReplayPoint(
          point: (lat: 46, lon: 7),
          seconds: 0,
          speedKmh: 10,
          altitude: 2000,
        ),
        ReplayPoint(
          point: (lat: 46.001, lon: 7.002),
          seconds: 10,
          speedKmh: 30,
          altitude: 1980,
        ),
        ReplayPoint(
          point: (lat: 46.002, lon: 7.002),
          seconds: 20,
          speedKmh: 50,
          altitude: 1950,
        ),
      ];
      final f = replayAt(track, 5)!;
      expect(f.point.lat, closeTo(46.0005, 1e-9));
      expect(f.point.lon, closeTo(7.001, 1e-9));
      expect(f.speedKmh, 20);
      expect(f.altitude, 1990);
      expect(f.index, 0);
      expect(f.seconds, 5);
      final g = replayAt(track, 15)!;
      expect(g.index, 1);
      expect(g.speedKmh, 40);
      expect(g.altitude, 1965);
      // Clamped at both ends.
      expect(replayAt(track, -3)!.index, 0);
      expect(replayAt(track, -3)!.speedKmh, 10);
      expect(replayAt(track, 99)!.index, 2);
      expect(replayAt(track, 99)!.altitude, 1950);
    });

    test('unknown altitude and repeated times', () {
      const track = [
        ReplayPoint(point: (lat: 46, lon: 7), seconds: 0, speedKmh: 10),
        ReplayPoint(point: (lat: 46, lon: 7), seconds: 4, speedKmh: 10),
        ReplayPoint(point: (lat: 46.001, lon: 7), seconds: 4, speedKmh: 20),
        ReplayPoint(point: (lat: 46.002, lon: 7), seconds: 8, speedKmh: 20),
      ];
      expect(replayAt(track, 2)!.altitude, isNull);
      expect(replayAt(track, 4)!.point.lat, closeTo(46.001, 1e-9));
      expect(replayAt(const [], 1), isNull);
      expect(replayDuration(const []), 0);
    });

    test('data that does not fit the route gives an empty track', () {
      expect(replayTrack(records, route.sublist(0, 5), descents[0]), isEmpty);
      final broken = [
        for (final r in records)
          SnowRecord(
            kind: r.kind,
            startSeconds: r.startSeconds,
            durationSeconds: r.durationSeconds,
            distanceMeters: r.distanceMeters,
            verticalMeters: r.verticalMeters,
            pointCount: r.pointCount,
          ),
      ];
      expect(replayTrack(broken, route, descents[0]), isEmpty);
    });
  });

  test('runMetricValue', () {
    final d = run(1, maxSpeed: 12, meters: 900, drop: 250, duration: 90);
    expect(runMetricValue(d, RunMetric.maxSpeed), 12);
    expect(runMetricValue(d, RunMetric.avgSpeed), 9);
    expect(runMetricValue(d, RunMetric.vertical), 250);
    expect(runMetricValue(d, RunMetric.distance), 900);
    expect(runMetricValue(d, RunMetric.duration), 90);
    expect(SnowKind.values, hasLength(3));
  });
}
