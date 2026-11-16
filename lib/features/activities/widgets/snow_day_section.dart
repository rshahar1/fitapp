import 'package:fitapp/app/theme/app_theme.dart';
import 'package:fitapp/app/theme/tokens.dart';
import 'package:fitapp/core/format.dart' show formatActivityMinutes;
import 'package:fitapp/data/db/app_database.dart';
import 'package:fitapp/domain/activity_types.dart'
    show distanceKmText, formatGrouped;
import 'package:fitapp/domain/tracking/snow_review.dart';
import 'package:fitapp/domain/tracking/snow_summary.dart';
import 'package:fitapp/features/activities/widgets/snow_compare.dart';
import 'package:fitapp/features/activities/widgets/snow_timeline.dart';
import 'package:fitapp/features/history/route_thumbnail.dart';
import 'package:fitapp/features/tracking/map_style.dart';
import 'package:fitapp/features/tracking/widgets/route_map.dart';
import 'package:fitapp/features/tracking/widgets/snow_route_spans.dart';
import 'package:fitapp/features/tracking/widgets/snow_time_bar.dart';
import 'package:fitapp/widgets/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart' show LatLng;
import 'package:material_ui/material_ui.dart';

/// The body of the detail screen for a tracked snowboarding day (feature
/// 017): map with speed heatmap, totals, time split, run comparison and
/// the timeline of runs and lifts.
class SnowDaySection extends ConsumerWidget {
  const new({required this.activity, super.key});

  final ActivityRow activity;

  /// Whether [activity] is a tracked snowboarding day with readable
  /// segments and route; other snowboarding rows keep the plain layout.
  static bool supports(ActivityRow activity) =>
      activity.typeId == 'snowboarding' &&
      activity.source == 'gps' &&
      decodeSnowRecords(activity.segments).isNotEmpty &&
      decodeRouteOrNull(activity.route) != null;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final records = decodeSnowRecords(activity.segments);
    final descents = snowDescents(records);
    final points = decodeRouteOrNull(activity.route)!;
    final route = [for (final p in points) LatLng(p.lat, p.lon)];
    final parts = snowRouteParts(records);
    final maxKmh = heatmapMaxKmh(records);
    final style = ref.watch(mapStyleProvider);
    void replay(SnowDescent d) =>
        context.push('/activity/${activity.id}/replay/${d.number}');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: Sizes.mapPreview * 1.5,
          child: Stack(
            children: [
              Positioned.fill(
                child: RouteMap(
                  route: route,
                  interactive: true,
                  style: style,
                  spans: [
                    ...snowLiftSpans(parts),
                    ...snowHeatSpans(parts, maxKmh),
                  ],
                  markers: [
                    RouteMarker(route.first, RouteMarkerKind.start),
                    RouteMarker(route.last, RouteMarkerKind.finish),
                  ],
                ),
              ),
              Positioned(
                top: Space.s,
                right: Space.s,
                child: _StyleMenu(
                  style: style,
                  onChoose: (s) =>
                      ref.read(mapStyleProvider.notifier).choose(s),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: Space.s),
        _HeatLegend(maxKmh: maxKmh),
        const SizedBox(height: Space.m),
        _Totals(activity: activity, records: records, descents: descents),
        const SizedBox(height: Space.m),
        SnowTimeBar(
          rideSeconds: activity.movingSeconds ?? 0,
          liftSeconds: activity.liftSeconds ?? 0,
          restSeconds: activity.restSeconds ?? 0,
        ),
        if (descents.length >= 2) ...[
          const SizedBox(height: Space.l),
          SnowCompare(descents: descents, onReplay: replay),
        ],
        const SizedBox(height: Space.l),
        Text('TIMELINE', style: text.labelSmall),
        const SizedBox(height: Space.s),
        SnowTimeline(
          startedAt: activity.startedAt,
          records: records,
          onReplay: replay,
        ),
      ],
    );
  }
}

class _StyleMenu extends StatelessWidget {
  const new({required this.style, required this.onChoose});

  final MapStyle style;
  final ValueChanged<MapStyle> onChoose;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        shape: BoxShape.circle,
      ),
      child: PopupMenuButton<MapStyle>(
        tooltip: 'Map style',
        icon: const Icon(Icons.layers_outlined),
        onSelected: onChoose,
        itemBuilder: (context) => [
          for (final s in MapStyle.values)
            CheckedPopupMenuItem<MapStyle>(
              value: s,
              checked: s == style,
              child: Text(s.label),
            ),
        ],
      ),
    );
  }
}

class _HeatLegend extends StatelessWidget {
  const new({required this.maxKmh});

  final int maxKmh;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final stops = speedColorStops(maxKmh);
    return Semantics(
      container: true,
      label: 'Speed legend',
      excludeSemantics: true,
      child: Row(
        children: [
          for (var i = 0; i < stops.length; i++)
            Expanded(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.heat[i],
                      shape: BoxShape.circle,
                    ),
                    child: const SizedBox.square(dimension: Space.s),
                  ),
                  const SizedBox(width: Space.xs),
                  Text('${stops[i]}', style: text.labelMedium),
                ],
              ),
            ),
          Text('km/h', style: text.labelMedium),
        ],
      ),
    );
  }
}

class _Totals extends StatelessWidget {
  const new({
    required this.activity,
    required this.records,
    required this.descents,
  });

  final ActivityRow activity;
  final List<SnowRecord> records;
  final List<SnowDescent> descents;

  @override
  Widget build(BuildContext context) {
    final meters = activity.distanceMeters;
    final minutes = activity.durationMinutes;
    final moving = activity.movingSeconds;
    final maxSpeed = activity.maxSpeedMps;
    final drop = activity.verticalDropMeters;
    final stats = snowDayStats(records, descents);
    String kmh(double mps) => (mps * 3.6).toStringAsFixed(1);
    final tiles = <Widget>[
      MetricTile(
        label: 'Runs',
        value: '${activity.runCount ?? descents.length}',
      ),
      if (drop != null)
        MetricTile(label: 'Vertical', value: formatGrouped(drop), caption: 'm'),
      if (meters != null)
        MetricTile(
          label: 'Distance',
          value: distanceKmText(meters),
          caption: 'km',
          color: context.metrics.volume,
        ),
      if (maxSpeed != null)
        MetricTile(label: 'Max speed', value: kmh(maxSpeed), caption: 'km/h'),
      if (meters != null && moving != null && moving > 0)
        MetricTile(
          label: 'Avg speed',
          value: kmh(meters / moving),
          caption: 'km/h',
        ),
      if (minutes != null)
        MetricTile(label: 'Duration', value: formatActivityMinutes(minutes)),
      if (stats.highestAlt != null)
        MetricTile(
          label: 'Highest',
          value: formatGrouped(stats.highestAlt!),
          caption: 'm',
        ),
      if (stats.lowestAlt != null)
        MetricTile(
          label: 'Lowest',
          value: formatGrouped(stats.lowestAlt!),
          caption: 'm',
        ),
      if (stats.longestRunMeters != null)
        MetricTile(
          label: 'Longest run',
          value: distanceKmText(stats.longestRunMeters!),
          caption: 'km',
        ),
    ];
    final width =
        (MediaQuery.sizeOf(context).width - 2 * Space.m - Space.s) / 2;
    return Wrap(
      spacing: Space.s,
      runSpacing: Space.s,
      children: [for (final t in tiles) SizedBox(width: width, child: t)],
    );
  }
}
