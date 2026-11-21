import 'dart:ui';

/// Design tokens (PRD §2.2, "Iron plate", feature 034). The only place
/// colors, sizes and font families are defined.
///
/// Soot, chalk and competition-plate colors: plate yellow is the single
/// action color; red, green, blue and white plates color the metrics.
abstract final class AppColors {
  /// Soot: screens, the bottom bar, the canvas.
  static const background = Color(0xFF15120F);

  /// Cards, sheets, dialogs, menus.
  static const surface = Color(0xFF201C18);

  /// Rules, pressed rows, stepper wells, empty bars.
  static const surfaceHigh = Color(0xFF2E2822);

  /// Chalk.
  static const textPrimary = Color(0xFFEDE6D8);
  static const textSecondary = Color(0xFF9C9284);

  /// Chevrons and empty check squares only (3.5:1, never body text).
  static const textTertiary = Color(0xFF7A7064);

  /// Plate yellow: the one action color.
  static const accent = Color(0xFFF5C518);
  static const onAccent = Color(0xFF15120F);
  static const accentSoft = Color(0x26F5C518); // accent at 15 %

  /// Session in progress (feature 022): safety orange.
  static const live = Color(0xFFF2711C);

  /// [live] at 15 %.
  static const liveSoft = Color(0x26F2711C); // live at 15 %

  /// Destructive text and icons (readable red, 6.0:1 on surface).
  static const danger = Color(0xFFFF6A5C);

  /// Competition plates, for fills, rails, bars and large numbers.
  static const plateRed = Color(0xFFE5352B);
  static const plateBlue = Color(0xFF3D7BF2);
  static const plateGreen = Color(0xFF2FB85C);

  /// Metric colors (readable tints of the plates; weight is the white
  /// plate so yellow stays the action color).
  static const metricSets = Color(0xFFFF6A5C);
  static const metricReps = plateGreen;
  static const metricVolume = Color(0xFF6FA0FF);
  static const metricWeight = textPrimary;

  /// Lift stretches of a snowboarding route (feature 017).
  static const routeLift = textSecondary;

  /// Speed heatmap of a snowboarding route, slowest to fastest, in plate
  /// order.
  static const heat = [plateBlue, plateGreen, accent, live, plateRed];

  /// Backdrop header wash: soot at 45 % alpha.
  static const backdropHeaderScrim = Color(0x7315120F);

  /// Backdrop bottom darkening: soot at 65 % alpha.
  static const backdropBottomScrim = Color(0xA615120F);

  /// Fully transparent soot (gradient ends).
  static const backgroundClear = Color(0x0015120F);

  /// Set-milestone reward (feature 008): bright yellow flash, chalk
  /// highlight, yellow spark and the figure fill.
  static const accentBright = Color(0xFFFFD84A);
  static const mint = textPrimary;
  static const gold = accent;
  static const rewardIconFill = surfaceHigh;

  /// Reward scrim: soot at 65 % alpha.
  static const rewardScrim = Color(0xA615120F);
}

/// Font families (bundled, SIL OFL 1.1).
abstract final class AppFonts {
  /// Big Shoulders Display, capitals only (800, 900): titles, names,
  /// section headers, tags, the Go label.
  static const display = 'PlateDisplay';

  /// Barlow Condensed with tabular figures (600, 700, 800): big and
  /// ticking numbers.
  static const number = 'BarlowCondensed';

  /// Barlow (400 to 700): everything else.
  static const body = 'Barlow';
}

/// Rule and outline widths.
abstract final class Strokes {
  /// Rules inside grouped lists.
  static const rule = 1.0;

  /// Rules between sections.
  static const section = 2.0;

  /// Yellow top rule of primary cards.
  static const cardTop = 4.0;

  /// Outlined buttons, tape chips, empty check squares.
  static const outline = 1.5;
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

/// Square corners everywhere (feature 034): cards are softened by 2 dp,
/// chips and blocks are sharp.
abstract final class Radii {
  static const card = 2.0;
  static const chip = 0.0;
  static const block = 0.0;
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

/// The shared workout image (feature 027): a fixed 4:5 canvas rendered at
/// [pixelRatio], giving a 1080 × 1350 PNG.
abstract final class ShareCardSize {
  static const width = 360.0;
  static const height = 450.0;
  static const pixelRatio = 3.0;

  /// Height of the route drawing on route and snow cards.
  static const routeHeight = 168.0;

  /// Height of the ride/lift/rest bar.
  static const barHeight = 10.0;

  /// Smallest text on the card (≥ 30 px on the image).
  static const minText = 11.0;
  static const title = 22.0;
  static const statValue = 22.0;
  static const statValueLarge = 30.0;

  /// Tallest card (9:16, 1080 × 1920): only gym cards with many exercises
  /// grow past [height] (feature 029).
  static const maxHeight = 640.0;

  /// Typical heights of the header, the gym totals and the footer, used to
  /// size gym cards (rows shrink if the real ones are taller).
  static const header = 48.0;
  static const statBlock = 52.0;
  static const footer = 20.0;

  /// Everything on a gym card except its exercise rows: padding, header,
  /// gaps, totals, divider and footer.
  static const strengthOverhead =
      2 * Space.l +
      header +
      Space.m +
      statBlock +
      (Space.m - Space.xs) +
      1 +
      Space.xs +
      Space.s +
      footer;

  /// A two-column exercise row (name above the set line).
  static const twoColumnRow = 40.0;

  /// Header icon, one exercise line, the icon of a card without stats.
  static const icon = 22.0;
  static const exerciseRow = 30.0;
  static const emptyIcon = 88.0;
}

abstract final class Motion {
  static const fast = Duration(milliseconds: 150);
}
