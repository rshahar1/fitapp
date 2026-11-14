import 'dart:ui';

/// Design tokens (PRD §2.2). The only place colors and sizes are defined.
abstract final class AppColors {
  static const background = Color(0xFF000000);
  static const surface = Color(0xFF1C1C1E);
  static const surfaceHigh = Color(0xFF2C2C2E);
  static const textPrimary = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFF8E8E93);
  static const textTertiary = Color(0xFF5A5A5F);
  static const accent = Color(0xFF11D16C);
  static const onAccent = Color(0xFF000000);
  static const accentSoft = Color(0x2611D16C); // accent at 15 %
  static const danger = Color(0xFFFF453A);
  static const metricSets = Color(0xFFFF453A);
  static const metricReps = Color(0xFF11D16C);
  static const metricVolume = Color(0xFF64D2FF);
  static const metricWeight = Color(0xFFFF9F0A);

  /// Backdrop header wash: background at 45 % alpha.
  static const backdropHeaderScrim = Color(0x73000000);

  /// Backdrop bottom darkening: background at 65 % alpha.
  static const backdropBottomScrim = Color(0xA6000000);

  /// Set-milestone reward (feature 008): brighter accent, mint highlight,
  /// gold spark and the dark green fill of the small figure icon.
  static const accentBright = Color(0xFF2BE07F);
  static const mint = Color(0xFF7CF5B0);
  static const gold = Color(0xFFFFD60A);
  static const rewardIconFill = Color(0xFF14261C);

  /// Reward scrim: background at 65 % alpha.
  static const rewardScrim = Color(0xA6000000);
}

/// Spacing scale.
abstract final class Space {
  static const xxs = 2.0;
  static const xs = 4.0;
  static const s = 8.0;
  static const m = 16.0;
  static const l = 24.0;
  static const xl = 32.0;
  static const xxl = 64.0;
}

abstract final class Radii {
  static const card = 14.0;
  static const pill = 999.0;
  static const chip = 10.0;
}

abstract final class Sizes {
  /// Minimum tap target (dp).
  static const tap = 48.0;
  static const stepperWidth = 56.0;
  static const stepperHeight = 60.0;
  static const hairline = 0.5;

  /// Height of the fixed workout footer (rest pill + Finish).
  static const footer = 72.0;

  /// Footer controls of the live tracking screen (feature 010).
  static const control = 56.0;

  /// Route line width and start/finish dot size on maps.
  static const routeStroke = 4.0;
  static const mapMarker = 14.0;

  /// Height of the route map on the finish sheet.
  static const mapPreview = 200.0;

  /// Smallest map shown on the live screen.
  static const mapMin = 120.0;
}

abstract final class Motion {
  static const fast = Duration(milliseconds: 150);
}
