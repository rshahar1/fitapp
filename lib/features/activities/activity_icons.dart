import 'package:fitapp/app/theme/app_icons.dart';
import 'package:fitapp/app/theme/tokens.dart';
import 'package:material_ui/material_ui.dart';

/// Icon of a gym workout in lists.
const gymWorkoutIcon = AppIcons.gym;

/// Icon for an activity type; a generic one for unknown ids. Functional
/// training has no Material icon: render it with [ActivityIcon].
IconData activityIcon(String typeId) => switch (typeId) {
  'cycling' => AppIcons.cycling,
  'snowboarding' => AppIcons.snowboarding,
  'running' => AppIcons.running,
  'pilates' => AppIcons.pilates,
  _ => AppIcons.sport,
};

/// Icon of an activity type: the [FunctionalIcon] for functional training,
/// the Material [activityIcon] for every other type. Sized like an [Icon].
class ActivityIcon extends StatelessWidget {
  /// Creates the icon for [typeId].
  const new(this.typeId, {super.key, this.size, this.color});

  /// Activity type id.
  final String typeId;

  /// Icon box size; defaults to the ambient icon size.
  final double? size;

  /// Icon colour; defaults to the ambient icon colour.
  final Color? color;

  @override
  Widget build(BuildContext context) => typeId == 'functional'
      ? FunctionalIcon(size: size, color: color)
      : Icon(activityIcon(typeId), size: size, color: color);
}

/// Functional training: a person holding a loaded barbell overhead, drawn
/// on the 24-unit Material icon grid with the same limb weight as the
/// Material sport icons (feature 022; Material has no such icon).
class FunctionalIcon extends StatelessWidget {
  /// Creates the icon.
  const new({super.key, this.size, this.color});

  /// Icon box size; defaults to the ambient icon size.
  final double? size;

  /// Icon colour; defaults to the ambient icon colour.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = IconTheme.of(context);
    final box = size ?? theme.size ?? 24;
    // Centred like [Icon], so a tight parent (a badge tile) cannot stretch it.
    return Center(
      widthFactor: 1,
      heightFactor: 1,
      child: SizedBox.square(
        dimension: box,
        child: CustomPaint(
          painter: LifterPainter(
            color ?? theme.color ?? AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

/// Paints [FunctionalIcon] in [color].
class LifterPainter extends CustomPainter {
  /// Creates the painter.
  const new(this.color);

  /// Fill and stroke colour.
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24, size.height / 24);
    final fill = Paint()..color = color;
    final limb = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.square
      ..strokeWidth = 1.9;
    RRect box(double l, double t, double r, double b, double radius) =>
        RRect.fromLTRBR(l, t, r, b, Radius.circular(radius));

    // Barbell: bar and a plate at each end.
    canvas
      ..drawRRect(box(3.5, 4.2, 20.5, 5.6, 0.7), fill)
      ..drawRRect(box(2, 1.8, 4.4, 8, 0.8), fill)
      ..drawRRect(box(19.6, 1.8, 22, 8, 0.8), fill)
      // Arms up to the bar.
      ..drawLine(const Offset(10.3, 11.6), const Offset(7.6, 5.4), limb)
      ..drawLine(const Offset(13.7, 11.6), const Offset(16.4, 5.4), limb)
      // Head, torso, legs.
      ..drawCircle(const Offset(12, 8.6), 1.9, fill)
      ..drawRRect(box(10, 11, 14, 16.2, 1.2), fill)
      ..drawLine(const Offset(10.9, 15.6), const Offset(8.6, 21.6), limb)
      ..drawLine(const Offset(13.1, 15.6), const Offset(15.4, 21.6), limb);
  }

  @override
  bool shouldRepaint(LifterPainter old) => old.color != color;
}
