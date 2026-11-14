import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../data/models.dart';
import '../../theme/og_helpers.dart';
import '../../theme/oratge_tokens.dart';

/// Map layers.
enum FieldLayer { wind, temp, rain, chance, thunder, rating }

extension FieldLayerX on FieldLayer {
  String get label => switch (this) {
    FieldLayer.wind => 'Wind',
    FieldLayer.temp => 'Temp',
    FieldLayer.rain => 'Rain',
    FieldLayer.chance => 'Rain chance',
    FieldLayer.thunder => 'Thunder',
    FieldLayer.rating => 'Spots',
  };
}

/// Bilinear sampling of the forecast grid at one time step.
class FieldSampler {
  FieldSampler(this.f, this.t);
  final MapForecast f;
  final int t;

  double get south => f.lats.first;
  double get north => f.lats.last;
  double get west => f.lons.first;
  double get east => f.lons.last;
  double get dLat => f.lats[1] - f.lats[0];
  double get dLon => f.lons[1] - f.lons[0];

  /// Grid extent incl. half a cell around the outer nodes.
  LatLng get nw => LatLng(north + dLat / 2, west - dLon / 2);
  LatLng get se => LatLng(south - dLat / 2, east + dLon / 2);

  double _v(String name, int r, int c) => f.fields[name]![t][r * f.lons.length + c];

  /// Value at a coordinate (clamped to the grid edge).
  double sample(String name, double lat, double lon) {
    final rf = ((lat - south) / dLat).clamp(0.0, f.lats.length - 1.0);
    final cf = ((lon - west) / dLon).clamp(0.0, f.lons.length - 1.0);
    final r0 = rf.floor(), c0 = cf.floor();
    final r1 = math.min(r0 + 1, f.lats.length - 1), c1 = math.min(c0 + 1, f.lons.length - 1);
    final fr = rf - r0, fc = cf - c0;
    final a = _v(name, r0, c0) * (1 - fc) + _v(name, r0, c1) * fc;
    final b = _v(name, r1, c0) * (1 - fc) + _v(name, r1, c1) * fc;
    return a * (1 - fr) + b * fr;
  }

  /// Wind as (u east, v north) in kn, interpolated component-wise (no direction wrap issues).
  (double, double) wind(double lat, double lon) {
    double comp(int r, int c, bool u) {
      final sp = _v('wind', r, c), dir = _v('wdir', r, c) * math.pi / 180;
      // Direction is where the wind comes FROM; motion is the opposite.
      return u ? -sp * math.sin(dir) : -sp * math.cos(dir);
    }

    final rf = ((lat - south) / dLat).clamp(0.0, f.lats.length - 1.0);
    final cf = ((lon - west) / dLon).clamp(0.0, f.lons.length - 1.0);
    final r0 = rf.floor(), c0 = cf.floor();
    final r1 = math.min(r0 + 1, f.lats.length - 1), c1 = math.min(c0 + 1, f.lons.length - 1);
    final fr = rf - r0, fc = cf - c0;
    double bil(bool u) {
      final a = comp(r0, c0, u) * (1 - fc) + comp(r0, c1, u) * fc;
      final b = comp(r1, c0, u) * (1 - fc) + comp(r1, c1, u) * fc;
      return a * (1 - fr) + b * fr;
    }

    return (bil(true), bil(false));
  }
}

/// Colour scales (theme-aware, one meaning per hue; alpha encodes "nothing here").
class FieldColors {
  FieldColors(this.c);
  final OratgeColors c;

  static Color _ramp(List<(double, Color)> stops, double v) {
    if (v <= stops.first.$1) return stops.first.$2;
    for (var i = 1; i < stops.length; i++) {
      if (v <= stops[i].$1) {
        final (a, ca) = stops[i - 1];
        final (b, cb) = stops[i];
        return Color.lerp(ca, cb, (v - a) / (b - a))!;
      }
    }
    return stops.last.$2;
  }

  Color wind(double kn) => _ramp([
    (0, c.wind1.withValues(alpha: 0.05)),
    (6, c.wind2.withValues(alpha: 0.35)),
    (12, c.wind3.withValues(alpha: 0.5)),
    (18, c.wind4.withValues(alpha: 0.6)),
    (25, c.wind5.withValues(alpha: 0.7)),
    (35, c.storm.withValues(alpha: 0.75)),
  ], kn);

  Color temp(double t) => _ramp([
    (-6, c.storm.withValues(alpha: 0.55)),
    (0, c.snow.withValues(alpha: 0.55)),
    (10, c.wind3.withValues(alpha: 0.45)),
    (18, c.sun.withValues(alpha: 0.5)),
    (26, c.heat.withValues(alpha: 0.55)),
    (35, c.warnRed.withValues(alpha: 0.6)),
  ], t);

  /// Radar style: transparent when dry, blue → violet for heavy rain.
  Color rain(double mm) => mm < 0.1
      ? const Color(0x00000000)
      : _ramp([
          (0.1, c.water.withValues(alpha: 0.25)),
          (1, c.water.withValues(alpha: 0.55)),
          (4, Color.lerp(c.water, c.storm, 0.5)!.withValues(alpha: 0.7)),
          (10, c.storm.withValues(alpha: 0.8)),
        ], mm);

  Color chance(double pct) => pct < 10 ? const Color(0x00000000) : c.water.withValues(alpha: (pct / 100) * 0.65);

  /// Thunderstorm risk %: nothing below 15 %, then yellow → storm violet.
  Color thunder(double pct) => pct < 15
      ? const Color(0x00000000)
      : _ramp([
          (15, c.sun.withValues(alpha: 0.25)),
          (30, c.sun.withValues(alpha: 0.5)),
          (50, Color.lerp(c.sun, c.storm, 0.6)!.withValues(alpha: 0.65)),
          (80, c.storm.withValues(alpha: 0.8)),
        ], pct);

  Color forLayer(FieldLayer l, FieldSampler s, double lat, double lon) => switch (l) {
    FieldLayer.wind => wind(s.sample('wind', lat, lon)),
    FieldLayer.temp => temp(s.sample('temp', lat, lon)),
    FieldLayer.rain => rain(s.sample('precip', lat, lon)),
    FieldLayer.chance => chance(s.sample('pprob', lat, lon)),
    FieldLayer.thunder => s.f.fields.containsKey('storm') ? thunder(s.sample('storm', lat, lon)) : const Color(0x00000000),
    FieldLayer.rating => const Color(0x00000000),
  };

  /// Legend stops (value label, colour) for a layer.
  List<(String, Color)> legend(FieldLayer l) => switch (l) {
    FieldLayer.wind => [
      for (final k in [0, 6, 12, 18, 25, 35]) ('$k', wind(k.toDouble()).withValues(alpha: 1)),
    ],
    FieldLayer.temp => [
      for (final t in [-5, 0, 10, 18, 26, 35]) ('$t°', temp(t.toDouble()).withValues(alpha: 1)),
    ],
    FieldLayer.rain => [
      for (final m in [0.1, 1.0, 4.0, 10.0]) (m < 1 ? '$m' : '${m.round()}', rain(m).withValues(alpha: 1)),
    ],
    FieldLayer.chance => [
      for (final p in [20, 50, 80, 100]) ('$p', chance(p.toDouble()).withValues(alpha: 1)),
    ],
    FieldLayer.thunder => [
      for (final p in [15, 30, 50, 80]) ('$p', thunder(p.toDouble()).withValues(alpha: 1)),
    ],
    FieldLayer.rating => [for (var r = 1; r <= 5; r++) ('$r', c.ratingColor(r))],
  };

  String unit(FieldLayer l) => switch (l) {
    FieldLayer.wind => 'kn',
    FieldLayer.temp => '',
    FieldLayer.rain => 'mm/h',
    FieldLayer.chance => '%',
    FieldLayer.thunder => '% storm risk · ⚡ strikes, last 2 h',
    FieldLayer.rating => '',
  };
}

double _mercY(double lat) => math.log(math.tan(math.pi / 4 + lat * math.pi / 360));
double _invMercY(double y) => (2 * math.atan(math.exp(y)) - math.pi / 2) * 180 / math.pi;

/// Renders the field to an RGBA image laid out in Mercator rows, so it lines up with the tiles.
Future<ui.Image> renderField(FieldSampler s, FieldLayer layer, FieldColors colors, {int width = 220, int height = 170}) {
  final px = Uint8List(width * height * 4);
  final yTop = _mercY(s.nw.latitude), yBot = _mercY(s.se.latitude);
  for (var y = 0; y < height; y++) {
    final lat = _invMercY(yTop + (yBot - yTop) * (y + 0.5) / height);
    for (var x = 0; x < width; x++) {
      final lon = s.nw.longitude + (s.se.longitude - s.nw.longitude) * (x + 0.5) / width;
      final col = colors.forLayer(layer, s, lat, lon);
      final i = (y * width + x) * 4;
      // Feather the outer edge so the field blends into the base map instead of ending in a hard box.
      final edge = math.min(
        math.min(x + 0.5, width - x - 0.5) / (width * 0.025),
        math.min(y + 0.5, height - y - 0.5) / (height * 0.025),
      );
      final a = col.a * edge.clamp(0.0, 1.0);
      // The engine reads raw rgba8888 as premultiplied alpha: scale the colour by alpha, or it renders opaque.
      px[i] = (col.r * a * 255).round();
      px[i + 1] = (col.g * a * 255).round();
      px[i + 2] = (col.b * a * 255).round();
      px[i + 3] = (a * 255).round();
    }
  }
  final done = Completer<ui.Image>();
  ui.decodeImageFromPixels(px, width, height, ui.PixelFormat.rgba8888, done.complete);
  return done.future;
}
