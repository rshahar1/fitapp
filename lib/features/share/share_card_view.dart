import 'dart:math' as math;

import 'package:fitapp/app/theme/app_theme.dart';
import 'package:fitapp/app/theme/tokens.dart';
import 'package:fitapp/core/format.dart' show formatShortDuration;
import 'package:fitapp/domain/share/share_card.dart';
import 'package:fitapp/domain/tracking/snow_review.dart';
import 'package:fitapp/domain/tracking/snow_summary.dart';
import 'package:fitapp/features/activities/activity_icons.dart';
import 'package:fitapp/features/share/share_map.dart';
import 'package:fitapp/features/share/share_route_painter.dart';
import 'package:fitapp/features/tracking/widgets/snow_route_spans.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

/// The shared workout image (feature 027): a fixed
/// [ShareCardSize.width] × [ShareCardSize.height] canvas that renders
/// [data] with a layout per [ShareLayout]. Captured at
/// [ShareCardSize.pixelRatio] it becomes a 1080 × 1350 PNG; gym cards with
/// many exercises grow up to [ShareCardSize.maxHeight] (1080 × 1920).
class ShareCardView extends StatelessWidget {
  const new({required this.data, this.map, super.key});

  final ShareCardData data;

  /// Map tiles under the route of route and snow cards (feature 035); null
  /// draws the route on the plain background.
  final ShareMapImages? map;

  /// Size of the route box of a card with [layout] (route and snow cards).
  static Size routeBoxSize(ShareLayout layout) => Size(
    ShareCardSize.width - 2 * Space.l,
    layout == ShareLayout.snow
        ? ShareCardSize.routeHeight - Space.l
        : ShareCardSize.routeHeight,
  );

  /// The exercise list layout of a gym card with [count] exercises.
  static ShareListLayout listLayout(int count) => shareListLayout(
    count,
    baseHeight: ShareCardSize.height,
    maxHeight: ShareCardSize.maxHeight,
    overhead: ShareCardSize.strengthOverhead,
    rowHeight: ShareCardSize.exerciseRow,
    twoColumnRowHeight: ShareCardSize.twoColumnRow,
  );

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).textTheme.bodyMedium ?? const TextStyle();
    final list = data.layout == ShareLayout.strength
        ? listLayout(data.exercises.length)
        : null;
    return SizedBox(
      width: ShareCardSize.width,
      height: list?.cardHeight ?? ShareCardSize.height,
      // Opaque base first: the PNG must have no transparent pixels.
      child: DecoratedBox(
        decoration: const BoxDecoration(color: AppColors.background),
        child: Stack(
          children: [
            DefaultTextStyle(
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
                    Expanded(child: _body(list)),
                    const SizedBox(height: Space.s),
                    const _Footer(),
                  ],
                ),
              ),
            ),
            // Yellow top rule of the poster.
            const Positioned(
              left: 0,
              top: 0,
              right: 0,
              height: Strokes.cardTop,
              child: ColoredBox(color: AppColors.accent),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body(ShareListLayout? list) => switch (data.layout) {
    ShareLayout.route => _RouteBody(data: data, map: map),
    ShareLayout.snow => _SnowBody(data: data, map: map),
    ShareLayout.strength => _StrengthBody(data: data, list: list!),
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
          decoration: const BoxDecoration(color: AppColors.accentSoft),
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
                  fontFamily: AppFonts.display,
                  fontSize: ShareCardSize.title,
                  fontWeight: FontWeight.w900,
                  height: 1.1,
                  letterSpacing: 0.4,
                ),
              ),
              Text(
                DateFormat('EEE, d MMM y · HH:mm').format(started),
                style: const TextStyle(
                  fontSize: ShareCardSize.minText + 1,
                  color: AppColors.textSecondary,
                  fontFeatures: tabular,
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
          fontFamily: AppFonts.display,
          color: AppColors.accent,
          fontWeight: FontWeight.w900,
          fontSize: ShareCardSize.minText + 3,
          letterSpacing: 0.8,
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

/// A grid of stats, [columns] per row. When a value is too wide for its
/// column, every value in the grid shrinks by the same factor, so a long
/// duration stays the same size as the sets and reps beside it.
class _StatGrid extends StatelessWidget {
  const new({
    required this.stats,
    required this.columns,
    this.valueSize = ShareCardSize.statValue,
  });

  final List<ShareStat> stats;
  final int columns;
  final double valueSize;

  static const _unitSize = ShareCardSize.minText + 1;

  /// The value of [stat] with its digits at [size].
  static TextSpan valueSpan(ShareStat stat, double size, double unitSize) =>
      TextSpan(
        children: [
          for (var i = 0; i < stat.parts.length; i++)
            if (stat.parts[i].isUnit)
              TextSpan(
                text: stat.parts[i].tight
                    ? stat.parts[i].text
                    : ' ${stat.parts[i].text}',
                style: TextStyle(
                  fontFamily: AppFonts.number,
                  fontSize: unitSize,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                  fontFeatures: tabular,
                ),
              )
            else
              TextSpan(
                text: i == 0 ? stat.parts[i].text : ' ${stat.parts[i].text}',
                style: TextStyle(
                  fontFamily: AppFonts.number,
                  fontSize: size,
                  fontWeight: FontWeight.w800,
                  fontFeatures: tabular,
                ),
              ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final rows = <List<ShareStat>>[
      for (var i = 0; i < stats.length; i += columns)
        stats.sublist(i, (i + columns).clamp(0, stats.length)),
    ];
    final base = DefaultTextStyle.of(context).style;
    return LayoutBuilder(
      builder: (context, constraints) {
        final cell = (constraints.maxWidth - (columns - 1) * Space.s) / columns;
        var scale = 1.0;
        for (final stat in stats) {
          final painter = TextPainter(
            text: TextSpan(
              style: base,
              children: [valueSpan(stat, valueSize, _unitSize)],
            ),
            textDirection: Directionality.of(context),
            maxLines: 1,
          )..layout();
          final width = painter.width;
          painter.dispose();
          if (width > cell && width > 0) scale = math.min(scale, cell / width);
        }
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
                              child: _Stat(
                                stat: rows[r][c],
                                valueSize: valueSize * scale,
                                unitSize: _unitSize * scale,
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                ],
              ),
            ],
          ],
        );
      },
    );
  }
}

class _Stat extends StatelessWidget {
  const new({
    required this.stat,
    required this.valueSize,
    required this.unitSize,
  });

  final ShareStat stat;
  final double valueSize;
  final double unitSize;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          stat.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontFamily: AppFonts.display,
            fontSize: ShareCardSize.minText,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: Space.xxs),
        Text.rich(
          _StatGrid.valueSpan(stat, valueSize, unitSize),
          maxLines: 1,
          softWrap: false,
        ),
      ],
    );
  }
}

class _RouteBox extends StatelessWidget {
  const new({required this.painter, required this.height, this.map});

  final ShareRoutePainter painter;
  final double height;
  final ShareMapImages? map;

  @override
  Widget build(BuildContext context) {
    final tiles = map;
    return SizedBox(
      height: height,
      child: ClipRRect(
        child: ColoredBox(
          color: AppColors.surfaceHigh,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (tiles != null) CustomPaint(painter: ShareTilesPainter(tiles)),
              CustomPaint(painter: painter),
              if (tiles != null)
                const Positioned(right: 0, bottom: 0, child: ShareMapCredit()),
            ],
          ),
        ),
      ),
    );
  }
}

class _RouteBody extends StatelessWidget {
  const new({required this.data, this.map});

  final ShareCardData data;
  final ShareMapImages? map;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _RouteBox(
        height: ShareCardSize.routeHeight,
        map: map,
        painter: ShareRoutePainter(points: data.route!, view: map?.view),
      ),
      const Spacer(),
      _StatGrid(stats: data.stats, columns: 3),
      const Spacer(),
    ],
  );
}

class _SnowBody extends StatelessWidget {
  const new({required this.data, this.map});

  final ShareCardData data;
  final ShareMapImages? map;

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
          map: map,
          painter: ShareRoutePainter(
            points: data.route!,
            view: map?.view,
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
                      decoration: BoxDecoration(color: color),
                    ),
                    const SizedBox(width: Space.xs),
                    Flexible(
                      child: Text(
                        '$label ${formatShortDuration(Duration(seconds: seconds))}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: AppFonts.number,
                          fontSize: ShareCardSize.minText + 1,
                          fontWeight: FontWeight.w700,
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
  const new({required this.data, required this.list});

  final ShareCardData data;
  final ShareListLayout list;

  @override
  Widget build(BuildContext context) {
    final exercises = data.exercises;
    final two = list.columns == 2;
    final perColumn = two ? (exercises.length + 1) ~/ 2 : exercises.length;
    final natural = two
        ? ShareCardSize.twoColumnRow
        : ShareCardSize.exerciseRow;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (data.stats.isNotEmpty)
          _StatGrid(stats: data.stats, columns: data.stats.length.clamp(1, 4)),
        const SizedBox(height: Space.m - Space.xs),
        const Divider(
          height: 1,
          thickness: Strokes.rule,
          color: AppColors.surfaceHigh,
        ),
        const SizedBox(height: Space.xs),
        Expanded(
          child: LayoutBuilder(
            builder: (context, c) {
              // Never taller than the space left, so nothing is clipped.
              final row = perColumn == 0
                  ? list.rowHeight
                  : math.min(list.rowHeight, c.maxHeight / perColumn);
              Widget column(Iterable<ShareExerciseLine> lines, double width) =>
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final e in lines)
                        _ExerciseRow(
                          line: e,
                          height: row,
                          naturalHeight: natural,
                          width: width,
                          stacked: two,
                        ),
                    ],
                  );
              if (!two) return column(exercises, c.maxWidth);
              final width = (c.maxWidth - Space.m) / 2;
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: width,
                    child: column(exercises.take(perColumn), width),
                  ),
                  const SizedBox(width: Space.m),
                  SizedBox(
                    width: width,
                    child: column(exercises.skip(perColumn), width),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

/// One exercise: name and set line side by side, or [stacked] (two-column
/// cards). Laid out at [naturalHeight] and scaled down as a whole when the
/// row gets only [height].
class _ExerciseRow extends StatelessWidget {
  const new({
    required this.line,
    required this.height,
    required this.naturalHeight,
    required this.width,
    required this.stacked,
  });

  final ShareExerciseLine line;
  final double height;
  final double naturalHeight;
  final double width;
  final bool stacked;

  @override
  Widget build(BuildContext context) {
    const nameStyle = TextStyle(fontWeight: FontWeight.w600);
    const detailStyle = TextStyle(
      fontFamily: AppFonts.number,
      color: AppColors.textSecondary,
      fontWeight: FontWeight.w700,
      fontFeatures: tabular,
    );
    final content = stacked
        ? Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                line.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: nameStyle,
              ),
              Text(
                line.detail,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: detailStyle.copyWith(fontSize: ShareCardSize.minText),
              ),
            ],
          )
        : Row(
            children: [
              Expanded(
                child: Text(
                  line.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: nameStyle,
                ),
              ),
              const SizedBox(width: Space.s),
              Text(line.detail, style: detailStyle),
            ],
          );
    return SizedBox(
      height: height,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: SizedBox(width: width, height: naturalHeight, child: content),
      ),
    );
  }
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
              fontFamily: AppFonts.display,
              fontSize: ShareCardSize.statValue,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.4,
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
