import 'package:fitapp/app/theme/app_theme.dart';
import 'package:fitapp/app/theme/text_styles.dart';
import 'package:fitapp/app/theme/tokens.dart';
import 'package:fitapp/core/format.dart';
import 'package:fitapp/domain/activity_types.dart' show formatGrouped;
import 'package:fitapp/domain/tracking/snow_reducer.dart';
import 'package:fitapp/domain/tracking/snow_state.dart';
import 'package:fitapp/domain/tracking/track_state.dart';
import 'package:fitapp/widgets/widgets.dart';
import 'package:material_ui/material_ui.dart';

/// The snowboarding live layout (feature 017): current speed, what the
/// rider is doing right now, and six tiles in a 3 x 2 grid that fits small
/// phones. [elapsed] is the screen's ticking elapsed tile.
class SnowLivePanel extends StatelessWidget {
  const new({
    required this.snow,
    required this.track,
    required this.elapsed,
    super.key,
  });

  final SnowState snow;
  final TrackState track;

  /// The Elapsed tile (ticks every second).
  final Widget elapsed;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final m = context.metrics;
    final style = context.plate.number(56);
    final tiles = [
      MetricTile(label: 'Runs', value: '${snowRunCount(snow)}'),
      MetricTile(
        label: 'Vertical',
        value: formatGrouped(snow.dropMeters.round()),
        caption: 'm',
        color: m.weight,
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
      MetricTile(
        label: 'Distance',
        value: formatLiveKm(snow.rideMeters),
        caption: 'km',
        color: m.volume,
      ),
      elapsed,
    ];
    return Column(
      children: [
        Semantics(
          container: true,
          child: Column(
            children: [
              Text(formatSpeedMps(snow.currentSpeedMps), style: style),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('km/h', style: text.labelSmall),
                  const SizedBox(width: Space.s),
                  _StatusChip(snow: snow, track: track),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: Space.xs),
        // Three narrow columns: a slightly smaller value size keeps long
        // values such as 1:08:00 and 1,260 on one line.
        Theme(
          data: Theme.of(context).copyWith(
            textTheme: text.copyWith(
              headlineMedium: text.headlineMedium?.copyWith(fontSize: 20),
            ),
          ),
          child: Column(
            children: [
              for (var row = 0; row < 2; row++) ...[
                if (row > 0) const SizedBox(height: Space.s),
                // Tiles with and without a caption share one height.
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var col = 0; col < 3; col++) ...[
                        if (col > 0) const SizedBox(width: Space.s),
                        Expanded(child: tiles[row * 3 + col]),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Riding / On lift / Resting, or the paused status.
class _StatusChip extends StatelessWidget {
  const new({required this.snow, required this.track});

  final SnowState snow;
  final TrackState track;

  @override
  Widget build(BuildContext context) {
    final (label, color) = track.manualPaused
        ? ('Paused', AppColors.textSecondary)
        : switch (snow.kind) {
            SnowKind.run => ('Riding', AppColors.accent),
            SnowKind.lift => ('On lift', AppColors.routeLift),
            SnowKind.rest => ('Resting', AppColors.textSecondary),
          };
    return Semantics(
      container: true,
      liveRegion: true,
      label: 'Status: $label',
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: const ShapeDecoration(
          color: AppColors.surfaceHigh,
          shape: RoundedRectangleBorder(),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Space.m,
            vertical: Space.xs,
          ),
          child: Text(label, style: context.plate.tag(color: color)),
        ),
      ),
    );
  }
}
