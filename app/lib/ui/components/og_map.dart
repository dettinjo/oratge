import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../data/models.dart';
import '../../theme/og_helpers.dart';
import '../../theme/oratge_tokens.dart';
import '../charts/chart_utils.dart';

/// OSM tiles toned to the theme (desaturated; inverted and warmed in dark).
Widget oratgeTiles(BuildContext context) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  return ColorFiltered(
    colorFilter: ColorFilter.matrix(dark ? _darkMatrix : _lightMatrix),
    child: TileLayer(
      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      userAgentPackageName: 'cat.oratge.oratge',
      maxNativeZoom: 16,
    ),
  );
}

/// True under `flutter test` (no network tiles there).
bool get _inTest => !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');

/// Real map of Catalonia (CARTO basemap, theme-matched) with spot pins: wind arrows or rating dots.
class OgSpotMap extends StatelessWidget {
  const OgSpotMap({super.key, required this.pins, required this.layer, this.fallback, this.onTap});

  /// Preview mode: no gestures, a tap opens the full map.
  final VoidCallback? onTap;
  final List<MapPin> pins;
  final String layer;

  /// Shown when tiles can't be used (tests, missing coordinates).
  final Widget? fallback;

  @override
  Widget build(BuildContext context) {
    if (_inTest || pins.any((p) => p.lat == null)) return fallback ?? const SizedBox.shrink();
    final c = context.og;
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: FlutterMap(
        options: MapOptions(
          initialCenter: const LatLng(41.75, 1.85),
          initialZoom: 7.4,
          minZoom: 6,
          maxZoom: 13,
          backgroundColor: c.bg,
          interactionOptions: InteractionOptions(
              flags: onTap != null ? InteractiveFlag.none : InteractiveFlag.all & ~InteractiveFlag.rotate),
          onTap: onTap == null ? null : (_, _) => onTap!(),
        ),
        children: [
          oratgeTiles(context),
          MarkerLayer(markers: [
            for (final p in pins)
              Marker(
                point: LatLng(p.lat!, p.lon!),
                width: 120,
                height: 52,
                child: Semantics(
                  label: '${p.name}: rating ${p.rating} of 5, wind ${p.wind.round()} knots',
                  child: Column(children: [
                    if (layer == 'Wind')
                      CustomPaint(size: const Size(28, 28), painter: _Arrow(c, p))
                    else
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                            color: c.ratingColor(p.rating), shape: BoxShape.circle, border: Border.all(color: c.bg, width: 2)),
                        child: Center(
                            child: Text('${p.rating}', style: OgText.chip.copyWith(color: c.bg, fontWeight: FontWeight.w700))),
                      ),
                    Text(p.name.split(' · ').first,
                        style: OgText.chip.copyWith(color: c.text, fontWeight: FontWeight.w600, shadows: [
                          Shadow(color: c.bg, blurRadius: 3),
                          Shadow(color: c.bg, blurRadius: 6),
                        ])),
                  ]),
                ),
              ),
          ]),
          const SimpleAttributionWidget(source: Text('OpenStreetMap contributors')),
        ],
      ),
    );
  }
}

class _Arrow extends CustomPainter {
  _Arrow(this.c, this.p);
  final OratgeColors c;
  final MapPin p;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawCircle(Offset(size.width / 2, size.height / 2), 14, Paint()..color = c.bg.withValues(alpha: 0.75));
    windArrow(canvas, Offset(size.width / 2, size.height / 2), p.windFrom.toDouble(), c.windColor(p.wind), len: 10, width: 2.6);
  }

  @override
  bool shouldRepaint(_Arrow o) => o.p != p || o.c != c;
}

// Greyscale with a warm tint (light) / inverted greyscale, dimmed and warmed (dark).
const _lightMatrix = <double>[
  0.25, 0.60, 0.15, 0, 18, //
  0.24, 0.58, 0.14, 0, 12,
  0.22, 0.54, 0.13, 0, 6,
  0, 0, 0, 1, 0,
];
const _darkMatrix = <double>[
  // out = offset − 0.58 × luminance: light land (≈240) → ≈40, grey map text (≈120) → ≈110.
  -0.12, -0.35, -0.11, 0, 181, //
  -0.12, -0.35, -0.11, 0, 172,
  -0.12, -0.35, -0.11, 0, 164,
  0, 0, 0, 1, 0,
];
