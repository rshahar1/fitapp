import 'package:fitapp/app/theme/app_icons.dart';
import 'package:fitapp/app/theme/tokens.dart';
import 'package:fitapp/core/format.dart';
import 'package:fitapp/data/db/app_database.dart';
import 'package:fitapp/data/providers.dart';
import 'package:fitapp/domain/tracking/snow_review.dart';
import 'package:fitapp/domain/tracking/snow_summary.dart';
import 'package:fitapp/features/history/route_thumbnail.dart';
import 'package:fitapp/features/tracking/map_style.dart';
import 'package:fitapp/features/tracking/widgets/route_map.dart';
import 'package:fitapp/widgets/widgets.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart' show LatLng;
import 'package:material_ui/material_ui.dart';

/// Replays one snowboarding run (feature 017): the position moves along the
/// run's track with the speed, altitude and time at that moment.
class SnowReplayScreen extends ConsumerStatefulWidget {
  /// Creates the replay of run [runNumber] (1-based) of [activityId].
  const new({required this.activityId, required this.runNumber, super.key});

  final String activityId;
  final int runNumber;

  @override
  ConsumerState<SnowReplayScreen> createState() => _SnowReplayScreenState();
}

/// Playback speeds offered.
const _speeds = [1, 4, 16];

class _SnowReplayScreenState extends ConsumerState<SnowReplayScreen>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final _position = ValueNotifier<double>(0);
  Duration _last = Duration.zero;
  bool _playing = false;
  int _speed = 4;
  double _total = 0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
  }

  @override
  void dispose() {
    _ticker.dispose();
    _position.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    final dt = (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    final next = _position.value + dt * _speed;
    if (next >= _total) {
      _position.value = _total;
      _stop();
    } else {
      _position.value = next;
    }
  }

  void _stop() {
    _ticker.stop();
    if (mounted) setState(() => _playing = false);
  }

  void _play() {
    if (_position.value >= _total) _position.value = 0;
    _last = Duration.zero;
    if (_ticker.isActive) _ticker.stop();
    _ticker.start();
    setState(() => _playing = true);
  }

  void _toggle() => _playing ? _stop() : _play();

  /// The usable track of the run, or null when the replay is not possible.
  List<ReplayPoint>? _trackOf(ActivityRow activity) {
    final route = decodeRouteOrNull(activity.route);
    if (route == null) return null;
    final records = decodeSnowRecords(activity.segments);
    if (records.isEmpty) return null;
    final runs = snowDescents(records);
    final descent = runs.where((d) => d.number == widget.runNumber).firstOrNull;
    if (descent == null) return null;
    final track = replayTrack(records, route, descent);
    return track.length < 2 ? null : track;
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(activityProvider(widget.activityId));
    final activity = async.value;
    final track = activity == null ? null : _trackOf(activity);
    Widget body;
    if (activity == null && async.isLoading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (track == null) {
      body = const EmptyState(
        icon: AppIcons.replay,
        title: 'Replay not available',
        message: 'This run has no stored track to replay.',
      );
    } else {
      _total = replayDuration(track).toDouble();
      body = _buildPlayer(context, track);
    }
    return Scaffold(
      appBar: AppBar(title: Text('Run ${widget.runNumber} replay')),
      body: body,
    );
  }

  Widget _buildPlayer(BuildContext context, List<ReplayPoint> track) {
    final style = ref.watch(mapStyleProvider);
    final points = [for (final p in track) LatLng(p.point.lat, p.point.lon)];
    final origin = track.first.seconds.toDouble();
    return Column(
      children: [
        Expanded(
          child: ValueListenableBuilder<double>(
            valueListenable: _position,
            builder: (context, position, _) {
              final frame = replayAt(track, origin + position)!;
              final last = points.length - 1;
              final seconds = (frame.seconds - origin).round();
              final altitude = frame.altitude;
              return Column(
                children: [
                  Expanded(
                    child: RouteMap(
                      route: points,
                      fitTo: points,
                      interactive: true,
                      style: style,
                      current: LatLng(frame.point.lat, frame.point.lon),
                      spans: frame.index >= last
                          ? const []
                          : [RouteSpan(frame.index, last, AppColors.routeLift)],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(Space.m),
                    child: Row(
                      children: [
                        Expanded(
                          child: MetricTile(
                            label: 'Speed',
                            value: '${frame.speedKmh.round()}',
                            caption: 'km/h',
                          ),
                        ),
                        const SizedBox(width: Space.s),
                        Expanded(
                          child: MetricTile(
                            label: 'Altitude',
                            value: altitude == null
                                ? '—'
                                : '${altitude.round()}',
                            caption: 'm',
                          ),
                        ),
                        const SizedBox(width: Space.s),
                        Expanded(
                          child: MetricTile(
                            label: 'Time',
                            value: formatClock(Duration(seconds: seconds)),
                            caption:
                                'of ${formatClock(Duration(seconds: _total.round()))}',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(Space.m, 0, Space.m, Space.m),
          child: Row(
            children: [
              IconButton(
                tooltip: _playing ? 'Pause' : 'Play',
                iconSize: Space.xl,
                constraints: const BoxConstraints(
                  minWidth: Sizes.tap,
                  minHeight: Sizes.tap,
                ),
                color: AppColors.accent,
                icon: Icon(_playing ? AppIcons.pause : AppIcons.play),
                onPressed: _toggle,
              ),
              Expanded(
                child: ValueListenableBuilder<double>(
                  valueListenable: _position,
                  builder: (context, position, _) => Semantics(
                    label: 'Replay position',
                    child: Slider(
                      max: _total,
                      value: position.clamp(0, _total),
                      onChanged: (v) => _position.value = v,
                    ),
                  ),
                ),
              ),
              Semantics(
                label: 'Replay speed',
                container: true,
                child: ChipSelector<int>(
                  options: _speeds,
                  selected: _speed,
                  labelOf: (s) => '$s×',
                  onSelected: (s) => setState(() => _speed = s),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
