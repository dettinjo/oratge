import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'oratge_tokens.dart';

/// One meaning per hue (design-system README): wind, heat, water, sun, storm, snow.
enum OgAccent { wind, heat, water, sun, storm, snow, neutral }

OgAccent? accentFromString(String? s) {
  switch (s) {
    case 'wind':
      return OgAccent.wind;
    case 'heat':
      return OgAccent.heat;
    case 'water':
      return OgAccent.water;
    case 'sun':
      return OgAccent.sun;
    case 'storm':
      return OgAccent.storm;
    case 'snow':
      return OgAccent.snow;
    case 'neutral':
      return OgAccent.neutral;
  }
  return null;
}

extension OgColorHelpers on OratgeColors {
  Color accent(OgAccent a) {
    switch (a) {
      case OgAccent.wind:
        return wind;
      case OgAccent.heat:
        return heat;
      case OgAccent.water:
        return water;
      case OgAccent.sun:
        return sun;
      case OgAccent.storm:
        return storm;
      case OgAccent.snow:
        return snow;
      case OgAccent.neutral:
        return text2;
    }
  }

  /// Rating 1–5 on the green ramp; 0 = empty cell.
  Color ratingColor(num r) {
    final v = r.round();
    if (v < 1) return r0;
    return rating[v.clamp(1, 5) - 1];
  }

  /// Wind-speed band (kn): <8, 8, 11, 14, 17+.
  Color windColor(num kn) => windSpeed[kn < 8
      ? 0
      : kn < 11
          ? 1
          : kn < 14
              ? 2
              : kn < 17
                  ? 3
                  : 4];

  Color warningColor(String level) =>
      level == 'red' ? warnRed : (level == 'orange' ? warnOrange : warnYellow);
}

const ratingWords = ['Poor', 'Marginal', 'Fair', 'Good', 'Epic'];

/// Draws text on a canvas. `align`: 0 = start, 0.5 = centre, 1 = end (anchor at x).
void ogText(
  Canvas canvas,
  String text,
  double x,
  double baselineY, {
  required Color color,
  double size = 12,
  FontWeight weight = FontWeight.w400,
  double align = 0,
}) {
  final tp = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        fontFamily: 'DMSans',
        fontSize: size,
        fontWeight: weight,
        color: color,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  final baseline = tp.computeDistanceToActualBaseline(TextBaseline.alphabetic);
  tp.paint(canvas, Offset(x - tp.width * align, baselineY - baseline));
}

double ogTextWidth(String text, {double size = 12, FontWeight weight = FontWeight.w400}) {
  final tp = TextPainter(
    text: TextSpan(text: text, style: TextStyle(fontFamily: 'DMSans', fontSize: size, fontWeight: weight)),
    textDirection: TextDirection.ltr,
  )..layout();
  return tp.width;
}

/// Polar → cartesian, 0° = north, clockwise (matches the React `polar`).
Offset polar(double cx, double cy, double r, double deg) {
  final q = deg * math.pi / 180;
  return Offset(cx + r * math.sin(q), cy - r * math.cos(q));
}
