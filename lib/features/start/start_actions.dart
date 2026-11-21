import 'dart:async';

import 'package:fitapp/app/router.dart';
import 'package:fitapp/core/haptics.dart';
import 'package:fitapp/data/providers.dart';
import 'package:fitapp/domain/start_guard.dart';
import 'package:fitapp/widgets/guard.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// The session in progress as currently streamed, for display (hub Continue
/// row, Home hero). Starts re-check the stored state at tap time instead.
final sessionInProgressProvider = Provider<SessionInProgress?>((ref) {
  final workout = ref.watch(activeWorkoutProvider).value;
  final tracking = ref.watch(activeTrackingProvider).value;
  return sessionInProgress(
    hasActiveWorkout: workout != null,
    trackingTypeId: tracking?.typeId,
  );
});

final startActionsProvider = Provider<StartActions>(StartActions.new);

/// Shared start logic for every entry point (feature 011): the hub and template
/// STARTs (the Home hero only continues a session). Gym workouts start only
/// from a template (feature 024). One guard for gym and GPS starts.
class StartActions {
  const new(this._ref);

  final Ref _ref;

  /// The session in progress, read from the database (not the stream cache).
  Future<SessionInProgress?> current() async {
    final tracking = await _ref.read(trackingRepositoryProvider).session();
    final workout = await _ref.read(workoutRepositoryProvider).activeWorkout();
    return sessionInProgress(
      hasActiveWorkout: workout != null,
      trackingTypeId: tracking?.typeId,
    );
  }

  /// Starts a gym workout from the template [templateId] and opens it.
  /// Refused with a message while any session is in progress.
  Future<void> startTemplate(BuildContext context, String templateId) async {
    if (!await _allowed(context)) return;
    if (!context.mounted) return;
    final ok = await guard(
      context,
      () => _ref.read(templateRepositoryProvider).startWorkout(templateId),
    );
    if (!ok || !context.mounted) return;
    _ref.read(hapticsProvider).success();
    unawaited(GoRouter.of(context).push(Routes.workout));
  }

  /// Opens the GPS setup for [typeId]; refused while a session is in progress.
  Future<void> startTracking(BuildContext context, String typeId) async {
    if (!await _allowed(context)) return;
    if (!context.mounted) return;
    unawaited(GoRouter.of(context).push(Routes.newTrack(typeId)));
  }

  /// Opens the session in progress.
  void open(BuildContext context, SessionInProgress session) =>
      unawaited(GoRouter.of(context).push(_routeOf(session)));

  Future<bool> _allowed(BuildContext context) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final router = GoRouter.maybeOf(context);
    final session = await current();
    if (canStart(session)) return true;
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(session!.blockedMessage),
          action: router == null
              ? null
              : SnackBarAction(
                  label: 'Open',
                  onPressed: () => unawaited(router.push(_routeOf(session))),
                ),
        ),
      );
    return false;
  }

  static String _routeOf(SessionInProgress s) => switch (s.kind) {
    SessionKind.gym => Routes.workout,
    SessionKind.tracking => Routes.trackLive,
  };
}
