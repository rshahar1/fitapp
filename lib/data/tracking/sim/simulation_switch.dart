import 'package:flutter/foundation.dart' show kReleaseMode;

/// Whether the dev-only GPS simulation (feature 019) may run, for a build
/// with the `SIMULATE_GPS` define set to [define]: never in a [release]
/// build, whatever the define says.
bool simulationEnabled({required bool define, required bool release}) =>
    define && !release;

/// `--dart-define=SIMULATE_GPS=true` replays the simulated Val Thorens
/// session instead of the real GPS. A compile-time constant: in a release
/// build it is false, so the simulation code and its data are tree-shaken.
const kSimulateGps = bool.fromEnvironment('SIMULATE_GPS') && !kReleaseMode;
