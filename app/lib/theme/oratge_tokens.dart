// Generated from design-system/tokens.json — Oratge design tokens.
// Do not hand-edit values here; regenerate when tokens.json changes.
import 'package:flutter/material.dart';

/// Theme-dependent colours. Access with `context.og` (see extension below).
@immutable
class OratgeColors extends ThemeExtension<OratgeColors> {
  const OratgeColors({
    required this.bg,
    required this.night,
    required this.surface,
    required this.surface2,
    required this.line,
    required this.text,
    required this.text2,
    required this.text3,
    required this.cloud,
    required this.sand,
    required this.wind,
    required this.heat,
    required this.water,
    required this.sun,
    required this.storm,
    required this.snow,
    required this.r0,
    required this.r1,
    required this.r2,
    required this.r3,
    required this.r4,
    required this.r5,
    required this.wind1,
    required this.wind2,
    required this.wind3,
    required this.wind4,
    required this.wind5,
    required this.warnYellow,
    required this.warnOrange,
    required this.warnRed,
  });

  /// Page background, set by OratgeRoot; BottomNav background; text on an active tab or chip.
  final Color bg;
  /// Night shading in hour and multi-day charts.
  final Color night;
  /// Cards: Card, og-card, FactTile, inactive tabs and chips. Same tint as og-bg, one step lighter.
  final Color surface;
  /// Nested or raised surfaces inside a card (og-card og-raised).
  final Color surface2;
  /// Hairlines: row dividers, nav border, pill borders, chart ticks and hatching. Decorative only.
  final Color line;
  /// Primary text on og-bg, og-surface and og-surface-2: dark ≥13.01:1, light ≥13.69:1.
  final Color text;
  /// Secondary text: muted copy, chips, legends on og-bg, og-surface and og-surface-2: dark ≥7.51:1, light ≥7.01:1.
  final Color text2;
  /// Faint text: labels, inactive nav, footnotes on og-bg, og-surface and og-surface-2: dark ≥4.52:1, light ≥4.53:1.
  final Color text3;
  /// Neutral cloud and moon tone in weather glyphs.
  final Color cloud;
  /// Dashed shoreline in WindCompass.
  final Color sand;
  /// Wind only: wind lines, arrows, tailwind, the sea side of WindCompass. Same hue in both themes, a lighter step in dark: ≥6.5:1 on dark surfaces, ≥3.2:1 on light. Use it for lines, marks, icons and large values (20px+ semibold), never small text.
  final Color wind;
  /// Heat and temperature only: temperature lines, headwind. Same hue in both themes, a lighter step in dark: ≥6.5:1 on dark surfaces, ≥3.2:1 on light. Use it for lines, marks, icons and large values (20px+ semibold), never small text.
  final Color heat;
  /// Water only: rain, waves, swell. Same hue in both themes, a lighter step in dark: ≥6.5:1 on dark surfaces, ≥3.2:1 on light. Use it for lines, marks, icons and large values (20px+ semibold), never small text.
  final Color water;
  /// Sun and UV only. Same hue in both themes, a lighter step in dark: ≥6.5:1 on dark surfaces, ≥3.2:1 on light. Use it for lines, marks, icons and large values (20px+ semibold), never small text.
  final Color sun;
  /// Storm and lightning only. Same hue in both themes, a lighter step in dark: ≥6.5:1 on dark surfaces, ≥3.8:1 on light. Use it for lines, marks, icons and large values (20px+ semibold), never small text.
  final Color storm;
  /// Snow and cold only. Same hue in both themes, a lighter step in dark: ≥8.0:1 on dark surfaces, ≥3.2:1 on light. Use it for lines, marks, icons and large values (20px+ semibold), never small text.
  final Color snow;
  /// Rating 0: an empty rating cell or dot.
  final Color r0;
  /// Rating 1 on the green ramp; in dark it brightens with the rating, in light it saturates. Always shown with the dot count (RatingDots, RatingStrip, HourChart rating row). Dark ≥3.3:1, light ≥3.2:1.
  final Color r1;
  /// Rating 2 on the green ramp. Dark ≥4.6:1, light ≥3.2:1.
  final Color r2;
  /// Rating 3 on the green ramp. Dark ≥6.3:1, light ≥3.2:1.
  final Color r3;
  /// Rating 4 on the green ramp. Dark ≥8.4:1, light ≥3.2:1.
  final Color r4;
  /// Rating 5 on the green ramp. Dark ≥10.5:1, light ≥3.2:1.
  final Color r5;
  /// Wind speed band under 8 kn. Used by SpotCard and wind cells; brighter step in dark.
  final Color wind1;
  /// Wind speed 8–11 kn. Used by SpotCard and wind cells; brighter step in dark.
  final Color wind2;
  /// Wind speed 11–14 kn. Used by SpotCard and wind cells; brighter step in dark.
  final Color wind3;
  /// Wind speed 14–17 kn. Used by SpotCard and wind cells; brighter step in dark.
  final Color wind4;
  /// Wind speed 17 kn and above. Used by SpotCard and wind cells; brighter step in dark.
  final Color wind5;
  /// Yellow Meteocat warning: reserved for WarningBanner and map warning areas. Same hue in both themes, lighter in dark: ≥6.5:1 dark, ≥3.2:1 light; always paired with the level word.
  final Color warnYellow;
  /// Orange Meteocat warning: reserved for WarningBanner and map warning areas. Same hue in both themes, lighter in dark: ≥6.5:1 dark, ≥3.2:1 light; always paired with the level word.
  final Color warnOrange;
  /// Red Meteocat warning: reserved for WarningBanner and map warning areas. Same hue in both themes, lighter in dark: ≥6.5:1 dark, ≥3.2:1 light; always paired with the level word.
  final Color warnRed;

  static const dark = OratgeColors(
    bg: Color(0xFF150F0B),
    night: Color(0xFF1B1511),
    surface: Color(0xFF201B16),
    surface2: Color(0xFF2B2521),
    line: Color(0xFF3B3531),
    text: Color(0xFFF2EDEA),
    text2: Color(0xFFBFB5AE),
    text3: Color(0xFF948B83),
    cloud: Color(0xFFB1A79F),
    sand: Color(0xFFC9B49A),
    wind: Color(0xFF4FBE8A),
    heat: Color(0xFFFF8A5B),
    water: Color(0xFF2DB4FB),
    sun: Color(0xFFEF9600),
    storm: Color(0xFFBE9CE6),
    snow: Color(0xFF94C4D7),
    r0: Color(0xFF2B2521),
    r1: Color(0xFF6E7962),
    r2: Color(0xFF809468),
    r3: Color(0xFF92B169),
    r4: Color(0xFFA5CE6F),
    r5: Color(0xFFBAE581),
    wind1: Color(0xFF657B6E),
    wind2: Color(0xFF6D9780),
    wind3: Color(0xFF70B691),
    wind4: Color(0xFF78D4A5),
    wind5: Color(0xFF8AECB9),
    warnYellow: Color(0xFFD2A400),
    warnOrange: Color(0xFFFF8C3B),
    warnRed: Color(0xFFF18E96),
  );

  static const light = OratgeColors(
    bg: Color(0xFFF8F2EE),
    night: Color(0xFFEFE8E3),
    surface: Color(0xFFFFFDFB),
    surface2: Color(0xFFEDE6E2),
    line: Color(0xFFDAD3CD),
    text: Color(0xFF211C17),
    text2: Color(0xFF534A43),
    text3: Color(0xFF70665F),
    cloud: Color(0xFF6F665F),
    sand: Color(0xFF8C765F),
    wind: Color(0xFF3A8F67),
    heat: Color(0xFFDD5300),
    water: Color(0xFF1787C0),
    sun: Color(0xFFB67000),
    storm: Color(0xFF9752D6),
    snow: Color(0xFF628594),
    r0: Color(0xFFEDE6E2),
    r1: Color(0xFF7B8273),
    r2: Color(0xFF758562),
    r3: Color(0xFF6F884F),
    r4: Color(0xFF698A39),
    r5: Color(0xFF638C14),
    wind1: Color(0xFF75837B),
    wind2: Color(0xFF668775),
    wind3: Color(0xFF558B6E),
    wind4: Color(0xFF3E8E68),
    wind5: Color(0xFF189161),
    warnYellow: Color(0xFF9F7B00),
    warnOrange: Color(0xFFCB6200),
    warnRed: Color(0xFFE6425F),
  );

  @override
  OratgeColors copyWith() => this;

  @override
  OratgeColors lerp(ThemeExtension<OratgeColors>? other, double t) {
    if (other is! OratgeColors) return this;
    return OratgeColors(
      bg: Color.lerp(bg, other.bg, t)!,
      night: Color.lerp(night, other.night, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surface2: Color.lerp(surface2, other.surface2, t)!,
      line: Color.lerp(line, other.line, t)!,
      text: Color.lerp(text, other.text, t)!,
      text2: Color.lerp(text2, other.text2, t)!,
      text3: Color.lerp(text3, other.text3, t)!,
      cloud: Color.lerp(cloud, other.cloud, t)!,
      sand: Color.lerp(sand, other.sand, t)!,
      wind: Color.lerp(wind, other.wind, t)!,
      heat: Color.lerp(heat, other.heat, t)!,
      water: Color.lerp(water, other.water, t)!,
      sun: Color.lerp(sun, other.sun, t)!,
      storm: Color.lerp(storm, other.storm, t)!,
      snow: Color.lerp(snow, other.snow, t)!,
      r0: Color.lerp(r0, other.r0, t)!,
      r1: Color.lerp(r1, other.r1, t)!,
      r2: Color.lerp(r2, other.r2, t)!,
      r3: Color.lerp(r3, other.r3, t)!,
      r4: Color.lerp(r4, other.r4, t)!,
      r5: Color.lerp(r5, other.r5, t)!,
      wind1: Color.lerp(wind1, other.wind1, t)!,
      wind2: Color.lerp(wind2, other.wind2, t)!,
      wind3: Color.lerp(wind3, other.wind3, t)!,
      wind4: Color.lerp(wind4, other.wind4, t)!,
      wind5: Color.lerp(wind5, other.wind5, t)!,
      warnYellow: Color.lerp(warnYellow, other.warnYellow, t)!,
      warnOrange: Color.lerp(warnOrange, other.warnOrange, t)!,
      warnRed: Color.lerp(warnRed, other.warnRed, t)!,
    );
  }

  List<Color> get rating => [r1, r2, r3, r4, r5];
  List<Color> get windSpeed => [wind1, wind2, wind3, wind4, wind5];
}

/// Spacing scale (logical px).
abstract final class OgSpace {
  /// Step of the source's 4–24px spacing scale (4px); not referenced by the component stylesheet.
  static const double s1 = 4.0;
  /// Step of the source's 4–24px spacing scale (8px); not referenced by the component stylesheet.
  static const double s2 = 8.0;
  /// Tight card padding (og-card og-tight).
  static const double s3 = 12.0;
  /// Default card padding (og-card).
  static const double s4 = 16.0;
  /// Padding of a padded OratgeRoot (screen gutter).
  static const double s5 = 20.0;
  /// Step of the source's 4–24px spacing scale (24px); not referenced by the component stylesheet.
  static const double s6 = 24.0;
}

/// Corner radii.
abstract final class OgRadius {
  /// Cards (Card, og-card): rounded surfaces, no shadow.
  static const double card = 20.0;
  /// Smaller radius declared by the source; not referenced by the component stylesheet.
  static const double sm = 14.0;
}

/// Text styles. Colour comes from the theme (`context.og.text` etc.); these set size/weight/spacing only.
/// Font: DM Sans (weights 300–700). Bundle the TTF files (see HANDOFF.md) and use `fontFeatures: [FontFeature.tabularFigures()]` for numbers.
abstract final class OgText {
  static const _family = 'DMSans';
  static const _tnum = [FontFeature.tabularFigures()];
  /// The big temperature in CurrentConditions.
  static const heroTemp = TextStyle(fontFamily: _family, fontSize: 64.0, fontWeight: FontWeight.w300, fontFeatures: _tnum, height: 1.0, letterSpacing: -2.56);
  /// Key numbers: FactTile size="lg", one strip per screen, coloured by the quantity they measure.
  static const factValueLg = TextStyle(fontFamily: _family, fontSize: 36.0, fontWeight: FontWeight.w600, fontFeatures: _tnum, height: 1.05, letterSpacing: -0.72);
  /// The best window in VerdictCard.
  static const verdictBest = TextStyle(fontFamily: _family, fontSize: 24.0, fontWeight: FontWeight.w600, fontFeatures: _tnum, letterSpacing: -0.24);
  /// The value in FactTile.
  static const factValue = TextStyle(fontFamily: _family, fontSize: 24.0, fontWeight: FontWeight.w600, fontFeatures: _tnum, letterSpacing: -0.24);
  /// Base text set by OratgeRoot, with tabular figures.
  static const body = TextStyle(fontFamily: _family, fontSize: 14.0, fontWeight: FontWeight.w400, fontFeatures: _tnum, height: 1.4);
  /// Sport name in ActivityRow.
  static const actName = TextStyle(fontFamily: _family, fontSize: 14.0, fontWeight: FontWeight.w500, fontFeatures: _tnum);
  /// Time window in ActivityRow; WarningBanner title uses the same size and weight.
  static const actWindow = TextStyle(fontFamily: _family, fontSize: 15.0, fontWeight: FontWeight.w600, fontFeatures: _tnum);
  /// ForecastDayRow line.
  static const day = TextStyle(fontFamily: _family, fontSize: 13.0, fontWeight: FontWeight.w400, fontFeatures: _tnum);
  /// Reasoning under the verdict in VerdictCard.
  static const verdictSummary = TextStyle(fontFamily: _family, fontSize: 14.0, fontWeight: FontWeight.w400, fontFeatures: _tnum, height: 1.45);
  /// ChipGroup chips (600 when active); WarningBanner detail.
  static const chip = TextStyle(fontFamily: _family, fontSize: 12.0, fontWeight: FontWeight.w400, fontFeatures: _tnum);
  /// Reason line in ActivityRow.
  static const actWhy = TextStyle(fontFamily: _family, fontSize: 13.0, fontWeight: FontWeight.w400, fontFeatures: _tnum);
  /// Uppercase labels: SectionLabel and FactTile labels (set in uppercase).
  static const label = TextStyle(fontFamily: _family, fontSize: 12.0, fontWeight: FontWeight.w500, fontFeatures: _tnum, letterSpacing: 0.96);
  /// DataSources footnote.
  static const src = TextStyle(fontFamily: _family, fontSize: 12.0, fontWeight: FontWeight.w400, fontFeatures: _tnum, height: 1.5);
  /// Weekday under the date in DayTabs.
  static const tab = TextStyle(fontFamily: _family, fontSize: 11.0, fontWeight: FontWeight.w400, fontFeatures: _tnum);
}

/// Builds ThemeData for light or dark. Use with MaterialApp(themeMode: ThemeMode.system | light | dark).
ThemeData oratgeTheme(Brightness brightness) {
  final c = brightness == Brightness.dark ? OratgeColors.dark : OratgeColors.light;
  return ThemeData(
    brightness: brightness,
    useMaterial3: true,
    fontFamily: 'DMSans',
    scaffoldBackgroundColor: c.bg,
    colorScheme: ColorScheme(
      brightness: brightness,
      primary: c.text, onPrimary: c.bg,
      secondary: c.wind, onSecondary: c.bg,
      error: c.warnRed, onError: c.bg,
      surface: c.surface, onSurface: c.text,
      surfaceContainerHighest: c.surface2,
      outline: c.line, outlineVariant: c.line,
    ),
    dividerColor: c.line,
    textTheme: TextTheme(bodyMedium: OgText.body.copyWith(color: c.text)),
    extensions: [c],
  );
}

extension OratgeContext on BuildContext {
  OratgeColors get og => Theme.of(this).extension<OratgeColors>()!;
}
