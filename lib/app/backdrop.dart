import 'dart:math' as math;

import 'package:fitapp/app/theme/tokens.dart';
import 'package:material_ui/material_ui.dart';

/// Blurred dark fill image asset.
const backdropFillAsset = 'assets/images/backdrop_fill.jpg';

/// Barbell band image asset.
const backdropBandAsset = 'assets/images/backdrop_band.jpg';

const _bandAspect = 1067 / 1600;
const _barFraction = 0.567;
const _barAnchor = 0.60;
const _bandFade = 180.0;
const _headerHeight = 330.0;
const _bottomFraction = 0.40;

/// Black background with a photo backdrop behind [child] (PRD §2.2).
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
              child: IgnorePointer(child: _BackdropLayers()),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _BackdropLayers extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        final bh = w * _bandAspect;
        final top = _barAnchor * h - _barFraction * bh;
        final fade = math.min(_bandFade, bh / 2) / bh;
        return Stack(
          fit: StackFit.expand,
          children: [
            const Positioned.fill(
              child: Image(
                image: ResizeImage(AssetImage(backdropFillAsset), width: 540),
                fit: BoxFit.cover,
                gaplessPlayback: true,
                excludeFromSemantics: true,
                errorBuilder: _noImage,
              ),
            ),
            Positioned(
              left: 0,
              top: top,
              width: w,
              height: bh,
              child: ShaderMask(
                blendMode: BlendMode.dstIn,
                shaderCallback: (rect) => LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: const [
                    AppColors.backgroundClear,
                    AppColors.background,
                    AppColors.background,
                    AppColors.backgroundClear,
                  ],
                  stops: [0, fade, 1 - fade, 1],
                ).createShader(rect),
                child: Image(
                  image: ResizeImage(
                    const AssetImage(backdropBandAsset),
                    width: (w * dpr).round().clamp(1, 1080),
                  ),
                  fit: BoxFit.fill,
                  gaplessPlayback: true,
                  excludeFromSemantics: true,
                  errorBuilder: _noImage,
                ),
              ),
            ),
            const Positioned(
              left: 0,
              top: 0,
              right: 0,
              height: _headerHeight,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.backdropHeaderScrim,
                      AppColors.backgroundClear,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: h * _bottomFraction,
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.backgroundClear,
                      AppColors.backdropBottomScrim,
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

Widget _noImage(BuildContext context, Object error, StackTrace? stack) =>
    const SizedBox.shrink();
