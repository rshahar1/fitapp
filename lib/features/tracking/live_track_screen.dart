import 'dart:async';

import 'package:fitapp/app/router.dart';
import 'package:fitapp/app/theme/app_theme.dart';
import 'package:fitapp/app/theme/tokens.dart';
import 'package:fitapp/core/format.dart';
import 'package:fitapp/core/haptics.dart';
import 'package:fitapp/data/providers.dart';
import 'package:fitapp/domain/activity_types.dart';
import 'package:fitapp/domain/tracking/geo.dart';
import 'package:fitapp/domain/tracking/track_reducer.dart' show elapsedAt;
import 'package:fitapp/domain/tracking/track_state.dart';
import 'package:fitapp/features/tracking/finish_sheet.dart';
import 'package:fitapp/features/tracking/tracking_controller.dart';
import 'package:fitapp/features/tracking/widgets/footer_controls.dart';
import 'package:fitapp/features/tracking/widgets/route_map.dart';
import 'package:fitapp/features/workout/widgets/tick.dart';
import 'package:fitapp/widgets/guard.dart';
import 'package:fitapp/widgets/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart' show LatLng;
import 'package:material_ui/material_ui.dart';

/// Whether [typeId] shows speed (cycling) instead of pace (running).
bool usesSpeed(String typeId) => typeId == 'cycling';

LatLng toLatLng(GeoPoint p) => LatLng(p.lat, p.lon);

/// The full-screen live tracking screen. Leaving it (back) keeps the session
/// running; Train shows a banner to return.
class LiveTrackScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<LiveTrackScreen> createState() => _LiveTrackScreenState();
}

class _LiveTrackScreenState extends ConsumerState<LiveTrackScreen> {
  bool _locked = false;
  bool _recovering = false;
  bool _finishing = false;

  @override
  void initState() {
    super.initState();
    if (ref.read(trackingControllerProvider) is TrackingIdle) {
      _recovering = true;
      unawaited(_recover());
    }
  }

  Future<void> _recover() async {
    // Provider state may not be modified while the tree is being built.
    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;
    await ref.read(trackingControllerProvider.notifier).recover();
    if (mounted) setState(() => _recovering = false);
  }

  void _hint(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  Future<void> _finish(TrackingLive live) async {
    if (_finishing) return;
    _finishing = true;
    final haptics = ref.read(hapticsProvider);
    final router = GoRouter.of(context);
    final result = await showFinishSheet(context);
    _finishing = false;
    if (result == null) return;
    if (result == FinishResult.saved) {
      haptics.success();
      router.go(Routes.history);
    } else {
      haptics.warning();
      router.go(Routes.train);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(trackingControllerProvider);
    if (state is! TrackingLive) {
      return Scaffold(
        appBar: AppBar(),
        body: _recovering || state is TrackingFinished
            ? const Center(child: CircularProgressIndicator())
            : EmptyState(
                icon: Icons.directions_run,
                title: 'No activity in progress.',
                action: AppButton(
                  label: 'Back to Train',
                  onPressed: () => context.go(Routes.train),
                ),
              ),
      );
    }
    final ctl = ref.read(trackingControllerProvider.notifier);
    final track = state.state;
    final paused = track.manualPaused;
    final last = state.points.lastOrNull;
    return PopScope(
      canPop: !_locked,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          leading: IconButton(
            tooltip: 'Back',
            icon: const Icon(Icons.arrow_back),
            onPressed: _locked ? null : () => _leave(context),
          ),
          title: Text(activityLabel(state.typeId)),
        ),
        body: Padding(
          padding: const EdgeInsets.fromLTRB(Space.m, 0, Space.m, Space.m),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Hero(typeId: state.typeId, track: track),
              _StatusRow(track: track),
              _Tiles(typeId: state.typeId, track: track),
              const SizedBox(height: Space.m),
              Expanded(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: Sizes.mapMin),
                  child: RouteMap(
                    route: [for (final p in state.points) toLatLng(p)],
                    current: last == null ? null : toLatLng(last),
                    followCurrent: true,
                  ),
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: SafeArea(
          child: Container(
            height: Sizes.footer,
            padding: const EdgeInsets.symmetric(horizontal: Space.m),
            decoration: const BoxDecoration(
              color: AppColors.background,
              border: Border(
                top: BorderSide(
                  color: AppColors.surfaceHigh,
                  width: Sizes.hairline,
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: FooterButton(
                    label: paused ? 'Resume' : 'Pause',
                    icon: paused ? Icons.play_arrow : Icons.pause,
                    primary: paused,
                    onPressed: _locked
                        ? null
                        : () => unawaited(
                            guard(context, paused ? ctl.resume : ctl.pause),
                          ),
                  ),
                ),
                const SizedBox(width: Space.s),
                if (_locked)
                  HoldButton(
                    label: 'Unlock',
                    icon: Icons.lock,
                    iconOnly: true,
                    onCompleted: () => setState(() => _locked = false),
                    onShortPress: () => _hint('Hold to unlock'),
                  )
                else
                  FooterButton(
                    label: 'Lock',
                    icon: Icons.lock_open,
                    iconOnly: true,
                    onPressed: () => setState(() => _locked = true),
                  ),
                const SizedBox(width: Space.s),
                Expanded(
                  child: HoldButton(
                    label: 'Finish',
                    icon: Icons.flag,
                    onCompleted: _locked ? null : () => _finish(state),
                    onShortPress: () => _hint('Hold to finish'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _leave(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(Routes.train);
    }
  }
}

class _Elapsed extends ConsumerWidget {
  const new({required this.track, this.style});

  final TrackState track;
  final TextStyle? style;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Tick(
    builder: (_) => Text(
      formatClock(elapsedAt(track, ref.read(clockProvider)().toUtc())),
      style: style,
    ),
  );
}

class _Hero extends StatelessWidget {
  const new({required this.typeId, required this.track});

  final String typeId;
  final TrackState track;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final style = text.displayLarge?.copyWith(
      fontWeight: FontWeight.w800,
      color: AppColors.textPrimary,
      fontFeatures: tabular,
    );
    final speed = usesSpeed(typeId);
    return Semantics(
      container: true,
      child: Column(
        children: [
          Text(speed ? 'SPEED' : 'TIME', style: text.labelSmall),
          if (speed)
            Text(formatSpeedMps(track.currentSpeedMps), style: style)
          else
            _Elapsed(track: track, style: style),
          if (speed) Text('km/h', style: text.labelSmall),
        ],
      ),
    );
  }
}

/// Fixed height so a pause indicator never shifts the layout.
class _StatusRow extends StatelessWidget {
  const new({required this.track});

  final TrackState track;

  @override
  Widget build(BuildContext context) {
    final label = track.manualPaused
        ? 'Paused'
        : track.autoPaused
        ? 'Auto-paused'
        : null;
    return SizedBox(
      height: Sizes.tap,
      child: Center(
        child: label == null
            ? null
            : Semantics(
                liveRegion: true,
                label: label,
                excludeSemantics: true,
                child: DecoratedBox(
                  decoration: const ShapeDecoration(
                    color: AppColors.surfaceHigh,
                    shape: StadiumBorder(),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Space.m,
                      vertical: Space.xs,
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        color: context.metrics.weight,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

class _Tiles extends ConsumerWidget {
  const new({required this.typeId, required this.track});

  final String typeId;
  final TrackState track;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = context.metrics;
    final distance = MetricTile(
      label: 'Distance',
      value: formatLiveKm(track.distanceMeters),
      caption: 'km',
      color: m.volume,
    );
    final List<Widget> tiles;
    if (usesSpeed(typeId)) {
      tiles = [
        distance,
        MetricTile(
          label: 'Avg speed',
          value: formatSpeedMps(track.avgSpeedMps),
          caption: 'km/h',
        ),
        Tick(
          builder: (_) => MetricTile(
            label: 'Elapsed',
            value: formatClock(
              elapsedAt(track, ref.read(clockProvider)().toUtc()),
            ),
          ),
        ),
        MetricTile(
          label: 'Climb',
          value: '${track.elevationGainMeters.round()}',
          caption: 'm',
          color: m.weight,
        ),
      ];
    } else {
      final split = track.lastSplitSeconds;
      tiles = [
        distance,
        MetricTile(
          label: 'Pace',
          value: formatPaceSec(track.currentPaceSecPerKm),
          caption: '/km',
        ),
        MetricTile(
          label: 'Avg pace',
          value: formatPaceSec(track.avgPaceSecPerKm),
          caption: '/km',
        ),
        MetricTile(
          label: 'Last km',
          value: split == null ? '—' : formatClock(Duration(seconds: split)),
        ),
      ];
    }
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: tiles[0]),
            const SizedBox(width: Space.s),
            Expanded(child: tiles[1]),
          ],
        ),
        const SizedBox(height: Space.s),
        Row(
          children: [
            Expanded(child: tiles[2]),
            const SizedBox(width: Space.s),
            Expanded(child: tiles[3]),
          ],
        ),
      ],
    );
  }
}
