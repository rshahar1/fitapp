import 'package:fitapp/data/providers.dart';
import 'package:fitapp/data/tracking/sim/simulated_location_source.dart';
import 'package:fitapp/data/tracking/sim/track_simulation.dart';
import 'package:fitapp/data/tracking/sim/val_thorens_session.dart';
import 'package:fitapp/data/tracking/track_csv.dart';
import 'package:fitapp/features/tracking/tracking_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;

/// The simulated Val Thorens session as a [TrackSimulation] (feature 019).
TrackSimulation valThorensSimulation() => TrackSimulation(
  parseTrackCsv(valThorensSessionCsv, start: DateTime.utc(2026)).samples,
);

/// Provider overrides that replace the GPS and the clock with [sim].
List<Override> simulationOverrides(TrackSimulation sim) => [
  simulationProvider.overrideWithValue(sim),
  locationSourceProvider.overrideWithValue(SimulatedLocationSource(sim)),
  clockProvider.overrideWithValue(sim.now),
];

/// Starts the replay when a tracking session goes live and parks it again
/// when the session is saved or thrown away.
void driveSimulation(ProviderContainer container, TrackSimulation sim) {
  container.listen<TrackingUiState>(trackingControllerProvider, (_, next) {
    switch (next) {
      case TrackingLive(:final sessionId):
        sim.startReplay(sessionId);
      case TrackingIdle() || TrackingFinished():
        sim.park();
      case TrackingAcquiring():
        break;
    }
  });
}
