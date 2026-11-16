import 'dart:convert';

import 'package:fitapp/app/theme/app_theme.dart';
import 'package:fitapp/app/theme/tokens.dart';
import 'package:fitapp/core/format.dart';
import 'package:fitapp/data/db/app_database.dart';
import 'package:fitapp/data/providers.dart';
import 'package:fitapp/domain/activity_types.dart';
import 'package:fitapp/domain/tracking/geo.dart';
import 'package:fitapp/features/activities/activity_sheet.dart';
import 'package:fitapp/features/activities/widgets/snow_day_section.dart';
import 'package:fitapp/features/history/route_thumbnail.dart';
import 'package:fitapp/features/tracking/widgets/route_map.dart';
import 'package:fitapp/widgets/guard.dart';
import 'package:fitapp/widgets/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart' show LatLng;
import 'package:material_ui/material_ui.dart';

/// Read-only summary of an activity (GPS or manual): route map and splits
/// when present, the recorded metrics, and the note.
class ActivityDetailScreen extends ConsumerWidget {
  /// Creates the screen for [activityId].
  const new({required this.activityId, super.key});

  /// The activity shown.
  final String activityId;

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    ActivityRow activity,
  ) async {
    final ok = await confirmDestructive(
      context,
      title: 'Delete activity?',
      message: 'This activity will be deleted. This cannot be undone.',
      confirmLabel: 'Delete',
    );
    if (!ok || !context.mounted) return;
    final repo = ref.read(activityRepositoryProvider);
    final done = await guard(context, () => repo.delete(activity.id));
    if (done && context.mounted && context.canPop()) context.pop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(activityProvider(activityId));
    final activity = async.value;
    return Scaffold(
      appBar: AppBar(
        title: Text(activity == null ? '' : activityLabel(activity.typeId)),
        actions: [
          if (activity != null) ...[
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit activity',
              onPressed: () => showActivitySheet(context, existing: activity),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              color: AppColors.danger,
              tooltip: 'Delete activity',
              onPressed: () => _delete(context, ref, activity),
            ),
          ],
        ],
      ),
      body: async.hasError
          ? const Center(child: Text('Could not load this activity.'))
          : activity == null
          ? (async.isLoading
                ? const Center(child: CircularProgressIndicator())
                : const EmptyState(
                    icon: Icons.search_off,
                    title: 'Activity not found',
                    message: 'It may have been deleted.',
                  ))
          : _Body(activity: activity),
    );
  }
}

class _Body extends StatelessWidget {
  const new({required this.activity});

  final ActivityRow activity;

  List<int> get _splits {
    final raw = activity.splits;
    if (raw == null) return const [];
    try {
      final v = jsonDecode(raw);
      return v is List
          ? [
              for (final s in v)
                if (s is num) s.round(),
            ]
          : [];
    } on FormatException {
      return const [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final started = activity.startedAt.toLocal();
    final points = decodeRouteOrNull(activity.route);
    final splits = _splits;
    final note = activity.notes;
    final snow = SnowDaySection.supports(activity);
    return ListView(
      padding: const EdgeInsets.all(Space.m),
      children: [
        Text(
          '${formatDateShort(started)} · ${DateFormat('HH:mm').format(started)}',
          style: text.titleMedium,
        ),
        const SizedBox(height: Space.m),
        if (snow)
          SnowDaySection(activity: activity)
        else ...[
          if (points != null) ...[
            SizedBox(
              height: Sizes.mapPreview * 1.5,
              child: RouteMap(
                route: [for (final p in points) LatLng(p.lat, p.lon)],
                interactive: true,
                markers: _markers(points),
              ),
            ),
            const SizedBox(height: Space.m),
          ],
          _Metrics(activity: activity),
          if (splits.isNotEmpty) ...[
            const SizedBox(height: Space.l),
            Text('SPLITS', style: text.labelSmall),
            const SizedBox(height: Space.s),
            _Splits(splits: splits),
          ],
        ],
        if (note != null && note.isNotEmpty) ...[
          const SizedBox(height: Space.l),
          Text('NOTE', style: text.labelSmall),
          const SizedBox(height: Space.s),
          Text(note, style: text.bodyLarge),
        ],
      ],
    );
  }

  static List<RouteMarker> _markers(List<GeoPoint> points) {
    LatLng ll(GeoPoint p) => LatLng(p.lat, p.lon);
    final km = pointsAtEveryKm(points);
    return [
      for (var i = 0; i < km.length; i++)
        RouteMarker(ll(km[i]), RouteMarkerKind.km, label: '${i + 1}'),
      RouteMarker(ll(points.first), RouteMarkerKind.start),
      RouteMarker(ll(points.last), RouteMarkerKind.finish),
    ];
  }
}

class _Metrics extends StatelessWidget {
  const new({required this.activity});

  final ActivityRow activity;

  @override
  Widget build(BuildContext context) {
    final meters = activity.distanceMeters;
    final minutes = activity.durationMinutes;
    final moving = activity.movingSeconds;
    final climb = activity.elevationGainMeters;
    final tiles = <Widget>[
      if (meters != null)
        MetricTile(
          label: 'Distance',
          value: distanceKmText(meters),
          caption: 'km',
          color: context.metrics.volume,
        ),
      if (minutes != null)
        MetricTile(label: 'Duration', value: formatActivityMinutes(minutes)),
      if (moving != null)
        MetricTile(
          label: 'Moving time',
          value: formatClock(Duration(seconds: moving)),
        ),
      if (meters != null && minutes != null && meters > 0)
        ?switch (activity.typeId) {
          'running' => MetricTile(
            label: 'Avg pace',
            value: formatPace(meters, minutes).replaceAll(' /km', ''),
            caption: '/km',
          ),
          'cycling' => MetricTile(
            label: 'Avg speed',
            value: formatSpeed(meters, minutes).replaceAll(' km/h', ''),
            caption: 'km/h',
          ),
          _ => null,
        },
      if (climb != null)
        MetricTile(label: 'Climb', value: '$climb', caption: 'm'),
    ];
    return Wrap(
      spacing: Space.s,
      runSpacing: Space.s,
      children: [
        for (final t in tiles)
          SizedBox(
            width:
                (MediaQuery.sizeOf(context).width - 2 * Space.m - Space.s) / 2,
            child: t,
          ),
      ],
    );
  }
}

class _Splits extends StatelessWidget {
  const new({required this.splits});

  final List<int> splits;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final slowest = splits.reduce((a, b) => a > b ? a : b);
    final fastest = splits.reduce((a, b) => a < b ? a : b);
    return Group(
      children: [
        for (var i = 0; i < splits.length; i++)
          Semantics(
            container: true,
            label:
                'Kilometre ${i + 1}, ${formatClock(Duration(seconds: splits[i]))}'
                '${splits[i] == fastest ? ', fastest' : ''}',
            excludeSemantics: true,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: Sizes.tap),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: Space.m,
                  vertical: Space.s,
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: Space.xxl - Space.m,
                      child: Text('km ${i + 1}', style: text.bodyMedium),
                    ),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, c) => Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            height: Space.m,
                            width: c.maxWidth * splits[i] / slowest,
                            decoration: BoxDecoration(
                              color: splits[i] == fastest
                                  ? AppColors.accent
                                  : AppColors.textTertiary,
                              borderRadius: BorderRadius.circular(Radii.chip),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: Space.m),
                    Text(
                      formatClock(Duration(seconds: splits[i])),
                      style: text.bodyLarge?.copyWith(
                        fontFeatures: tabular,
                        color: splits[i] == fastest ? AppColors.accent : null,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
