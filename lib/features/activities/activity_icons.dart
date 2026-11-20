import 'package:fitapp/app/theme/tokens.dart';
import 'package:material_ui/material_ui.dart';

/// Icon of a gym workout in lists.
const gymWorkoutIcon = Icons.fitness_center;

/// Emoji shown for functional training: person lifting weights (🏋️),
/// gender-neutral default presentation.
const functionalEmoji = '\u{1F3CB}\u{FE0F}';

/// Icon for an activity type; a generic one for unknown ids. Functional
/// training has no Material icon: render it with [ActivityIcon].
IconData activityIcon(String typeId) => switch (typeId) {
  'cycling' => Icons.directions_bike,
  'snowboarding' => Icons.snowboarding,
  'running' => Icons.directions_run,
  'pilates' => Icons.self_improvement,
  _ => Icons.sports,
};

/// Icon of an activity type: the [functionalEmoji] for functional training,
/// the Material [activityIcon] for every other type. Sized like an [Icon].
class ActivityIcon extends StatelessWidget {
  /// Creates the icon for [typeId].
  const new(this.typeId, {super.key, this.size, this.color});

  /// Activity type id.
  final String typeId;

  /// Icon box size; defaults to the ambient icon size.
  final double? size;

  /// Icon colour; the emoji is painted as a silhouette in it.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    if (typeId != 'functional') {
      return Icon(activityIcon(typeId), size: size, color: color);
    }
    final iconTheme = IconTheme.of(context);
    final box = size ?? iconTheme.size ?? 24;
    final tint = color ?? iconTheme.color ?? AppColors.textSecondary;
    // Paint the colour emoji as a one-colour silhouette so it matches the
    // Material icons around it (owner feedback, feature 022).
    return ExcludeSemantics(
      child: SizedBox(
        width: box,
        height: box,
        child: ColorFiltered(
          colorFilter: ColorFilter.mode(tint, BlendMode.srcIn),
          child: Center(
            child: Text(
              functionalEmoji,
              style: TextStyle(fontSize: box * 0.9, height: 1),
              textScaler: TextScaler.noScaling,
            ),
          ),
        ),
      ),
    );
  }
}
