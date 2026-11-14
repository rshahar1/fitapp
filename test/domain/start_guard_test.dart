import 'package:fitapp/domain/start_guard.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('sessionInProgress', () {
    test('null when nothing is in progress', () {
      expect(sessionInProgress(hasActiveWorkout: false), isNull);
    });

    test('gym workout', () {
      final s = sessionInProgress(hasActiveWorkout: true)!;
      expect(s.kind, SessionKind.gym);
      expect(s.typeId, isNull);
      expect(s, const SessionInProgress.gym());
    });

    test('tracking session', () {
      final s = sessionInProgress(
        hasActiveWorkout: false,
        trackingTypeId: 'running',
      )!;
      expect(s.kind, SessionKind.tracking);
      expect(s.typeId, 'running');
      expect(s, const SessionInProgress.tracking('running'));
    });

    test('tracking wins when both exist', () {
      expect(
        sessionInProgress(hasActiveWorkout: true, trackingTypeId: 'cycling'),
        const SessionInProgress.tracking('cycling'),
      );
    });
  });

  group('canStart', () {
    test('allowed only when nothing is in progress', () {
      expect(canStart(null), isTrue);
      expect(canStart(const SessionInProgress.gym()), isFalse);
      expect(canStart(const SessionInProgress.tracking('running')), isFalse);
    });
  });

  group('labels', () {
    test('gym', () {
      const s = SessionInProgress.gym();
      expect(s.label, 'Workout');
      expect(s.continueLabel, 'Continue workout');
      expect(s.blockedMessage, 'Workout in progress. Finish it first.');
    });

    test('tracking uses the sport name', () {
      const s = SessionInProgress.tracking('running');
      expect(s.label, 'Running');
      expect(s.continueLabel, 'Continue running');
      expect(s.blockedMessage, 'Running in progress. Finish it first.');
      expect(
        const SessionInProgress.tracking('cycling').continueLabel,
        'Continue cycling',
      );
    });

    test('unknown sport falls back to Activity', () {
      const s = SessionInProgress.tracking('kitesurfing');
      expect(s.label, 'Activity');
      expect(s.continueLabel, 'Continue activity');
      expect(s.blockedMessage, 'Activity in progress. Finish it first.');
    });
  });

  group('equality', () {
    test('by kind and type', () {
      expect(
        const SessionInProgress.tracking('running'),
        isNot(const SessionInProgress.tracking('cycling')),
      );
      expect(
        const SessionInProgress.gym(),
        isNot(const SessionInProgress.tracking('running')),
      );
      expect(
        const SessionInProgress.tracking('running').hashCode,
        const SessionInProgress.tracking('running').hashCode,
      );
      expect(
        const SessionInProgress.tracking('running').toString(),
        contains('running'),
      );
    });
  });
}
