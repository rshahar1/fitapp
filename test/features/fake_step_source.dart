import 'package:fitapp/core/step_source.dart';

/// Controllable [StepSource] for widget tests; records calls.
class FakeStepSource implements StepSource {
  new({this.state = StepAccess.granted, this.steps = 1234});

  StepAccess state;
  int? steps;
  final calls = <String>[];

  /// Per-interval counts keyed by interval start; falls back to [steps].
  final byStart = <DateTime, int>{};

  /// Every [stepsBetween] interval requested.
  final intervals = <(DateTime, DateTime)>[];

  @override
  Future<StepAccess> access() async => state;

  @override
  Future<bool> requestAccess() async {
    calls.add('request');
    return true;
  }

  @override
  Future<void> installHealthConnect() async => calls.add('install');

  bool distanceGranted = true;
  double? meters;

  @override
  Future<bool> distanceAccess() async => distanceGranted;

  @override
  Future<bool> requestDistanceAccess() async => distanceGranted = true;

  @override
  Future<double?> distanceBetween(DateTime start, DateTime end) async =>
      distanceGranted ? meters : null;

  @override
  Future<int?> stepsBetween(DateTime start, DateTime end) async {
    intervals.add((start, end));
    return byStart[start] ?? steps;
  }
}
