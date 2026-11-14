import 'dart:math' as math;

import 'package:fitapp/app/theme/tokens.dart';
import 'package:fitapp/features/workout/widgets/reward/muscle_figure.dart';
import 'package:material_ui/material_ui.dart';

/// Timeline of the burst, in milliseconds (approved preview, feature 008).
abstract final class BurstTimeline {
  static const popIn = 380;
  static const pump = 1300;
  static const shakeStart = 850;
  static const shakeBeat = 90;
  static const shakeBeats = 6;
  static const strainStart = 450;
  static const strainLength = 900;
  static const collapse = 1400;
  static const collapseLength = 260;
  static const mainBurst = collapse + 120;
  static const sideBursts = collapse + 520;
  static const ring = 500;
  static const reveal = collapse + 1300;
  static const scrimFade = 300;
  static const total = 3300;
}

/// Displayed size of the figure (dp).
const figureSize = Size(150, 128);

/// Full-screen, non-interactive reward burst centred on [center]: the neon
/// figure pumps three times, collapses and explodes into a firework.
///
/// [onExplode] fires when the firework starts, [onReveal] when the scrim
/// starts to fade (show the pill), [onDone] when everything has finished.
class RewardBurst extends StatefulWidget {
  const new({
    required this.center,
    this.onExplode,
    this.onReveal,
    this.onDone,
    this.seed,
    super.key,
  });

  final Offset center;
  final VoidCallback? onExplode;
  final VoidCallback? onReveal;
  final VoidCallback? onDone;

  /// Fixes the spark pattern (tests).
  final int? seed;

  @override
  State<RewardBurst> createState() => _RewardBurstState();
}

class _RewardBurstState extends State<RewardBurst>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: BurstTimeline.total),
  );
  late final _sparks = Firework.generate(math.Random(widget.seed));
  var _exploded = false;
  var _revealed = false;

  @override
  void initState() {
    super.initState();
    _controller
      ..addListener(_onTick)
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) widget.onDone?.call();
      })
      ..forward();
  }

  void _onTick() {
    final t = _ms;
    if (!_exploded && t >= BurstTimeline.mainBurst) {
      _exploded = true;
      widget.onExplode?.call();
    }
    if (!_revealed && t >= BurstTimeline.reveal) {
      _revealed = true;
      widget.onReveal?.call();
    }
  }

  double get _ms => _controller.value * BurstTimeline.total;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = _ms;
          final figure = figureAt(t);
          return Stack(
            children: [
              Positioned.fill(
                child: ColoredBox(
                  color: AppColors.rewardScrim.withValues(
                    alpha: AppColors.rewardScrim.a * scrimAt(t),
                  ),
                ),
              ),
              if (figure != null)
                Positioned(
                  left: widget.center.dx - figureSize.width / 2,
                  top: widget.center.dy - figureSize.height / 2,
                  width: figureSize.width,
                  height: figureSize.height,
                  child: Opacity(
                    opacity: figure.opacity,
                    child: Transform.translate(
                      offset: Offset(0, figure.dy),
                      child: Transform.scale(
                        scale: figure.scale,
                        child: CustomPaint(
                          painter: MuscleFigurePainter(pose: figure.pose),
                        ),
                      ),
                    ),
                  ),
                ),
              Positioned.fill(
                child: CustomPaint(
                  painter: _FireworkPainter(
                    sparks: _sparks,
                    // The burst comes from the chest, a little above centre.
                    origin: widget.center.translate(0, -10),
                    ms: t,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
}

/// Scrim opacity (0..1) at [t] ms.
double scrimAt(double t) {
  if (t < BurstTimeline.scrimFade) return t / BurstTimeline.scrimFade;
  if (t < BurstTimeline.reveal) return 1;
  return (1 - (t - BurstTimeline.reveal) / BurstTimeline.scrimFade).clamp(0, 1);
}

/// Placement and pose of the figure at [t] ms; null once it has exploded.
({double opacity, double scale, double dy, FigurePose pose})? figureAt(
  double t,
) {
  if (t >= BurstTimeline.collapse + BurstTimeline.collapseLength) return null;

  var opacity = 1.0;
  var scale = 1.0;
  var dy = 0.0;
  var flash = 0.0;
  if (t < BurstTimeline.popIn) {
    final p = t / BurstTimeline.popIn;
    final e = const Cubic(0.3, 1.4, 0.5, 1).transform(p);
    opacity = (p / 0.7).clamp(0, 1);
    scale = 0.5 + 0.5 * e;
    dy = 20 * (1 - e);
  } else if (t >= BurstTimeline.collapse) {
    final k = Curves.easeIn.transform(
      (t - BurstTimeline.collapse) / BurstTimeline.collapseLength,
    );
    opacity = _keys(k, const [0, 0.4, 1], const [1, 1, 0]);
    scale = _keys(k, const [0, 0.4, 1], const [1, 1.1, 0.2]);
    flash = _keys(k, const [0, 0.4, 1], const [0, 0.75, 1]);
  }

  final k = (t / BurstTimeline.pump).clamp(0.0, 1.0);
  double beat(double a, double b, double c) =>
      _keys(k, _beatStops, [1, 1, a, 1, b, a, c], curve: Curves.easeInOut);

  final g = Curves.easeIn.transform(k);
  var shake = Offset.zero;
  const shakeEnd =
      BurstTimeline.shakeStart +
      BurstTimeline.shakeBeat * BurstTimeline.shakeBeats;
  if (t >= BurstTimeline.shakeStart && t < shakeEnd) {
    final p =
        ((t - BurstTimeline.shakeStart) % BurstTimeline.shakeBeat) /
        BurstTimeline.shakeBeat;
    const stops = [0.0, 0.25, 0.5, 0.75, 1.0];
    shake = Offset(
      _keys(p, stops, const [0, -1.2, 1.2, -0.8, 0]),
      _keys(p, stops, const [0, 0.8, -0.6, -1, 0]),
    );
  }

  var strain = 0.0;
  if (t >= BurstTimeline.strainStart) {
    final p = ((t - BurstTimeline.strainStart) / BurstTimeline.strainLength)
        .clamp(0.0, 1.0);
    strain = _keys(p, const [0, 0.3, 0.5, 0.75, 1], const [0, 1, 0, 1, 1]);
  }

  return (
    opacity: opacity,
    scale: scale,
    dy: dy,
    pose: FigurePose(
      biceps: Offset(beat(1.12, 1.22, 1.35), beat(1.2, 1.4, 1.65)),
      delts: beat(1.06, 1.12, 1.2),
      pecs: beat(1.04, 1.08, 1.14),
      glow: 0.2 + 0.8 * g,
      glowScale: 0.8 + 0.4 * g,
      strain: strain,
      shake: shake,
      flash: flash,
    ),
  );
}

const _beatStops = [0.0, 0.18, 0.3, 0.4, 0.54, 0.64, 1.0];

/// Piecewise keyframe interpolation of [values] at [stops] (both ascending).
double _keys(
  double k,
  List<double> stops,
  List<double> values, {
  Curve curve = Curves.linear,
}) {
  if (k <= stops.first) return values.first;
  for (var i = 1; i < stops.length; i++) {
    if (k <= stops[i]) {
      final p = (k - stops[i - 1]) / (stops[i] - stops[i - 1]);
      return values[i - 1] +
          (values[i] - values[i - 1]) * curve.transform(p.clamp(0, 1));
    }
  }
  return values.last;
}

/// One spark. Motion is closed-form so any frame can be drawn directly:
/// each 60 Hz step multiplies velocity by [drag] and adds [gravity] to vy.
@immutable
class Spark {
  const new({
    required this.start,
    required this.from,
    required this.velocity,
    required this.decay,
    required this.color,
    required this.width,
  });

  static const drag = 0.965;
  static const gravity = 0.045;
  static const _terminal = gravity / (1 - drag);

  /// Start time (ms) and position relative to the burst origin.
  final double start;
  final Offset from;
  final Offset velocity;

  /// Life lost per step; the spark is gone when life reaches 0.
  final double decay;
  final Color color;
  final double width;

  /// Position after [n] steps.
  Offset at(double n) {
    final f = drag * (1 - math.pow(drag, n)) / (1 - drag);
    return from +
        Offset(velocity.dx * f, (velocity.dy - _terminal) * f + _terminal * n);
  }

  /// Steps elapsed at [ms], or null when not alive.
  double? stepsAt(double ms) {
    if (ms < start) return null;
    final n = (ms - start) * 60 / 1000;
    return 1 - decay * n > 0 ? n : null;
  }
}

/// Spark set of the reward: a big crackling burst and two side bursts.
abstract final class Firework {
  static const _colors = [
    AppColors.accent,
    AppColors.accent,
    AppColors.accentBright,
    AppColors.mint,
    AppColors.textPrimary,
    AppColors.gold,
  ];

  static List<Spark> generate(math.Random rnd) {
    final sparks = <Spark>[];
    void burst(
      double start,
      Offset at,
      int count,
      double speed, {
      required bool big,
    }) {
      for (var i = 0; i < count; i++) {
        final a = rnd.nextDouble() * math.pi * 2;
        final v = speed * (0.45 + rnd.nextDouble() * 0.75);
        final spark = Spark(
          start: start,
          from: at,
          velocity: Offset(math.cos(a) * v, math.sin(a) * v),
          decay: 0.011 + rnd.nextDouble() * 0.012,
          color: _colors[rnd.nextInt(_colors.length)],
          width: big ? 2.4 : 1.4,
        );
        sparks.add(spark);
        // A third of the big sparks crackle into five small ones.
        if (big && rnd.nextDouble() < 0.35) {
          final n = (0.55 / spark.decay).floorToDouble() + 1;
          burst(start + n * 1000 / 60, spark.at(n), 5, 1.6, big: false);
        }
      }
    }

    const main = BurstTimeline.mainBurst + 0.0;
    const side = BurstTimeline.sideBursts + 0.0;
    burst(main, Offset.zero, 60, 5, big: true);
    burst(side, const Offset(-65, -40), 20, 2.8, big: false);
    burst(side, const Offset(65, -40), 20, 2.8, big: false);
    return sparks;
  }
}

class _FireworkPainter extends CustomPainter {
  const new({required this.sparks, required this.origin, required this.ms});

  final List<Spark> sparks;
  final Offset origin;
  final double ms;

  /// Trail segments drawn per spark and how fast older ones fade.
  static const _trail = 4;
  static const _trailFade = 0.72;

  @override
  void paint(Canvas canvas, Size size) {
    canvas
      ..save()
      ..translate(origin.dx, origin.dy);
    _ring(canvas);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..blendMode = BlendMode.plus;
    for (final s in sparks) {
      final n = s.stepsAt(ms);
      if (n == null) continue;
      final life = 1 - s.decay * n;
      paint.strokeWidth = s.width;
      for (var j = 0; j < _trail; j++) {
        final b = n - j;
        if (b <= 0) break;
        final a = math.max(b - 1, 0).toDouble();
        paint.color = s.color.withValues(
          alpha: (life * math.pow(_trailFade, j)).clamp(0, 1),
        );
        canvas.drawLine(s.at(a), s.at(b), paint);
      }
    }
    canvas.restore();
  }

  void _ring(Canvas canvas) {
    final k = (ms - BurstTimeline.mainBurst) / BurstTimeline.ring;
    if (k < 0 || k > 1) return;
    canvas.drawCircle(
      Offset.zero,
      10 + k * 75,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3 * (1 - k) + 0.5
        ..blendMode = BlendMode.plus
        ..color = AppColors.mint.withValues(alpha: (1 - k) * 0.8),
    );
  }

  @override
  bool shouldRepaint(_FireworkPainter old) => old.ms != ms;
}
