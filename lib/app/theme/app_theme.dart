import 'package:fitapp/app/theme/text_styles.dart';
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

const _square = RoundedRectangleBorder(
  borderRadius: BorderRadius.all(Radius.circular(Radii.card)),
);
const _sharp = RoundedRectangleBorder();
const _topSquare = RoundedRectangleBorder(
  borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.card)),
);

TextStyle _display(double size, {FontWeight weight = FontWeight.w800}) =>
    TextStyle(
      fontFamily: AppFonts.display,
      fontSize: size,
      fontWeight: weight,
      height: 1.05,
      letterSpacing: 0.4,
      color: AppColors.textPrimary,
    );

/// Bold capitals used on every button label.
const _buttonLabel = TextStyle(
  fontFamily: AppFonts.display,
  fontSize: 17,
  fontWeight: FontWeight.w800,
  letterSpacing: 1,
);

Color _selected(Set<WidgetState> s, Color on, Color off) =>
    s.contains(WidgetState.selected) ? on : off;

/// The always-dark "Iron plate" theme (feature 034).
ThemeData buildAppTheme() {
  const scheme = ColorScheme.dark(
    primary: AppColors.accent,
    onPrimary: AppColors.onAccent,
    primaryContainer: AppColors.accentSoft,
    onPrimaryContainer: AppColors.accent,
    secondary: AppColors.accent,
    onSecondary: AppColors.onAccent,
    secondaryContainer: AppColors.surfaceHigh,
    onSecondaryContainer: AppColors.textPrimary,
    tertiary: AppColors.plateGreen,
    surface: AppColors.surface,
    onSurface: AppColors.textPrimary,
    onSurfaceVariant: AppColors.textSecondary,
    surfaceContainerLowest: AppColors.background,
    surfaceContainerLow: AppColors.surface,
    surfaceContainer: AppColors.surface,
    surfaceContainerHigh: AppColors.surfaceHigh,
    surfaceContainerHighest: AppColors.surfaceHigh,
    surfaceTint: Colors.transparent,
    error: AppColors.danger,
    onError: AppColors.onAccent,
    outline: AppColors.textTertiary,
    outlineVariant: AppColors.surfaceHigh,
    inverseSurface: AppColors.textPrimary,
    onInverseSurface: AppColors.background,
    inversePrimary: AppColors.onAccent,
    shadow: AppColors.background,
    scrim: AppColors.rewardScrim,
  );
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    fontFamily: AppFonts.body,
  );
  final text = base.textTheme.apply(
    fontFamily: AppFonts.body,
    bodyColor: AppColors.textPrimary,
    displayColor: AppColors.textPrimary,
  );
  return base.copyWith(
    scaffoldBackgroundColor: Colors.transparent,
    canvasColor: AppColors.background,
    splashFactory: InkRipple.splashFactory,
    textTheme: text.copyWith(
      displayLarge: _display(56, weight: FontWeight.w900),
      displayMedium: _display(44, weight: FontWeight.w900),
      displaySmall: _display(36, weight: FontWeight.w900),
      headlineLarge: _display(34, weight: FontWeight.w900),
      headlineMedium: _display(30, weight: FontWeight.w900),
      headlineSmall: _display(26),
      titleLarge: _display(24),
      titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      titleSmall: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
      bodyLarge: text.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
      bodyMedium: text.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
      labelLarge: text.labelLarge?.copyWith(fontWeight: FontWeight.w700),
      labelSmall: const TextStyle(
        fontFamily: AppFonts.display,
        fontSize: 13,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.2,
        color: AppColors.textSecondary,
      ),
    ),
    iconTheme: const IconThemeData(
      color: AppColors.textPrimary,
      weight: 600,
      fill: 0,
      grade: 0,
      opticalSize: 24,
    ),
    primaryIconTheme: const IconThemeData(
      color: AppColors.onAccent,
      weight: 600,
      fill: 0,
      grade: 0,
      opticalSize: 24,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: _display(26, weight: FontWeight.w900),
    ),
    cardTheme: const CardThemeData(
      color: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: _square,
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.surfaceHigh,
      thickness: Strokes.rule,
      space: Strokes.rule,
    ),
    listTileTheme: const ListTileThemeData(
      shape: _sharp,
      iconColor: AppColors.textSecondary,
      textColor: AppColors.textPrimary,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      modalBackgroundColor: AppColors.surface,
      showDragHandle: true,
      dragHandleColor: AppColors.textTertiary,
      dragHandleSize: Size(40, Strokes.cardTop),
      shape: _topSquare,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: const Border(
        top: BorderSide(color: AppColors.accent, width: Strokes.cardTop),
      ),
      titleTextStyle: _display(24),
      contentTextStyle: text.bodyMedium?.copyWith(
        color: AppColors.textSecondary,
        fontWeight: FontWeight.w500,
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: AppColors.surfaceHigh,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: _sharp,
      textStyle: text.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
    ),
    menuTheme: const MenuThemeData(
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(AppColors.surfaceHigh),
        surfaceTintColor: WidgetStatePropertyAll(Colors.transparent),
        shape: WidgetStatePropertyAll(_sharp),
        elevation: WidgetStatePropertyAll(0),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.surfaceHigh,
      contentTextStyle: text.bodyMedium?.copyWith(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w600,
      ),
      actionTextColor: AppColors.accent,
      behavior: SnackBarBehavior.floating,
      elevation: 0,
      shape: const Border(
        left: BorderSide(color: AppColors.accent, width: Strokes.cardTop),
      ),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: const BoxDecoration(color: AppColors.surfaceHigh),
      textStyle: text.bodySmall?.copyWith(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w600,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.accent,
        foregroundColor: AppColors.onAccent,
        disabledBackgroundColor: AppColors.surfaceHigh,
        disabledForegroundColor: AppColors.textTertiary,
        shape: _sharp,
        minimumSize: const Size(64, Sizes.tap),
        textStyle: _buttonLabel,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.accent,
        foregroundColor: AppColors.onAccent,
        elevation: 0,
        shape: _sharp,
        minimumSize: const Size(64, Sizes.tap),
        textStyle: _buttonLabel,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.textPrimary,
        side: const BorderSide(
          color: AppColors.textSecondary,
          width: Strokes.outline,
        ),
        shape: _sharp,
        minimumSize: const Size(64, Sizes.tap),
        textStyle: _buttonLabel,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.accent,
        shape: _sharp,
        minimumSize: const Size(48, Sizes.tap),
        textStyle: _buttonLabel.copyWith(fontSize: 16),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: AppColors.textPrimary,
        shape: _sharp,
        minimumSize: const Size(Sizes.tap, Sizes.tap),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.accent,
      foregroundColor: AppColors.onAccent,
      elevation: 0,
      focusElevation: 0,
      hoverElevation: 0,
      highlightElevation: 0,
      shape: _sharp,
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        shape: const WidgetStatePropertyAll(_sharp),
        side: const WidgetStatePropertyAll(
          BorderSide(color: AppColors.surfaceHigh, width: Strokes.outline),
        ),
        backgroundColor: WidgetStateProperty.resolveWith(
          (s) => _selected(s, AppColors.accent, AppColors.surface),
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (s) => _selected(s, AppColors.onAccent, AppColors.textPrimary),
        ),
        textStyle: const WidgetStatePropertyAll(
          TextStyle(
            fontFamily: AppFonts.display,
            fontSize: 15,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
      ),
    ),
    chipTheme: const ChipThemeData(
      backgroundColor: AppColors.surface,
      selectedColor: AppColors.accent,
      disabledColor: AppColors.surfaceHigh,
      checkmarkColor: AppColors.onAccent,
      side: BorderSide(
        color: AppColors.textTertiary,
        width: Strokes.outline,
      ),
      shape: _sharp,
      labelStyle: TextStyle(
        fontFamily: AppFonts.display,
        fontSize: 14,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.8,
        color: AppColors.textPrimary,
      ),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: AppColors.background,
      hintStyle: TextStyle(color: AppColors.textSecondary),
      labelStyle: TextStyle(color: AppColors.textSecondary),
      floatingLabelStyle: TextStyle(color: AppColors.accent),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide(color: AppColors.surfaceHigh),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide(
          color: AppColors.surfaceHigh,
          width: Strokes.outline,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide(
          color: AppColors.accent,
          width: Strokes.section,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide(color: AppColors.danger),
      ),
    ),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: AppColors.accent,
      selectionColor: AppColors.accentSoft,
      selectionHandleColor: AppColors.accent,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.accent,
      linearTrackColor: AppColors.surfaceHigh,
      circularTrackColor: Colors.transparent,
      strokeCap: StrokeCap.butt,
      linearMinHeight: Strokes.cardTop,
    ),
    sliderTheme: const SliderThemeData(
      activeTrackColor: AppColors.accent,
      inactiveTrackColor: AppColors.surfaceHigh,
      thumbColor: AppColors.accent,
      overlayColor: AppColors.accentSoft,
      trackHeight: Strokes.cardTop,
      thumbShape: _SquareThumb(),
      trackShape: RectangularSliderTrackShape(),
    ),
    checkboxTheme: CheckboxThemeData(
      shape: _sharp,
      side: const BorderSide(
        color: AppColors.textTertiary,
        width: Strokes.outline,
      ),
      fillColor: WidgetStateProperty.resolveWith(
        (s) => _selected(s, AppColors.plateGreen, Colors.transparent),
      ),
      checkColor: const WidgetStatePropertyAll(AppColors.onAccent),
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (s) => _selected(s, AppColors.accent, AppColors.textTertiary),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbIcon: const WidgetStatePropertyAll(null),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => _selected(s, AppColors.onAccent, AppColors.textSecondary),
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => _selected(s, AppColors.accent, AppColors.surfaceHigh),
      ),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: AppColors.accent,
      unselectedLabelColor: AppColors.textSecondary,
      indicatorColor: AppColors.accent,
      indicatorSize: TabBarIndicatorSize.tab,
      dividerColor: AppColors.surfaceHigh,
      indicator: const UnderlineTabIndicator(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide(color: AppColors.accent, width: Strokes.cardTop),
      ),
      labelStyle: _display(16),
      unselectedLabelStyle: _display(16),
    ),
    datePickerTheme: DatePickerThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      headerBackgroundColor: AppColors.background,
      headerForegroundColor: AppColors.textPrimary,
      headerHeadlineStyle: _display(30, weight: FontWeight.w900),
      shape: _sharp,
      dayShape: const WidgetStatePropertyAll(_sharp),
      dayForegroundColor: WidgetStateProperty.resolveWith(
        (s) => _selected(s, AppColors.onAccent, AppColors.textPrimary),
      ),
      dayBackgroundColor: WidgetStateProperty.resolveWith(
        (s) => _selected(s, AppColors.accent, Colors.transparent),
      ),
      todayForegroundColor: WidgetStateProperty.resolveWith(
        (s) => _selected(s, AppColors.onAccent, AppColors.accent),
      ),
      todayBackgroundColor: WidgetStateProperty.resolveWith(
        (s) => _selected(s, AppColors.accent, Colors.transparent),
      ),
      todayBorder: const BorderSide(color: AppColors.accent),
      yearShape: const WidgetStatePropertyAll(_sharp),
      cancelButtonStyle: TextButton.styleFrom(
        foregroundColor: AppColors.textSecondary,
      ),
      confirmButtonStyle: TextButton.styleFrom(
        foregroundColor: AppColors.accent,
      ),
    ),
    timePickerTheme: const TimePickerThemeData(
      backgroundColor: AppColors.surface,
      shape: _sharp,
      hourMinuteShape: _sharp,
      dayPeriodShape: _sharp,
      dialBackgroundColor: AppColors.surfaceHigh,
      dialHandColor: AppColors.accent,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.background,
      surfaceTintColor: Colors.transparent,
      indicatorColor: Colors.transparent,
      indicatorShape: const Border(
        top: BorderSide(color: AppColors.accent, width: Strokes.cardTop),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(
          weight: 600,
          color: _selected(s, AppColors.accent, AppColors.textSecondary),
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => TextStyle(
          fontFamily: AppFonts.display,
          fontSize: 13,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
          color: _selected(s, AppColors.accent, AppColors.textSecondary),
        ),
      ),
    ),
    extensions: const [MetricColors.standard, PlateTextStyles.standard],
  );
}

/// A square slider thumb (no round shapes, feature 034).
class _SquareThumb extends SliderComponentShape {
  const new();

  static const _side = 18.0;

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) =>
      const Size(_side, _side);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    context.canvas.drawRect(
      Rect.fromCenter(center: center, width: _side, height: _side),
      Paint()..color = sliderTheme.thumbColor ?? AppColors.accent,
    );
  }
}
