import 'package:fitapp/app/theme/tokens.dart';
import 'package:fitapp/core/format.dart';
import 'package:material_ui/material_ui.dart';

/// How a snowboarding day's time splits into riding, lifts and rest
/// (feature 017): one bar with a legend.
class SnowTimeBar extends StatelessWidget {
  const new({
    required this.rideSeconds,
    required this.liftSeconds,
    required this.restSeconds,
    super.key,
  });

  final int rideSeconds;
  final int liftSeconds;
  final int restSeconds;

  static const rideColor = AppColors.accent;
  static const liftColor = AppColors.routeLift;
  static const restColor = AppColors.textTertiary;

  static const _height = 10.0;

  @override
  Widget build(BuildContext context) {
    final parts = [
      (label: 'Ride', seconds: rideSeconds, color: rideColor),
      (label: 'Lift', seconds: liftSeconds, color: liftColor),
      (label: 'Rest', seconds: restSeconds, color: restColor),
    ];
    final total = rideSeconds + liftSeconds + restSeconds;
    String time(int seconds) => formatShortDuration(Duration(seconds: seconds));
    return Semantics(
      container: true,
      label:
          'Time split: ${[for (final p in parts) '${p.label} ${time(p.seconds)}'].join(', ')}',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.all(Radius.circular(Radii.pill)),
            child: SizedBox(
              height: _height,
              child: total <= 0
                  ? const ColoredBox(color: AppColors.surfaceHigh)
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final p in parts)
                          if (p.seconds > 0)
                            Expanded(
                              flex: p.seconds,
                              child: ColoredBox(color: p.color),
                            ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: Space.s),
          Row(
            children: [
              for (final p in parts)
                Expanded(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: p.color,
                          shape: BoxShape.circle,
                        ),
                        child: const SizedBox.square(dimension: Space.s),
                      ),
                      const SizedBox(width: Space.xs),
                      Flexible(
                        child: Text(
                          '${p.label} ${time(p.seconds)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
