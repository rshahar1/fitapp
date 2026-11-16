import 'package:fitapp/domain/activity_types.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formatGrouped', () {
    expect(formatGrouped(0), '0');
    expect(formatGrouped(950), '950');
    expect(formatGrouped(3240), '3,240');
    expect(formatGrouped(1234567), '1,234,567');
    expect(formatGrouped(-1500), '-1,500');
  });

  test('initial types in order with stable ids', () {
    expect(activityTypes.map((t) => t.id), [
      'functional',
      'cycling',
      'snowboarding',
      'running',
      'pilates',
    ]);
    expect(activityTypes.map((t) => t.label), [
      'Functional training',
      'Cycling',
      'Snowboarding',
      'Running',
      'Pilates',
    ]);
  });

  test('ids are unique', () {
    expect(activityTypes.map((t) => t.id).toSet(), hasLength(5));
  });

  test('hasLiveTracking only for running, cycling and snowboarding', () {
    expect(activityTypes.where((t) => t.hasLiveTracking).map((t) => t.id), [
      'cycling',
      'snowboarding',
      'running',
    ]);
  });

  test('lookup by id; unknown -> null', () {
    expect(activityTypeById('cycling')!.label, 'Cycling');
    expect(activityTypeById('curling'), isNull);
  });

  test('label falls back for unknown ids', () {
    expect(activityLabel('running'), 'Running');
    expect(activityLabel('retired-sport'), 'Activity');
  });

  group('validateActivity', () {
    final today = DateTime(2026, 11, 13, 9);

    test('accepts a minimal activity and cleans the note', () {
      final v = validateActivity(
        typeId: 'running',
        startedAt: today,
        now: today,
        notes: '  easy 5k  ',
      );
      expect(v.notes, 'easy 5k');
      expect(v.durationMinutes, isNull);
      expect(
        validateActivity(
          typeId: 'running',
          startedAt: today,
          now: today,
          notes: '   ',
        ).notes,
        isNull,
      );
    });

    test('later today is fine, tomorrow is not', () {
      expect(
        () => validateActivity(
          typeId: 'running',
          startedAt: DateTime(2026, 11, 13, 23, 59),
          now: today,
        ),
        returnsNormally,
      );
      expect(
        () => validateActivity(
          typeId: 'running',
          startedAt: DateTime(2026, 11, 14),
          now: today,
        ),
        throwsArgumentError,
      );
    });

    test('unknown type rejected unless allowed', () {
      expect(
        () => validateActivity(typeId: 'x', startedAt: today, now: today),
        throwsArgumentError,
      );
      expect(
        validateActivity(
          typeId: 'x',
          startedAt: today,
          now: today,
          allowUnknownType: true,
        ).typeId,
        'x',
      );
    });

    test('duration 1..1440', () {
      for (final bad in [0, -5, 1441]) {
        expect(
          () => validateActivity(
            typeId: 'cycling',
            startedAt: today,
            now: today,
            durationMinutes: bad,
          ),
          throwsArgumentError,
        );
      }
      expect(
        validateActivity(
          typeId: 'cycling',
          startedAt: today,
          now: today,
          durationMinutes: 1440,
        ).durationMinutes,
        1440,
      );
    });

    test('note max 200 characters', () {
      expect(
        () => validateActivity(
          typeId: 'cycling',
          startedAt: today,
          now: today,
          notes: 'x' * 201,
        ),
        throwsArgumentError,
      );
    });
  });

  test('hasDistance only for running, cycling and snowboarding', () {
    expect(activityTypes.where((t) => t.hasDistance).map((t) => t.id), [
      'cycling',
      'snowboarding',
      'running',
    ]);
  });

  group('distance validation', () {
    final today = DateTime(2026, 11, 13, 9);
    ValidActivity v(String type, int? m, {bool unknown = false}) =>
        validateActivity(
          typeId: type,
          startedAt: today,
          now: today,
          distanceMeters: m,
          allowUnknownType: unknown,
        );

    test('1..1,000,000 for distance types', () {
      expect(v('running', 1).distanceMeters, 1);
      expect(v('cycling', 1000000).distanceMeters, 1000000);
      expect(v('running', null).distanceMeters, isNull);
      for (final bad in [0, -1, 1000001]) {
        expect(() => v('running', bad), throwsArgumentError);
      }
    });

    test('rejected on known types without distance', () {
      expect(() => v('functional', 5000), throwsArgumentError);
      expect(() => v('pilates', 5000), throwsArgumentError);
    });

    test('accepted on snowboarding', () {
      expect(v('snowboarding', 5000).distanceMeters, 5000);
      expect(v('snowboarding', null).distanceMeters, isNull);
    });

    test('unknown types may keep a distance', () {
      expect(v('retired', 5000, unknown: true).distanceMeters, 5000);
    });
  });

  test('parseDistanceKm', () {
    expect(parseDistanceKm('5.2'), 5200);
    expect(parseDistanceKm(' 5,2 '), 5200);
    expect(parseDistanceKm('10'), 10000);
    expect(parseDistanceKm('5.234'), 5230);
    expect(parseDistanceKm('0.005'), 10);
    expect(parseDistanceKm('0.004'), isNull);
    expect(parseDistanceKm('0'), isNull);
    expect(parseDistanceKm(''), isNull);
    expect(parseDistanceKm('abc'), isNull);
    expect(parseDistanceKm('-3'), isNull);
    expect(parseDistanceKm('1000'), 1000000);
    expect(parseDistanceKm('1000.01'), isNull);
  });

  test('formatDistanceKm', () {
    expect(formatDistanceKm(5200), '5.2 km');
    expect(formatDistanceKm(36750), '36.75 km');
    expect(formatDistanceKm(10000), '10 km');
    expect(formatDistanceKm(10), '0.01 km');
  });

  test('formatPace and formatSpeed', () {
    expect(formatPace(5200, 28), '5:23 /km');
    expect(formatPace(10000, 50), '5:00 /km');
    expect(formatSpeed(36750, 90), '24.5 km/h');
  });

  test('snowboarding has distance and live tracking', () {
    final t = activityTypeById('snowboarding')!;
    expect(t.hasDistance, isTrue);
    expect(t.hasLiveTracking, isTrue);
  });

  test('formatSpeedKmh', () {
    expect(formatSpeedKmh(17.4), '62.6 km/h');
    expect(formatSpeedKmh(0), '0.0 km/h');
  });

  test('formatMetersGrouped', () {
    expect(formatMetersGrouped(950), '950 m');
    expect(formatMetersGrouped(3240), '3,240 m');
    expect(formatMetersGrouped(12000), '12,000 m');
    expect(formatMetersGrouped(1234567), '1,234,567 m');
  });
}
