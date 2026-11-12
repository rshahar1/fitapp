import 'dart:ui' as ui;

import 'package:fitapp/app/theme/tokens.dart';
import 'package:material_ui/material_ui.dart';

/// Black background with a subtle decorative layer (PRD §2.2).
class AppBackdrop extends StatelessWidget {
  /// Creates the backdrop around [child].
  const new({super.key, required this.child});

  /// Screen content.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.background,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const ExcludeSemantics(
            child: RepaintBoundary(
              child: IgnorePointer(
                child: CustomPaint(painter: _BackdropPainter()),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _BackdropPainter extends CustomPainter {
  const new();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final reach = size.longestSide;

    // Accent glow, top-right.
    canvas
      ..drawRect(
        rect,
        Paint()
          ..shader = ui.Gradient.radial(Offset(size.width, 0), reach * 0.7, [
            AppColors.accent.withValues(alpha: 0.10),
            AppColors.accent.withValues(alpha: 0),
          ]),
      )
      // Blue glow, bottom-left.
      ..drawRect(
        rect,
        Paint()
          ..shader = ui.Gradient.radial(Offset(0, size.height), reach * 0.6, [
            AppColors.backdropBlue.withValues(alpha: 0.06),
            AppColors.backdropBlue.withValues(alpha: 0),
          ]),
      )
      // Grid fading out toward the middle.
      ..saveLayer(rect, Paint())
      ..drawRect(rect, Paint()..color = const Color(0x00000000));
    final grid = Paint()
      ..color = AppColors.surfaceHigh.withValues(alpha: 0.35)
      ..strokeWidth = Sizes.hairline;
    const cell = Space.xxl;
    for (var x = 0.0; x <= size.width; x += cell) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (var y = 0.0; y <= size.height; y += cell) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    canvas
      ..drawRect(
        rect,
        Paint()
          ..blendMode = BlendMode.dstIn
          ..shader = ui.Gradient.linear(
            Offset.zero,
            Offset(0, size.height * 0.5),
            [AppColors.background, const Color(0x00000000)],
          ),
      )
      ..restore();

    // Thin rising curve near the top.
    final curve = Path()
      ..moveTo(0, size.height * 0.16)
      ..cubicTo(
        size.width * 0.35,
        size.height * 0.17,
        size.width * 0.65,
        size.height * 0.06,
        size.width,
        size.height * 0.03,
      );
    canvas.drawPath(
      curve,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = Sizes.hairline * 2
        ..color = AppColors.accent.withValues(alpha: 0.08),
    );
  }

  @override
  bool shouldRepaint(_BackdropPainter oldDelegate) => false;
}
