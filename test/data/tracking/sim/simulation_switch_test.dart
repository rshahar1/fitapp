import 'package:fitapp/data/tracking/sim/simulation_switch.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('simulationEnabled only with the define in a non-release build', () {
    expect(simulationEnabled(define: true, release: false), isTrue);
    expect(simulationEnabled(define: true, release: true), isFalse);
    expect(simulationEnabled(define: false, release: false), isFalse);
    expect(simulationEnabled(define: false, release: true), isFalse);
  });

  test('kSimulateGps is off without the dart-define', () {
    expect(kSimulateGps, isFalse);
  });
}
