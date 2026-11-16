import 'package:fitapp/core/step_source.dart';
import 'package:fitapp/data/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

class FakeStepSource implements StepSource {
  new({this.state = StepAccess.granted, this.steps = 1234});

  StepAccess state;
  int? steps;
  int accessCalls = 0;
  int stepCalls = 0;
  DateTime? lastStart;
  DateTime? lastEnd;
  final intervals = <(DateTime, DateTime)>[];

  @override
  Future<StepAccess> access() async {
    accessCalls++;
    return state;
  }

  @override
  Future<bool> requestAccess() async => true;

  @override
  Future<void> installHealthConnect() async {}

  @override
  Future<int?> stepsBetween(DateTime start, DateTime end) async {
    stepCalls++;
    lastStart = start;
    lastEnd = end;
    intervals.add((start, end));
    return steps;
  }
}

void main() {
  late Harness h;
  late FakeStepSource source;
  late ProviderContainer c;
  final now = DateTime(2026, 11, 15, 17, 30);

  setUp(() {
    h = Harness();
    source = FakeStepSource();
    c = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(h.db),
        stepSourceProvider.overrideWithValue(source),
        clockProvider.overrideWithValue(() => now),
      ],
    );
  });
  // Keep autoDispose providers alive while awaiting them.
  Future<StepAccess> access() {
    c.listen(stepAccessProvider, (_, _) {});
    return c.read(stepAccessProvider.future);
  }

  Future<int?> today() {
    c.listen(todayStepsProvider, (_, _) {});
    return c.read(todayStepsProvider.future);
  }

  tearDown(() async {
    c.dispose();
    await h.close();
  });

  test('disabled: unavailable and the source is never touched', () async {
    await h.settings.setStepsEnabled(false);
    expect(await access(), StepAccess.unavailable);
    expect(await today(), isNull);
    expect(source.accessCalls, 0);
    expect(source.stepCalls, 0);
  });

  test('granted: returns the count for local midnight..now', () async {
    expect(await today(), 1234);
    expect(source.lastStart, DateTime(2026, 11, 15));
    expect(source.lastEnd, now);
  });

  test('not granted: no step read', () async {
    source.state = StepAccess.notGranted;
    expect(await access(), StepAccess.notGranted);
    expect(await today(), isNull);
    expect(source.stepCalls, 0);
  });

  test('source error (null) yields null', () async {
    source.steps = null;
    expect(await today(), isNull);
  });

  group('daySteps', () {
    Future<int?> day(DateTime d) {
      c.listen(daySteps(d), (_, _) {});
      return c.read(daySteps(d).future);
    }

    test('granted, today: midnight..now', () async {
      expect(await day(DateTime(2026, 11, 15)), 1234);
      expect(source.intervals.single, (DateTime(2026, 11, 15), now));
    });

    test('granted, past day: full local day', () async {
      expect(await day(DateTime(2026, 11, 10)), 1234);
      expect(source.intervals.single, (
        DateTime(2026, 11, 10),
        DateTime(2026, 11, 11),
      ));
    });

    test('future and out-of-window days never call the source', () async {
      expect(await day(DateTime(2026, 11, 16)), isNull);
      expect(await day(DateTime(2026, 10, 15)), isNull);
      expect(source.stepCalls, 0);
      expect(source.accessCalls, 0);
    });

    test('disabled: null without touching the source', () async {
      await h.settings.setStepsEnabled(false);
      expect(await day(DateTime(2026, 11, 15)), isNull);
      expect(source.accessCalls, 0);
      expect(source.stepCalls, 0);
    });

    test('not granted: null without a step read', () async {
      source.state = StepAccess.notGranted;
      expect(await day(DateTime(2026, 11, 15)), isNull);
      expect(source.stepCalls, 0);
    });

    test('source error (null) yields null', () async {
      source.steps = null;
      expect(await day(DateTime(2026, 11, 15)), isNull);
    });
  });
}
