import 'package:fitapp/app/theme/tokens.dart';
import 'package:fitapp/domain/tracking/snow_review.dart';
import 'package:fitapp/domain/tracking/snow_state.dart';
import 'package:fitapp/features/tracking/widgets/route_map.dart';

/// The lift stretches of a stored snowboarding route, muted (feature 017).
List<RouteSpan> snowLiftSpans(List<SnowRoutePart> parts) => [
  for (final p in parts)
    if (p.kind == SnowKind.lift && p.count >= 2)
      RouteSpan(p.offset, p.offset + p.count - 1, AppColors.routeLift),
];

/// The runs of a stored snowboarding route coloured by speed on a scale up
/// to [maxKmh]: neighbouring points of the same colour form one span.
/// A stretch between two points takes the colour of its faster end.
List<RouteSpan> snowHeatSpans(List<SnowRoutePart> parts, int maxKmh) {
  final out = <RouteSpan>[];
  for (final p in parts) {
    if (p.kind != SnowKind.run || p.speedsKmh.length != p.count) continue;
    int bucketOfStretch(int i) {
      final a = p.speedsKmh[i];
      final b = p.speedsKmh[i + 1];
      return speedBucket(a > b ? a : b, maxKmh);
    }

    var start = 0;
    for (var i = 0; i < p.count - 1; i++) {
      final last = i == p.count - 2;
      if (last || bucketOfStretch(i + 1) != bucketOfStretch(start)) {
        out.add(
          RouteSpan(
            p.offset + start,
            p.offset + i + 1,
            AppColors.heat[bucketOfStretch(start)],
          ),
        );
        start = i + 1;
      }
    }
  }
  return out;
}
