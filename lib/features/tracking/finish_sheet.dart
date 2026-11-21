import 'package:fitapp/app/theme/app_icons.dart';
import 'package:fitapp/app/theme/app_theme.dart';
import 'package:fitapp/app/theme/tokens.dart';
import 'package:fitapp/core/format.dart';
import 'package:fitapp/data/providers.dart';
import 'package:fitapp/domain/activity_types.dart';
import 'package:fitapp/domain/tracking/snow_summary.dart';
import 'package:fitapp/domain/tracking/track_reducer.dart' show elapsedAt;
import 'package:fitapp/domain/tracking/track_summary.dart';
import 'package:fitapp/features/tracking/live_track_screen.dart';
import 'package:fitapp/features/tracking/tracking_controller.dart';
import 'package:fitapp/features/tracking/widgets/route_map.dart';
import 'package:fitapp/features/tracking/widgets/snow_time_bar.dart';
import 'package:fitapp/widgets/guard.dart';
import 'package:fitapp/widgets/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// How the finish sheet ended.
enum FinishResult { saved, discarded }

/// Sessions shorter than this (metres) ask before saving.
const shortDistanceMeters = 50;

/// Sessions shorter than this ask before saving.
const shortDuration = Duration(minutes: 1);

/// Shows the summary of the live session. Null when dismissed (tracking goes
/// on).
Future<FinishResult?> showFinishSheet(BuildContext context) =>
    showModalBottomSheet<FinishResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _FinishSheet(),
    );

class _FinishSheet extends ConsumerStatefulWidget {
  const new();

  @override
  ConsumerState<_FinishSheet> createState() => _FinishSheetState();
}

class _FinishSheetState extends ConsumerState<_FinishSheet> {
  final _note = TextEditingController();
  late final TrackingLive _live;
  late final TrackSummary _summary;
  late final SnowSummary? _snow;
  late final Duration _elapsed;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _live = ref.read(trackingControllerProvider) as TrackingLive;
    final ctl = ref.read(trackingControllerProvider.notifier);
    _summary = ctl.previewSummary()!;
    _snow = ctl.previewSnowSummary();
    _elapsed = elapsedAt(_live.state, ref.read(clockProvider)().toUtc());
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  /// Metres for the short-activity check and its message: a snowboarding
  /// day counts the distance ridden downhill, not the lifts.
  num get _distanceMeters => _snow?.rideMeters ?? _summary.distanceMeters;

  bool get _isShort =>
      _distanceMeters < shortDistanceMeters || _elapsed < shortDuration;

  Future<void> _save() async {
    if (_busy) return;
    final ctl = ref.read(trackingControllerProvider.notifier);
    if (_isShort) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Save this short activity?'),
          content: Text(
            '${formatLiveKm(_distanceMeters)} km in '
            '${formatClock(_elapsed)}. Save it anyway?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Save'),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }
    setState(() => _busy = true);
    final done = await guard(context, () => ctl.finish(notes: _note.text));
    if (!mounted) return;
    setState(() => _busy = false);
    if (done) {
      requestSyncFrom(ref); // back up the saved activity (FR-013)
      Navigator.of(context).pop(FinishResult.saved);
    }
  }

  Future<void> _discard() async {
    if (_busy) return;
    final ctl = ref.read(trackingControllerProvider.notifier);
    final ok = await confirmDestructive(
      context,
      title: 'Discard activity?',
      message: 'This recording will be deleted. This cannot be undone.',
      confirmLabel: 'Discard',
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    final done = await guard(context, ctl.discard);
    if (!mounted) return;
    setState(() => _busy = false);
    if (done) Navigator.of(context).pop(FinishResult.discarded);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final m = context.metrics;
    final speed = usesSpeed(_live.typeId);
    final snow = _snow;
    final route = [for (final p in _live.points) toLatLng(p)];
    final avg = speed
        ? formatSpeedMps(_live.state.avgSpeedMps)
        : formatPaceSec(_live.state.avgPaceSecPerKm);
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          Space.m,
          0,
          Space.m,
          Space.m + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${activityLabel(_live.typeId)} summary',
              style: text.titleLarge,
            ),
            const SizedBox(height: Space.m),
            SizedBox(
              height: Sizes.mapPreview,
              child: RouteMap(
                route: route,
                spans: [
                  for (final s in _live.liftSpans)
                    RouteSpan(s.from, s.to, AppColors.routeLift),
                ],
                markers: [
                  if (route.isNotEmpty)
                    RouteMarker(route.first, RouteMarkerKind.start),
                  if (route.length > 1)
                    RouteMarker(route.last, RouteMarkerKind.finish),
                ],
              ),
            ),
            const SizedBox(height: Space.m),
            if (snow != null)
              ..._snowTiles(snow, m)
            else ...[
              Row(
                children: [
                  Expanded(
                    child: MetricTile(
                      label: 'Distance',
                      value: formatLiveKm(_summary.distanceMeters),
                      caption: 'km',
                      color: m.volume,
                    ),
                  ),
                  const SizedBox(width: Space.s),
                  Expanded(
                    child: MetricTile(
                      label: 'Time',
                      value: formatClock(_elapsed),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Space.s),
              Row(
                children: [
                  Expanded(
                    child: MetricTile(
                      label: speed ? 'Avg speed' : 'Avg pace',
                      value: avg,
                      caption: speed ? 'km/h' : '/km',
                    ),
                  ),
                  const SizedBox(width: Space.s),
                  Expanded(
                    child: MetricTile(
                      label: 'Climb',
                      value: '${_summary.elevationGainMeters}',
                      caption: 'm',
                      color: m.weight,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: Space.m),
            TextField(
              controller: _note,
              maxLength: maxActivityNoteLength,
              maxLines: 3,
              minLines: 1,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Note (optional)'),
            ),
            const SizedBox(height: Space.s),
            AppButton(
              label: 'Save',
              icon: AppIcons.check,
              expand: true,
              onPressed: _busy ? null : _save,
            ),
            const SizedBox(height: Space.s),
            AppButton(
              label: 'Discard',
              expand: true,
              variant: AppButtonVariant.danger,
              onPressed: _busy ? null : _discard,
            ),
          ],
        ),
      ),
    );
  }

  /// Runs, vertical, ride distance, speeds and time as a 3 x 2 grid, then
  /// the ride / lift / rest split.
  List<Widget> _snowTiles(SnowSummary snow, MetricColors m) {
    final tiles = [
      MetricTile(label: 'Runs', value: '${snow.runCount}'),
      MetricTile(
        label: 'Vertical',
        value: formatGrouped(snow.dropMeters),
        caption: 'm',
        color: m.weight,
      ),
      MetricTile(
        label: 'Distance',
        value: formatLiveKm(snow.rideMeters),
        caption: 'km',
        color: m.volume,
      ),
      MetricTile(
        label: 'Max speed',
        value: formatSpeedMps(snow.maxSpeedMps),
        caption: 'km/h',
      ),
      MetricTile(
        label: 'Avg speed',
        value: formatSpeedMps(snow.avgSpeedMps),
        caption: 'km/h',
      ),
      MetricTile(label: 'Time', value: formatClock(_elapsed)),
    ];
    return [
      for (var row = 0; row < 2; row++) ...[
        if (row > 0) const SizedBox(height: Space.s),
        Row(
          children: [
            for (var col = 0; col < 3; col++) ...[
              if (col > 0) const SizedBox(width: Space.s),
              Expanded(child: tiles[row * 3 + col]),
            ],
          ],
        ),
      ],
      const SizedBox(height: Space.m),
      SnowTimeBar(
        rideSeconds: snow.rideSeconds,
        liftSeconds: snow.liftSeconds,
        restSeconds: snow.restSeconds,
      ),
    ];
  }
}
