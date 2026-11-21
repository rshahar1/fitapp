import 'package:fitapp/app/theme/tokens.dart';
import 'package:material_ui/material_ui.dart';

/// Iron plate text styles that Material's text theme has no slot for
/// (feature 034). Read them via `context.plate`.
@immutable
class PlateTextStyles extends ThemeExtension<PlateTextStyles> {
  const new();

  static const standard = PlateTextStyles();

  /// Capitals in the display face (titles, names, headers).
  TextStyle display(double size, {Color? color, FontWeight? weight}) =>
      TextStyle(
        fontFamily: AppFonts.display,
        fontSize: size,
        fontWeight: weight ?? FontWeight.w800,
        height: 1,
        letterSpacing: 0.4,
        color: color ?? AppColors.textPrimary,
      );

  /// A big or ticking number: condensed, tabular digits.
  TextStyle number(double size, {Color? color, FontWeight? weight}) =>
      TextStyle(
        fontFamily: AppFonts.number,
        fontSize: size,
        fontWeight: weight ?? FontWeight.w800,
        height: 1,
        fontFeatures: const [FontFeature.tabularFigures()],
        color: color ?? AppColors.textPrimary,
      );

  /// A tape label or plate tag (`PUSH DAY`, `+2.5`, `PR`).
  TextStyle tag({Color? color}) => TextStyle(
    fontFamily: AppFonts.display,
    fontSize: 13,
    fontWeight: FontWeight.w800,
    height: 1,
    letterSpacing: 0.8,
    color: color ?? AppColors.onAccent,
  );

  @override
  PlateTextStyles copyWith() => this;

  @override
  PlateTextStyles lerp(PlateTextStyles? other, double t) => this;
}

extension PlateTextStylesX on BuildContext {
  PlateTextStyles get plate =>
      Theme.of(this).extension<PlateTextStyles>() ?? PlateTextStyles.standard;
}
