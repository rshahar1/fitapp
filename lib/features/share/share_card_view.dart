import 'package:fitapp/app/theme/app_theme.dart';
import 'package:fitapp/app/theme/tokens.dart';
import 'package:fitapp/core/format.dart' show formatShortDuration;
import 'package:fitapp/domain/share/share_card.dart';
import 'package:fitapp/domain/tracking/snow_review.dart';
import 'package:fitapp/domain/tracking/snow_summary.dart';
import 'package:fitapp/features/activities/activity_icons.dart';
import 'package:fitapp/features/share/share_route_painter.dart';
import 'package:fitapp/features/tracking/widgets/snow_route_spans.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

/// The shared workout image (feature 027): a fixed
/// [ShareCardSize.width] × [ShareCardSize.height] canvas that renders
/// [data] with a layout per [ShareLayout]. Captured at
/// [ShareCardSize.pixelRatio] it becomes a 1080 × 1350 PNG.
class ShareCardView extends StatelessWidget {
  const new({required this.data, super.key});

  final ShareCardData data;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).textTheme.bodyMedium ?? const TextStyle();
    return SizedBox(
      width: ShareCardSize.width,
      height: ShareCardSize.height,
      // Opaque base first: the PNG must have no transparent pixels.
      child: DecoratedBox(
        decoration: const BoxDecoration(color: AppColors.background),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [
                AppColors.accentSoft,
                AppColors.surface,
                AppColors.background,
              ],
              stops: [0, 0.35, 1],
            ),
          ),
          child: DefaultTextStyle(
            style: base.copyWith(
              color: AppColors.textPrimary,
              fontSize: ShareCardSize.minText + 2,
              height: 1.2,
            ),
            child: Padding(
              padding: const EdgeInsets.all(Space.l),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Header(data: data),
                  const SizedBox(height: Space.m),
                  Expanded(child: _body()),
                  const SizedBox(height: Space.s),
                  const _Footer(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _body() => switch (data.layout) {
    ShareLayout.route => _RouteBody(data: data),
    ShareLayout.snow => _SnowBody(data: data),
    ShareLayout.strength => _StrengthBody(data: data),
    ShareLayout.basic => _BasicBody(data: data),
  };
}

class _Header extends StatelessWidget {
  const new({required this.data});

  final ShareCardData data;

  @override
  Widget build(BuildContext context) {
    final started = data.startedAt.toLocal();
    return Row(
      children: [
        Container(
          width: Sizes.tap - Space.s,
          height: Sizes.tap - Space.s,
          decoration: const BoxDecoration(
            color: AppColors.accentSoft,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: data.typeId == 'gym'
              ? const Icon(
                  gymWorkoutIcon,
                  color: AppColors.accent,
                  size: ShareCardSize.icon,
                )
              : ActivityIcon(
                  data.typeId,
                  color: AppColors.accent,
                  size: ShareCardSize.icon,
                ),
        ),
        const SizedBox(width: Space.m - Space.xs),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                data.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: ShareCardSize.title,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                DateFormat('EEE, d MMM y · HH:mm').format(started),
                style: const TextStyle(
                  fontSize: ShareCardSize.minText + 1,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Footer extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) => const Row(
    children: [
      Text(
        'FitApp',
        style: TextStyle(
          color: AppColors.accent,
          fontWeight: FontWeight.w800,
          fontSize: ShareCardSize.minText + 3,
        ),
      ),
      SizedBox(width: Space.s),
      Expanded(
        child: Text(
          'Train · Track · Progress',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: ShareCardSize.minText,
          ),
        ),
      ),
    ],
  );
}

/// A grid of stats, [columns] per row.
class _StatGrid extends StatelessWidget {
  const new({
    required this.stats,
    required this.columns,
    this.valueSize = ShareCardSize.statValue,
  });

  final List<ShareStat> stats;
  final int columns;
  final double valueSize;

  @override
  Widget build(BuildContext context) {
    final rows = <List<ShareStat>>[
      for (var i = 0; i < stats.length; i += columns)
        stats.sublist(i, (i + columns).clamp(0, stats.length)),
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var r = 0; r < rows.length; r++) ...[
          if (r > 0) const SizedBox(height: Space.m - Space.xs),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var c = 0; c < columns; c++)
                Expanded(
                  child: c < rows[r].length
                      ? Padding(
                          padding: EdgeInsets.only(
                            right: c < columns - 1 ? Space.s : 0,
                          ),
                          child: _Stat(stat: rows[r][c], valueSize: valueSize),
                        )
                      : const SizedBox.shrink(),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const new({required this.stat, required this.valueSize});

  final ShareStat stat;
  final double valueSize;

  @override
  Widget build(BuildContext context) {
    final unit = stat.unit;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          stat.label.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: ShareCardSize.minText,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: Space.xxs),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: stat.value,
                  style: TextStyle(
                    fontSize: valueSize,
                    fontWeight: FontWeight.w800,
                    fontFeatures: tabular,
                  ),
                ),
                if (unit != null)
                  TextSpan(
                    text: ' $unit',
                    style: const TextStyle(
                      fontSize: ShareCardSize.minText + 1,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _RouteBox extends StatelessWidget {
  const new({required this.painter, required this.height});

  final ShareRoutePainter painter;
  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(Radii.card),
      child: ColoredBox(
        color: AppColors.surfaceHigh,
        child: CustomPaint(painter: painter, size: Size.infinite),
      ),
    ),
  );
}

class _RouteBody extends StatelessWidget {
  const new({required this.data});

  final ShareCardData data;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _RouteBox(
        height: ShareCardSize.routeHeight,
        painter: ShareRoutePainter(points: data.route!),
      ),
      const Spacer(),
      _StatGrid(stats: data.stats, columns: 3),
      const Spacer(),
    ],
  );
}

class _SnowBody extends StatelessWidget {
  const new({required this.data});

  final ShareCardData data;

  @override
  Widget build(BuildContext context) {
    final parts = snowRouteParts(decodeSnowRecords(data.segments));
    final maxKmh = heatmapMaxKmh(decodeSnowRecords(data.segments));
    final breakdown = data.breakdown;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _RouteBox(
          height: ShareCardSize.routeHeight - Space.l,
          painter: ShareRoutePainter(
            points: data.route!,
            color: AppColors.heat.first,
            spans: [...snowLiftSpans(parts), ...snowHeatSpans(parts, maxKmh)],
          ),
        ),
        if (breakdown != null) ...[
          const SizedBox(height: Space.m - Space.xs),
          _TimeBar(breakdown: breakdown),
        ],
        const Spacer(),
        _StatGrid(stats: data.stats, columns: 3),
        const Spacer(),
      ],
    );
  }
}

class _TimeBar extends StatelessWidget {
  const new({required this.breakdown});

  final ShareTimeBreakdown breakdown;

  @override
  Widget build(BuildContext context) {
    final parts = [
      ('Ride', breakdown.rideSeconds, AppColors.accent),
      ('Lift', breakdown.liftSeconds, AppColors.routeLift),
      ('Rest', breakdown.restSeconds, AppColors.textTertiary),
    ].where((p) => p.$2 > 0).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(Radii.pill),
          child: SizedBox(
            height: ShareCardSize.barHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (_, seconds, color) in parts)
                  Expanded(
                    flex: seconds,
                    child: ColoredBox(color: color),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: Space.s),
        Row(
          children: [
            for (final (label, seconds, color) in parts)
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: Space.s,
                      height: Space.s,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: Space.xs),
                    Flexible(
                      child: Text(
                        '$label ${formatShortDuration(Duration(seconds: seconds))}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: ShareCardSize.minText + 1,
                          fontWeight: FontWeight.w600,
                          fontFeatures: tabular,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _StrengthBody extends StatelessWidget {
  const new({required this.data});

  final ShareCardData data;

  @override
  Widget build(BuildContext context) {
    final hidden = data.hiddenExercises;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (data.stats.isNotEmpty)
          _StatGrid(stats: data.stats, columns: data.stats.length.clamp(1, 4)),
        const SizedBox(height: Space.m - Space.xs),
        const Divider(height: 1, thickness: Sizes.hairline),
        const SizedBox(height: Space.xs),
        Expanded(
          child: ClipRect(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final e in data.exercises) _ExerciseRow(line: e),
                if (hidden > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: Space.xs),
                    child: Text(
                      '+$hidden more exercise${hidden == 1 ? '' : 's'}',
                      style: const TextStyle(
                        color: AppColors.accent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ExerciseRow extends StatelessWidget {
  const new({required this.line});

  final ShareExerciseLine line;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: ShareCardSize.exerciseRow,
    child: Row(
      children: [
        Expanded(
          child: Text(
            line.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(width: Space.s),
        Text(
          line.detail,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontFeatures: tabular,
          ),
        ),
      ],
    ),
  );
}

class _BasicBody extends StatelessWidget {
  const new({required this.data});

  final ShareCardData data;

  @override
  Widget build(BuildContext context) {
    if (data.stats.isEmpty) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ActivityIcon(
            data.typeId,
            color: AppColors.accent,
            size: ShareCardSize.emptyIcon,
          ),
          const SizedBox(height: Space.m),
          const Text(
            'Logged in FitApp',
            style: TextStyle(
              fontSize: ShareCardSize.statValue,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      );
    }
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StatGrid(
          stats: data.stats,
          columns: data.stats.length == 1 ? 1 : 2,
          valueSize: ShareCardSize.statValueLarge,
        ),
      ],
    );
  }
}
