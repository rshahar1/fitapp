import 'package:fitapp/domain/activity_types.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('initial types in order with stable ids', () {
    expect(activityTypes.map((t) => t.id), [
      'functional',
      'cycling',
      'snowboarding',
      'running',
    ]);
    expect(activityTypes.map((t) => t.label), [
      'Functional training',
      'Cycling',
      'Snowboarding',
      'Running',
    ]);
  });

  test('ids are unique', () {
    expect(activityTypes.map((t) => t.id).toSet(), hasLength(4));
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
}
