import 'package:fitapp/app/theme/tokens.dart';
import 'package:material_ui/material_ui.dart';

/// Metric colors, readable via `Theme.of(context).extension<MetricColors>()`
/// or the [MetricColorsX] shortcut.
@immutable
class MetricColors extends ThemeExtension<MetricColors> {
  const new({
    required this.sets,
    required this.reps,
    required this.volume,
    required this.weight,
  });

  static const standard = MetricColors(
    sets: AppColors.metricSets,
    reps: AppColors.metricReps,
    volume: AppColors.metricVolume,
    weight: AppColors.metricWeight,
  );

  final Color sets;
  final Color reps;
  final Color volume;
  final Color weight;

  @override
  MetricColors copyWith({
    Color? sets,
    Color? reps,
    Color? volume,
    Color? weight,
  }) => MetricColors(
    sets: sets ?? this.sets,
    reps: reps ?? this.reps,
    volume: volume ?? this.volume,
    weight: weight ?? this.weight,
  );

  @override
  MetricColors lerp(MetricColors? other, double t) {
    if (other == null) return this;
    return MetricColors(
      sets: Color.lerp(sets, other.sets, t)!,
      reps: Color.lerp(reps, other.reps, t)!,
      volume: Color.lerp(volume, other.volume, t)!,
      weight: Color.lerp(weight, other.weight, t)!,
    );
  }
}

extension MetricColorsX on BuildContext {
  MetricColors get metrics =>
      Theme.of(this).extension<MetricColors>() ?? MetricColors.standard;
}

/// Number style with tabular figures.
const tabular = [FontFeature.tabularFigures()];

/// The always-dark app theme.
ThemeData buildAppTheme() {
  const scheme = ColorScheme.dark(
    primary: AppColors.accent,
    secondary: AppColors.accent,
    surface: AppColors.surface,
    surfaceContainerHighest: AppColors.surfaceHigh,
    error: AppColors.danger,
    onError: AppColors.textPrimary,
    outline: AppColors.textTertiary,
    outlineVariant: AppColors.surfaceHigh,
  );
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
  );
  final text = base.textTheme.apply(
    bodyColor: AppColors.textPrimary,
    displayColor: AppColors.textPrimary,
  );
  return base.copyWith(
    scaffoldBackgroundColor: Colors.transparent,
    canvasColor: AppColors.background,
    textTheme: text.copyWith(
      headlineLarge: text.headlineLarge?.copyWith(fontWeight: FontWeight.w800),
      headlineMedium: text.headlineMedium?.copyWith(
        fontWeight: FontWeight.w800,
      ),
      titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      labelSmall: text.labelSmall?.copyWith(
        color: AppColors.textSecondary,
        letterSpacing: 0.8,
        fontWeight: FontWeight.w600,
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
    ),
    cardTheme: const CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(Radii.card)),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.surfaceHigh,
      thickness: Sizes.hairline,
      space: Sizes.hairline,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.card)),
      ),
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.background,
      surfaceTintColor: Colors.transparent,
      indicatorColor: AppColors.accentSoft,
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(
          color: s.contains(WidgetState.selected)
              ? AppColors.accent
              : AppColors.textSecondary,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: s.contains(WidgetState.selected)
              ? AppColors.accent
              : AppColors.textSecondary,
        ),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: AppColors.surfaceHigh,
      contentTextStyle: TextStyle(color: AppColors.textPrimary),
      behavior: SnackBarBehavior.floating,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? AppColors.onAccent
            : AppColors.textSecondary,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? AppColors.accent
            : AppColors.surfaceHigh,
      ),
    ),
    extensions: const [MetricColors.standard],
  );
}
