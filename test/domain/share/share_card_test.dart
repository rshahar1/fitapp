import 'package:fitapp/domain/share/share_card.dart';
import 'package:fitapp/domain/tracking/geo.dart';
import 'package:fitapp/domain/tracking/snow_state.dart';
import 'package:fitapp/domain/tracking/snow_summary.dart';
import 'package:flutter_test/flutter_test.dart';

final _day = DateTime.utc(2026, 11, 20, 8);

String _route() => encodePolyline([
  (lat: 45.3, lon: 6.58),
  (lat: 45.31, lon: 6.59),
  (lat: 45.32, lon: 6.585),
]);

Map<String, String> _stats(ShareCardData c) => {
  for (final s in c.stats) s.label: '${s.value}${s.unit ?? ''}',
};

ShareExercise _ex(
  String name,
  List<(double, int)> sets, {
  bool perHand = false,
}) => ShareExercise(name: name, perHand: perHand, sets: sets);

void main() {
  group('running and cycling with a route', () {
    test('GPS run: route layout with pace and best km', () {
      final c = activityShareCard(
        ActivityShareInput(
          typeId: 'running',
          startedAt: _day,
          source: 'gps',
          durationMinutes: 27,
          distanceMeters: 5200,
          movingSeconds: 1600,
          elevationGainMeters: 42,
          route: _route(),
          splits: '[310, 298, 305, 320, 301]',
        ),
      );
      expect(c.layout, ShareLayout.route);
      expect(c.title, 'Running');
      expect(c.typeId, 'running');
      expect(c.route, hasLength(3));
      expect(c.stats.map((s) => s.label), [
        'Distance',
        'Avg pace',
        'Duration',
        'Moving time',
        'Climb',
        'Best km',
      ]);
      expect(_stats(c), {
        'Distance': '5.2km',
        'Avg pace': '5:12/km',
        'Duration': '27 min',
        'Moving time': '26:40',
        'Climb': '42m',
        'Best km': '4:58/km',
      });
    });

    test('GPS ride: average speed, no best km', () {
      final c = activityShareCard(
        ActivityShareInput(
          typeId: 'cycling',
          startedAt: _day,
          source: 'gps',
          durationMinutes: 90,
          distanceMeters: 36750,
          route: _route(),
          splits: '[120, 118]',
        ),
      );
      expect(c.layout, ShareLayout.route);
      expect(_stats(c), {
        'Distance': '36.75km',
        'Avg speed': '24.5km/h',
        'Duration': '1 h 30 min',
      });
    });

    test('zero and missing values are omitted', () {
      final c = activityShareCard(
        ActivityShareInput(
          typeId: 'running',
          startedAt: _day,
          source: 'gps',
          durationMinutes: 10,
          distanceMeters: 0,
          movingSeconds: 0,
          elevationGainMeters: 0,
          route: _route(),
          splits: '[]',
        ),
      );
      expect(_stats(c), {'Duration': '10 min'});
    });

    test('broken route or splits never throw', () {
      final c = activityShareCard(
        ActivityShareInput(
          typeId: 'running',
          startedAt: _day,
          source: 'gps',
          durationMinutes: 10,
          distanceMeters: 2000,
          route: '}}}',
          splits: 'not json',
        ),
      );
      expect(c.layout, ShareLayout.basic);
      expect(c.route, isNull);
      expect(c.stats.map((s) => s.label), ['Distance', 'Avg pace', 'Duration']);
    });

    test('a one-point route is not drawn', () {
      final c = activityShareCard(
        ActivityShareInput(
          typeId: 'cycling',
          startedAt: _day,
          source: 'gps',
          route: encodePolyline([(lat: 1, lon: 1)]),
        ),
      );
      expect(c.layout, ShareLayout.basic);
    });
  });

  group('snowboarding', () {
    final records = [
      const SnowRecord(
        kind: SnowKind.lift,
        startSeconds: 0,
        durationSeconds: 600,
        distanceMeters: 1500,
        verticalMeters: 400,
        pointCount: 2,
      ),
      const SnowRecord(
        kind: SnowKind.run,
        startSeconds: 600,
        durationSeconds: 300,
        distanceMeters: 2100,
        verticalMeters: 410,
        maxSpeedMps: 17.4,
        pointCount: 1,
        speedsKmh: [40],
        seconds: [0],
      ),
    ];

    test('GPS day: snow layout with breakdown and day stats', () {
      final c = activityShareCard(
        ActivityShareInput(
          typeId: 'snowboarding',
          startedAt: _day,
          source: 'gps',
          durationMinutes: 320,
          distanceMeters: 18400,
          movingSeconds: 7200,
          liftSeconds: 6000,
          restSeconds: 6000,
          maxSpeedMps: 17.4,
          verticalDropMeters: 3240,
          runCount: 12,
          route: _route(),
          segments: encodeSnowRecords(records),
        ),
      );
      expect(c.layout, ShareLayout.snow);
      expect(c.segments, isNotNull);
      expect(c.breakdown!.rideSeconds, 7200);
      expect(c.breakdown!.liftSeconds, 6000);
      expect(c.breakdown!.restSeconds, 6000);
      expect(c.breakdown!.totalSeconds, 19200);
      expect(_stats(c), {
        'Top speed': '62.6km/h',
        'Vertical': '3,240m',
        'Runs': '12',
        'Distance': '18.4km',
        'Total time': '5 h 20 min',
        'Longest run': '2.1km',
      });
    });

    test('breakdown is dropped when nothing was timed', () {
      final c = activityShareCard(
        ActivityShareInput(
          typeId: 'snowboarding',
          startedAt: _day,
          source: 'gps',
          durationMinutes: 5,
          route: _route(),
          segments: encodeSnowRecords(records),
        ),
      );
      expect(c.layout, ShareLayout.snow);
      expect(c.breakdown, isNull);
    });

    test('manual day: basic layout', () {
      final c = activityShareCard(
        ActivityShareInput(
          typeId: 'snowboarding',
          startedAt: _day,
          durationMinutes: 240,
          distanceMeters: 25000,
        ),
      );
      expect(c.layout, ShareLayout.basic);
      expect(_stats(c), {'Distance': '25km', 'Duration': '4 h'});
    });
  });

  group('other activities', () {
    test('pilates: duration only', () {
      final c = activityShareCard(
        ActivityShareInput(
          typeId: 'pilates',
          startedAt: _day,
          durationMinutes: 45,
        ),
      );
      expect(c.layout, ShareLayout.basic);
      expect(c.title, 'Pilates');
      expect(_stats(c), {'Duration': '45 min'});
    });

    test('manual run: distance, duration and pace without a route', () {
      final c = activityShareCard(
        ActivityShareInput(
          typeId: 'running',
          startedAt: _day,
          durationMinutes: 50,
          distanceMeters: 10000,
        ),
      );
      expect(c.layout, ShareLayout.basic);
      expect(c.route, isNull);
      expect(_stats(c), {
        'Distance': '10km',
        'Avg pace': '5:00/km',
        'Duration': '50 min',
      });
    });

    test('empty entry has no stats', () {
      final c = activityShareCard(
        ActivityShareInput(typeId: 'functional', startedAt: _day),
      );
      expect(c.stats, isEmpty);
      expect(c.title, 'Functional training');
    });

    test('unknown type shares as Activity', () {
      final c = activityShareCard(
        ActivityShareInput(typeId: 'kitesurf', startedAt: _day),
      );
      expect(c.title, 'Activity');
    });
  });

  group('exercise lines', () {
    test('uniform sets', () {
      expect(
        exerciseShareLine(_ex('Bench press', [(60, 8), (60, 8), (60, 8)]))
            .detail,
        '3 × 8 · 60 kg',
      );
    });

    test('mixed sets show the top set', () {
      expect(
        exerciseShareLine(_ex('Squat', [(80, 5), (85, 5), (85, 4)])).detail,
        '3 sets · top 85 kg × 5',
      );
    });

    test('bodyweight sets show reps only', () {
      expect(
        exerciseShareLine(_ex('Pull-up', [(0, 12), (0, 12), (0, 12)])).detail,
        '3 × 12',
      );
      expect(
        exerciseShareLine(_ex('Dip', [(0, 10), (0, 15)])).detail,
        '2 sets · best 15 reps',
      );
    });

    test('per-hand weights read "each"', () {
      expect(
        exerciseShareLine(_ex('Curl', [(20, 10), (20, 10)], perHand: true))
            .detail,
        '2 × 10 · 20 kg each',
      );
      expect(
        exerciseShareLine(_ex('Row', [(22.5, 8), (25, 6)], perHand: true))
            .detail,
        '2 sets · top 25 kg × 6 each',
      );
    });

    test('decimal weights', () {
      expect(
        exerciseShareLine(_ex('OHP', [(42.5, 5)])).detail,
        '1 × 5 · 42.5 kg',
      );
    });
  });

  group('gym workout', () {
    test('totals and lines', () {
      final c = workoutShareCard(
        WorkoutShareInput(
          startedAt: _day,
          endedAt: _day.add(const Duration(minutes: 62)),
          exercises: [
            _ex('Bench press', [(60, 8), (60, 8), (60, 8)]),
            _ex('Curl', [(10, 10)], perHand: true),
            _ex('Skipped', const []),
          ],
        ),
      );
      expect(c.layout, ShareLayout.strength);
      expect(c.title, 'Workout');
      expect(c.typeId, 'gym');
      expect(c.exercises.map((e) => e.name), ['Bench press', 'Curl']);
      expect(c.hiddenExercises, 0);
      expect(_stats(c), {
        'Duration': '1 h 2 min',
        'Sets': '4',
        'Reps': '34',
        'Volume': '1,640kg',
      });
    });

    test('named workout uses its name', () {
      final c = workoutShareCard(
        WorkoutShareInput(
          name: 'Push day',
          startedAt: _day,
          endedAt: _day,
          exercises: [
            _ex('Push-up', [(0, 20)]),
          ],
        ),
      );
      expect(c.title, 'Push day');
      // Under a minute and no volume: omitted.
      expect(_stats(c), {'Sets': '1', 'Reps': '20'});
    });

    test('seven exercises all fit', () {
      final c = workoutShareCard(
        WorkoutShareInput(
          startedAt: _day,
          exercises: [
            for (var i = 0; i < 7; i++) _ex('E$i', [(10, 5)]),
          ],
        ),
      );
      expect(c.exercises, hasLength(7));
      expect(c.hiddenExercises, 0);
    });

    test('long lists keep six and count the rest', () {
      final c = workoutShareCard(
        WorkoutShareInput(
          startedAt: _day,
          exercises: [
            for (var i = 0; i < 11; i++) _ex('E$i', [(10, 5)]),
          ],
        ),
      );
      expect(c.exercises, hasLength(6));
      expect(c.hiddenExercises, 5);
    });
  });

  group('file name and caption', () {
    test('file name uses type and local date', () {
      expect(
        shareFileName('running', DateTime(2026, 3, 7, 23)),
        'fitapp-running-2026-03-07.png',
      );
    });

    test('caption lists title and first two stats', () {
      final c = activityShareCard(
        ActivityShareInput(
          typeId: 'running',
          startedAt: _day,
          durationMinutes: 50,
          distanceMeters: 10000,
        ),
      );
      expect(shareCaption(c), 'Running · 10 km · 5:00 /km');
      final empty = activityShareCard(
        ActivityShareInput(typeId: 'pilates', startedAt: _day),
      );
      expect(shareCaption(empty), 'Pilates');
    });
  });
}
