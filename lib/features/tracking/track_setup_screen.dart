import 'dart:async';

import 'package:fitapp/app/router.dart';
import 'package:fitapp/app/theme/app_theme.dart';
import 'package:fitapp/app/theme/tokens.dart';
import 'package:fitapp/core/haptics.dart';
import 'package:fitapp/data/providers.dart';
import 'package:fitapp/data/tracking/location_source.dart';
import 'package:fitapp/domain/activity_types.dart';
import 'package:fitapp/features/activities/activity_sheet.dart';
import 'package:fitapp/features/tracking/live_track_screen.dart' show toLatLng;
import 'package:fitapp/features/tracking/tracking_controller.dart';
import 'package:fitapp/features/tracking/widgets/route_map.dart';
import 'package:fitapp/widgets/guard.dart';
import 'package:fitapp/widgets/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// Before a live session: location permission, GPS check, Start.
class TrackSetupScreen extends ConsumerStatefulWidget {
  const new({required this.typeId, super.key});

  final String? typeId;

  @override
  ConsumerState<TrackSetupScreen> createState() => _TrackSetupScreenState();
}

class _TrackSetupScreenState extends ConsumerState<TrackSetupScreen>
    with WidgetsBindingObserver {
  late final TrackingController _controller;

  /// True until the user accepted the rationale (permission not yet asked).
  bool _rationale = false;
  bool _checking = true;
  bool _started = false;
  bool _busy = false;
  Timer? _tick;

  /// How long without a good fix before the indoor hint appears.
  static const _lowSignalAfter = Duration(seconds: 20);

  String? get _typeId {
    final id = widget.typeId;
    return id != null && (activityTypeById(id)?.hasLiveTracking ?? false)
        ? id
        : null;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = ref.read(trackingControllerProvider.notifier);
    unawaited(_init());
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _init() async {
    final type = _typeId;
    if (type == null) return;
    final permission = await ref.read(locationSourceProvider).checkPermission();
    if (!mounted) return;
    if (permission == LocationPermissionState.denied) {
      setState(() {
        _rationale = true;
        _checking = false;
      });
      return;
    }
    setState(() => _checking = false);
    await _controller.prepare(type);
  }

  Future<void> _continue() async {
    final type = _typeId;
    if (type == null) return;
    setState(() => _rationale = false);
    await _controller.prepare(type);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Back from system settings: look again.
    final type = _typeId;
    final s = ref.read(trackingControllerProvider);
    if (state == AppLifecycleState.resumed &&
        type != null &&
        !_rationale &&
        s is TrackingAcquiring &&
        (!s.serviceEnabled ||
            s.permission != LocationPermissionState.granted)) {
      unawaited(_controller.prepare(type));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tick?.cancel();
    if (!_started) unawaited(_controller.cancelAcquiring());
    super.dispose();
  }

  Future<void> _start({required bool anyway}) async {
    if (_busy) return;
    final haptics = ref.read(hapticsProvider);
    final router = GoRouter.of(context);
    setState(() => _busy = true);
    final ok = await guard(
      context,
      () => _controller.startSession(anyway: anyway),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (!ok) return;
    _started = true;
    haptics.success();
    unawaited(router.pushReplacement(Routes.trackLive));
  }

  void _logManually() {
    final type = _typeId;
    final root = Navigator.of(context, rootNavigator: true).context;
    context.pop();
    unawaited(showActivitySheet(root, initialTypeId: type));
  }

  @override
  Widget build(BuildContext context) {
    final type = _typeId;
    final state = ref.watch(trackingControllerProvider);
    final Widget body;
    if (type == null) {
      body = const EmptyState(
        icon: Icons.location_off_outlined,
        title: 'This activity has no live tracking',
      );
    } else if (_checking) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_rationale) {
      body = _Rationale(onContinue: _continue, onManual: _logManually);
    } else if (state is TrackingAcquiring) {
      body = _Acquiring(
        state: state,
        lowSignal:
            !state.hasGoodFix &&
            ref.read(clockProvider)().toUtc().difference(state.since) >=
                _lowSignalAfter,
        busy: _busy,
        onStart: () => _start(anyway: false),
        onStartAnyway: () => _start(anyway: true),
        onOpenSettings: _controller.openAppSettings,
        onTurnOn: _controller.openLocationSettings,
        onManual: _logManually,
      );
    } else {
      body = const Center(child: CircularProgressIndicator());
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(type == null ? 'Live tracking' : activityLabel(type)),
      ),
      body: SafeArea(
        child: Padding(padding: const EdgeInsets.all(Space.m), child: body),
      ),
    );
  }
}

class _Rationale extends StatelessWidget {
  const new({required this.onContinue, required this.onManual});

  final VoidCallback onContinue;
  final VoidCallback onManual;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.my_location, color: AppColors.accent),
              const SizedBox(height: Space.s),
              Text('Location is needed', style: text.titleLarge),
              const SizedBox(height: Space.s),
              Text(
                'FitApp uses your location to measure distance, pace and '
                'draw your route, even with the screen off. Your location '
                'stays on this device.',
                style: text.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        AppButton(label: 'Continue', expand: true, onPressed: onContinue),
        TextButton(
          onPressed: onManual,
          style: TextButton.styleFrom(
            minimumSize: const Size.fromHeight(Sizes.tap),
          ),
          child: const Text('Log manually instead'),
        ),
      ],
    );
  }
}

class _Acquiring extends StatelessWidget {
  const new({
    required this.state,
    required this.lowSignal,
    required this.busy,
    required this.onStart,
    required this.onStartAnyway,
    required this.onOpenSettings,
    required this.onTurnOn,
    required this.onManual,
  });

  final TrackingAcquiring state;

  /// No good fix for a while: explain and promote "Start anyway".
  final bool lowSignal;
  final bool busy;
  final VoidCallback onStart;
  final VoidCallback onStartAnyway;
  final VoidCallback onOpenSettings;
  final VoidCallback onTurnOn;
  final VoidCallback onManual;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final granted = state.permission == LocationPermissionState.granted;
    if (!granted) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.location_off_outlined,
                  color: AppColors.danger,
                ),
                const SizedBox(height: Space.s),
                Text('Location permission denied', style: text.titleLarge),
                const SizedBox(height: Space.s),
                Text(
                  'Allow location for FitApp in the system settings to track '
                  'this activity, or log it manually.',
                  style: text.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          AppButton(
            label: 'Open settings',
            expand: true,
            onPressed: onOpenSettings,
          ),
          const SizedBox(height: Space.s),
          AppButton(
            label: 'Log manually instead',
            expand: true,
            variant: AppButtonVariant.secondary,
            onPressed: onManual,
          ),
        ],
      );
    }
    if (!state.serviceEnabled) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.location_disabled, color: AppColors.danger),
                const SizedBox(height: Space.s),
                Text('Location is turned off', style: text.titleLarge),
                const SizedBox(height: Space.s),
                Text(
                  'Turn on location services to get a GPS fix.',
                  style: text.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: Space.m),
          Expanded(
            child: RouteMap(
              route: const [],
              current: state.position == null
                  ? null
                  : toLatLng(state.position!),
              followCurrent: true,
            ),
          ),
          const SizedBox(height: Space.m),
          AppButton(
            label: 'Turn on location',
            expand: true,
            onPressed: onTurnOn,
          ),
          const SizedBox(height: Space.s),
          AppButton(
            label: 'Log manually instead',
            expand: true,
            variant: AppButtonVariant.secondary,
            onPressed: onManual,
          ),
        ],
      );
    }
    final position = state.position;
    final error = state.error;
    final hint = error != null
        ? 'GPS error, retrying: $error'
        : state.hasGoodFix
        ? 'Ready when you are.'
        : lowSignal
        ? 'GPS accuracy is low here (indoors?). Head outside, or tap Start '
              'anyway — the first inaccurate points are skipped.'
        : 'Wait for a good GPS signal, ideally outdoors with a clear sky.';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: Sizes.mapMin),
            child: Stack(
              fit: StackFit.expand,
              children: [
                RouteMap(
                  route: const [],
                  current: position == null ? null : toLatLng(position),
                  followCurrent: true,
                ),
                if (position == null)
                  Center(
                    child: Text(
                      'Finding your location…',
                      style: text.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: Space.m),
        Center(child: _AccuracyChip(accuracy: state.accuracy)),
        const SizedBox(height: Space.m),
        Text(
          hint,
          textAlign: TextAlign.center,
          style: text.bodyMedium?.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: Space.m),
        AppButton(
          label: 'Start',
          icon: Icons.play_arrow,
          expand: true,
          onPressed: state.hasGoodFix && !busy ? onStart : null,
        ),
        if (lowSignal && !state.hasGoodFix)
          Padding(
            padding: const EdgeInsets.only(top: Space.s),
            child: AppButton(
              label: 'Start anyway',
              expand: true,
              variant: AppButtonVariant.secondary,
              onPressed: busy ? null : onStartAnyway,
            ),
          )
        else
          TextButton(
            onPressed: busy ? null : onStartAnyway,
            style: TextButton.styleFrom(
              minimumSize: const Size.fromHeight(Sizes.tap),
            ),
            child: const Text('Start anyway'),
          ),
      ],
    );
  }
}

class _AccuracyChip extends StatelessWidget {
  const new({required this.accuracy});

  final double? accuracy;

  @override
  Widget build(BuildContext context) {
    final a = accuracy;
    final (label, color, icon) = switch (a) {
      null => (
        'Searching for GPS',
        AppColors.textSecondary,
        Icons.gps_not_fixed,
      ),
      _ when a > 20 => (
        'Weak GPS (±${a.round()} m)',
        context.metrics.weight,
        Icons.gps_not_fixed,
      ),
      _ => ('GPS ready (±${a.round()} m)', AppColors.accent, Icons.gps_fixed),
    };
    return Semantics(
      container: true,
      liveRegion: true,
      label: label,
      excludeSemantics: true,
      child: Container(
        constraints: const BoxConstraints(minHeight: Sizes.tap),
        padding: const EdgeInsets.symmetric(horizontal: Space.m),
        decoration: const ShapeDecoration(
          color: AppColors.surfaceHigh,
          shape: StadiumBorder(),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color),
            const SizedBox(width: Space.s),
            Text(
              label,
              style: TextStyle(color: color, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}
