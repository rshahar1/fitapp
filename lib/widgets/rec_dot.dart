import 'dart:io';

import 'package:fitapp/app/theme/text_styles.dart';
import 'package:fitapp/app/theme/tokens.dart';
import 'package:material_ui/material_ui.dart';

/// The blinking plate-red "recording" square of a session in progress
/// (feature 034). Steady when the system asks for reduced motion, and in
/// widget tests (an endless animation would never settle).
class RecDot extends StatefulWidget {
  /// Creates the square.
  const new({super.key, this.size = 10});

  /// Side length.
  final double size;

  /// Whether the square blinks at all (off under `flutter test`).
  static bool blinks = !Platform.environment.containsKey('FLUTTER_TEST');

  @override
  State<RecDot> createState() => _RecDotState();
}

class _RecDotState extends State<RecDot> with SingleTickerProviderStateMixin {
  late final AnimationController _blink = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final steady = !RecDot.blinks || MediaQuery.disableAnimationsOf(context);
    if (steady) {
      _blink
        ..stop()
        ..value = 1;
    } else if (!_blink.isAnimating) {
      _blink.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _blink.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: CurvedAnimation(parent: _blink, curve: Curves.easeInOutCubic),
      child: SizedBox.square(
        dimension: widget.size,
        child: const ColoredBox(color: AppColors.rec),
      ),
    );
  }
}

/// The blinking red square and "LIVE" label of a session in progress.
class LiveTag extends StatelessWidget {
  /// Creates the tag.
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'In progress',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const RecDot(),
          const SizedBox(width: Space.xs + Space.xxs),
          Text('LIVE', style: context.plate.tag(color: AppColors.liveText)),
        ],
      ),
    );
  }
}
