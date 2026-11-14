import 'dart:ui' as ui;

import 'package:fitapp/app/theme/tokens.dart';
import 'package:material_ui/material_ui.dart';

/// Size of the figure's drawing space (logical units).
const figureViewBox = Size(200, 170);

/// Animated state of the figure: how much each muscle group has grown, plus
/// glow, strain lines, shake and the white-hot flash before it explodes.
@immutable
class FigurePose {
  const new({
    this.biceps = const Offset(1, 1),
    this.delts = 1,
    this.pecs = 1,
    this.glow = 0.2,
    this.glowScale = 0.8,
    this.strain = 0,
    this.shake = Offset.zero,
    this.flash = 0,
  });

  /// Horizontal and vertical scale of both biceps.
  final Offset biceps;
  final double delts;
  final double pecs;

  /// Opacity and scale of the radial glow behind the figure.
  final double glow;
  final double glowScale;

  /// Opacity of the strain lines over the fists.
  final double strain;

  /// Offset of the body in view-box units.
  final Offset shake;

  /// 0 = normal colours, 1 = nearly white.
  final double flash;

  static const rest = FigurePose();
}

/// Parses the absolute `M`, `L`, `C` and `Z` commands used by the figure.
Path _svg(String d) {
  final path = Path();
  final tokens = RegExp(r'[MLCZ]|-?\d+(?:\.\d+)?')
      .allMatches(d)
      .map((m) => m[0]!)
      .toList();
  var i = 0;
  double n() => double.parse(tokens[i++]);
  var cmd = 'M';
  while (i < tokens.length) {
    if (RegExp('[MLCZ]').hasMatch(tokens[i])) cmd = tokens[i++];
    switch (cmd) {
      case 'M':
        path.moveTo(n(), n());
      case 'L':
        path.lineTo(n(), n());
      case 'C':
        path.cubicTo(n(), n(), n(), n(), n(), n());
      case 'Z':
        path.close();
    }
  }
  return path;
}

final _fore = _svg('M14 92 C12 76 16 60 20 48 L33 48 C35 60 37 76 35 92 Z');
final _fist = _svg(
  'M15 47 C10 38 13 25 22 21 C31 17 40 22 40 32 C40 42 35 49 26 49 '
  'C21 49 17 49 15 47 Z',
);
final _knuckles = _svg('M24 28 C29 26 34 27 38 30 M23 36 C29 34 35 35 39 38');
final _upperArm = _svg(
  'M17 80 L62 70 L68 90 C52 96 36 104 23 102 C10 100 9 85 17 80 Z',
);
final _bicep = _svg(
  'M20 86 C22 66 42 56 56 62 C66 66 69 76 66 84 C52 88 34 90 20 86 Z',
);
final _pec = _svg(
  'M100 70 C92 65 76 65 70 74 C67 86 77 97 90 97 C97 97 100 92 100 86 Z',
);
final _delt = _svg(
  'M56 72 C56 60 66 56 76 60 C84 64 84 76 80 84 C74 90 62 88 58 82 Z',
);
final _oblique = _svg('M75 104 C79 116 80 130 82 146');
final _torso = _svg(
  'M100 52 C94 52 90 53 86 55 C80 60 70 62 62 66 C58 78 62 92 72 104 '
  'L80 150 L120 150 L128 104 C138 92 142 78 138 66 C130 62 120 60 114 55 '
  'C110 53 106 52 100 52 Z',
);
final _neck = _svg('M91 42 L91 54 C96 57 104 57 109 54 L109 42 Z');
final _abs = [
  RRect.fromLTRBR(87, 102, 99, 113, const Radius.circular(4)),
  RRect.fromLTRBR(87, 116, 99, 127, const Radius.circular(4)),
  RRect.fromLTRBR(88, 130, 99, 142, const Radius.circular(4)),
];
const _strainLines = [
  (Offset(40, 50), Offset(40, 40)),
  (Offset(56, 50), Offset(62, 42)),
  (Offset(160, 50), Offset(160, 40)),
  (Offset(144, 50), Offset(138, 42)),
];

/// Neon line-art bodybuilder in a double-biceps pose (feature 008).
///
/// [icon] draws the compact pill version: thick strokes, a dark green fill
/// and no inner detail lines, with no glow.
class MuscleFigurePainter extends CustomPainter {
  const new({this.pose = FigurePose.rest, this.icon = false});

  final FigurePose pose;
  final bool icon;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / figureViewBox.width;
    canvas
      ..save()
      ..scale(scale);
    if (icon) {
      _figure(canvas);
    } else {
      _glow(canvas);
      canvas.translate(pose.shake.dx, pose.shake.dy);
      // Blurred copy under a sharp copy = neon glow.
      final bounds = Offset.zero & figureViewBox;
      canvas.saveLayer(
        bounds.inflate(20),
        Paint()..imageFilter = ui.ImageFilter.blur(sigmaX: 2.5, sigmaY: 2.5),
      );
      _figure(canvas);
      _strain(canvas);
      canvas.restore();
      _figure(canvas);
      _strain(canvas);
    }
    canvas.restore();
  }

  void _glow(Canvas canvas) {
    const center = Offset(100, 85);
    final r = 95 * pose.glowScale;
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..shader = ui.Gradient.radial(center, r, [
          AppColors.accent.withValues(alpha: 0.35 * pose.glow),
          AppColors.accent.withValues(alpha: 0),
        ]),
    );
  }

  void _strain(Canvas canvas) {
    if (pose.strain <= 0) return;
    final paint = Paint()
      ..color = AppColors.mint.withValues(alpha: pose.strain.clamp(0, 1))
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (final (a, b) in _strainLines) {
      canvas.drawLine(a, b, paint);
    }
  }

  void _figure(Canvas canvas) {
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = icon ? 6 : 2
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round
      ..color = Color.lerp(
        AppColors.accent,
        AppColors.textPrimary,
        pose.flash * 0.8,
      )!;
    final detail = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..color = stroke.color;
    final fill = Paint()
      ..color = Color.lerp(
        icon ? AppColors.rewardIconFill : AppColors.surface,
        AppColors.accent,
        pose.flash * 0.5,
      )!;

    void shape(Path p) => canvas
      ..drawPath(p, fill)
      ..drawPath(p, stroke);

    void scaled(Offset origin, Offset s, VoidCallback draw) {
      canvas
        ..save()
        ..translate(origin.dx, origin.dy)
        ..scale(s.dx, s.dy)
        ..translate(-origin.dx, -origin.dy);
      draw();
      canvas.restore();
    }

    void mirrored(VoidCallback draw) {
      draw();
      canvas
        ..save()
        ..translate(figureViewBox.width, 0)
        ..scale(-1, 1);
      draw();
      canvas.restore();
    }

    mirrored(() {
      shape(_fore);
      shape(_fist);
      if (!icon) canvas.drawPath(_knuckles, detail);
      shape(_upperArm);
      scaled(const Offset(43, 86), pose.biceps, () => shape(_bicep));
    });
    shape(_torso);
    mirrored(() {
      final p = pose.pecs;
      scaled(const Offset(86, 92), Offset(p, p), () => shape(_pec));
      if (!icon) {
        for (final r in _abs) {
          canvas.drawRRect(r, detail);
        }
        canvas.drawPath(_oblique, detail);
      }
      final d = pose.delts;
      scaled(const Offset(70, 76), Offset(d, d), () => shape(_delt));
    });
    shape(_neck);
    canvas
      ..drawCircle(const Offset(100, 31), 16, fill)
      ..drawCircle(const Offset(100, 31), 16, stroke)
      ..drawLine(const Offset(80, 150), const Offset(120, 150), stroke);
  }

  @override
  bool shouldRepaint(MuscleFigurePainter old) =>
      old.pose != pose || old.icon != icon;
}
