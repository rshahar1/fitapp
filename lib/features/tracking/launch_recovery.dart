import 'dart:async';

import 'package:fitapp/app/router.dart';
import 'package:fitapp/data/providers.dart';
import 'package:fitapp/features/tracking/tracking_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// On app launch: when a tracking session was left behind (the app was
/// killed mid-run), resume it and open the live screen on top of Train.
Future<void> recoverTrackingOnLaunch(ProviderContainer container) async {
  final row = await container.read(trackingRepositoryProvider).session();
  if (row == null) return;
  await container.read(trackingControllerProvider.notifier).recover();
  if (container.read(trackingControllerProvider) is! TrackingLive) return;
  // Completes when the screen is popped: don't wait for it.
  unawaited(container.read(routerProvider).push<void>(Routes.trackLive));
}
