import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../theme/oratge_tokens.dart';
import '../charts/chart_utils.dart';
import '../motion.dart';
import 'field.dart';

/// The rendered field image, stretched over the grid extent in map coordinates.
class FieldImageLayer extends StatelessWidget {
  const FieldImageLayer({super.key, required this.image, required this.nw, required this.se, this.opacity = 1});
  final ui.Image image;
  final LatLng nw, se;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final cam = MapCamera.of(context);
    return IgnorePointer(
      child: CustomPaint(
        size: Size.infinite,
        painter: _ImagePainter(image, cam.getOffsetFromOrigin(nw), cam.getOffsetFromOrigin(se), opacity),
      ),
    );
  }
}

class _ImagePainter extends CustomPainter {
  _ImagePainter(this.img, this.a, this.b, this.opacity);
  final ui.Image img;
  final Offset a, b;
  final double opacity;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawImageRect(
      img,
      Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
      Rect.fromPoints(a, b),
      Paint()
        ..filterQuality = FilterQuality.medium
        ..color = Color.fromRGBO(255, 255, 255, opacity),
    );
  }

  @override
  bool shouldRepaint(_ImagePainter o) => o.img != img || o.a != a || o.b != b || o.opacity != opacity;
}

class _Particle {
  _Particle(this.pos, this.age, this.life);
  LatLng pos;
  int age, life;
  final List<Offset> trail = [];
}

/// Wind made visible: light streaks drifting with the interpolated wind, faster where it blows harder.
class WindParticleLayer extends StatefulWidget {
  const WindParticleLayer({super.key, required this.sampler});
  final FieldSampler sampler;
  @override
  State<WindParticleLayer> createState() => _WindParticleLayerState();
}

class _WindParticleLayerState extends State<WindParticleLayer> with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker((_) => _step());
  final _rnd = math.Random(7);
  final List<_Particle> _ps = [];
  final _frame = ValueNotifier(0);
  MapCamera? _cam;
  (LatLng, double)? _lastView;

  @override
  void initState() {
    super.initState();
    _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _frame.dispose();
    super.dispose();
  }

  LatLng _spawn() {
    final s = widget.sampler;
    final vb = _cam?.visibleBounds;
    final south = math.max(s.se.latitude, vb?.south ?? s.se.latitude),
        north = math.min(s.nw.latitude, vb?.north ?? s.nw.latitude);
    final west = math.max(s.nw.longitude, vb?.west ?? s.nw.longitude),
        east = math.min(s.se.longitude, vb?.east ?? s.se.longitude);
    if (south >= north || west >= east) return LatLng(s.se.latitude + 1, s.nw.longitude + 1);
    return LatLng(south + _rnd.nextDouble() * (north - south), west + _rnd.nextDouble() * (east - west));
  }

  void _step() {
    final cam = _cam;
    if (cam == null) return;
    // The camera moved: old trails no longer line up, start them fresh.
    final view = (cam.center, cam.zoom);
    if (_lastView != view) {
      for (final p in _ps) {
        p.trail.clear();
      }
      _lastView = view;
    }
    final target = (cam.size.width * cam.size.height / 1100).clamp(150, 650).round();
    while (_ps.length < target) {
      _ps.add(_Particle(_spawn(), 0, 40 + _rnd.nextInt(60)));
    }
    if (_ps.length > target) _ps.removeRange(target, _ps.length);
    final s = widget.sampler;
    for (final p in _ps) {
      p.age++;
      final inside =
          p.pos.latitude <= s.nw.latitude &&
          p.pos.latitude >= s.se.latitude &&
          p.pos.longitude >= s.nw.longitude &&
          p.pos.longitude <= s.se.longitude;
      if (p.age > p.life || !inside) {
        p
          ..pos = _spawn()
          ..age = 0
          ..life = 40 + _rnd.nextInt(60);
        p.trail.clear();
        continue;
      }
      final (u, v) = s.wind(p.pos.latitude, p.pos.longitude);
      final o = cam.getOffsetFromOrigin(p.pos);
      final next = o + Offset(u, -v) * 0.09;
      p.pos = cam.unprojectAtZoom(next + cam.pixelOrigin);
      p.trail.add(next);
      if (p.trail.length > 9) p.trail.removeAt(0);
    }
    _frame.value++;
  }

  @override
  Widget build(BuildContext context) {
    _cam = MapCamera.of(context);
    final c = context.og;
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(size: Size.infinite, painter: _ParticlePainter(_ps, _frame, c.text)),
      ),
    );
  }
}

class _ParticlePainter extends CustomPainter {
  _ParticlePainter(this.ps, Listenable frame, this.color) : super(repaint: frame);
  final List<_Particle> ps;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.6;
    for (final p in ps) {
      final t = p.trail;
      final fade = p.age < 8 ? p.age / 8 : (p.life - p.age < 8 ? (p.life - p.age) / 8 : 1.0);
      for (var i = 1; i < t.length; i++) {
        paint.color = color.withValues(alpha: (i / t.length) * 0.75 * fade);
        canvas.drawLine(t[i - 1], t[i], paint);
      }
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter o) => false;
}

/// Falling rain streaks wherever the selected hour has rain, denser where it rains harder.
class RainLayer extends StatefulWidget {
  const RainLayer({super.key, required this.sampler});
  final FieldSampler sampler;
  @override
  State<RainLayer> createState() => _RainLayerState();
}

class _RainLayerState extends State<RainLayer> with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker((e) => _time.value = e.inMilliseconds / 1000);
  final _time = ValueNotifier(0.0);
  List<(LatLng, double, double)> _drops = const [];
  FieldSampler? _for;

  @override
  void initState() {
    super.initState();
    _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _time.dispose();
    super.dispose();
  }

  void _build() {
    final s = widget.sampler;
    final f = s.f;
    final rnd = math.Random(s.t);
    final drops = <(LatLng, double, double)>[];
    for (var r = 0; r < f.lats.length; r++) {
      for (var c = 0; c < f.lons.length; c++) {
        final mm = f.fields['precip']![s.t][r * f.lons.length + c];
        if (mm < 0.15) continue;
        final n = (mm * 10).clamp(3, 28).round();
        for (var k = 0; k < n; k++) {
          drops.add((
            LatLng(f.lats[r] + (rnd.nextDouble() - 0.5) * s.dLat, f.lons[c] + (rnd.nextDouble() - 0.5) * s.dLon),
            rnd.nextDouble(),
            mm,
          ));
        }
      }
    }
    _drops = drops;
    _for = s;
  }

  @override
  Widget build(BuildContext context) {
    if (_for?.t != widget.sampler.t || _for?.f != widget.sampler.f) _build();
    final cam = MapCamera.of(context);
    final c = context.og;
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(size: Size.infinite, painter: _RainPainter(_drops, cam, _time, c.water, reduceMotion(context))),
      ),
    );
  }
}

class _RainPainter extends CustomPainter {
  _RainPainter(this.drops, this.cam, this.time, this.color, this.still) : super(repaint: time);
  final List<(LatLng, double, double)> drops;
  final MapCamera cam;
  final ValueNotifier<double> time;
  final Color color;
  final bool still;
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    for (final (pos, phase, mm) in drops) {
      final o = cam.getOffsetFromOrigin(pos);
      final k = still ? phase : (phase + time.value * (0.9 + mm * 0.05)) % 1.0;
      final y = o.dy - 10 + k * 20;
      p.color = Color.lerp(color, Colors.white, 0.35)!.withValues(alpha: math.sin(k * math.pi) * 0.85);
      canvas.drawLine(Offset(o.dx + (1 - k) * 3, y), Offset(o.dx + (1 - k) * 3 - 2.5, y + 7), p);
    }
  }

  @override
  bool shouldRepaint(_RainPainter o) => o.drops != drops || o.cam != cam;
}

/// Values at the grid nodes once zoomed in enough to read them.
class ValueLabelsLayer extends StatelessWidget {
  const ValueLabelsLayer({super.key, required this.sampler, required this.layer});
  final FieldSampler sampler;
  final FieldLayer layer;

  @override
  Widget build(BuildContext context) {
    final cam = MapCamera.of(context);
    if (layer == FieldLayer.rating) return const SizedBox.shrink();
    // Always readable: every 3rd grid point when zoomed out, every 2nd in between, all of them up close.
    final step = cam.zoom < 7.4 ? 3 : (cam.zoom < 8.4 ? 2 : 1);
    final c = context.og;
    final f = sampler.f;
    final markers = <Marker>[];
    for (var r = 0; r < f.lats.length; r += step) {
      for (var col = 0; col < f.lons.length; col += step) {
        final i = r * f.lons.length + col;
        final field = f.fields;
        final text = switch (layer) {
          FieldLayer.wind => '${field['wind']![sampler.t][i].round()}',
          FieldLayer.temp => '${field['temp']![sampler.t][i].round()}°',
          FieldLayer.rain => field['precip']![sampler.t][i] >= 0.1 ? field['precip']![sampler.t][i].toStringAsFixed(1) : '',
          FieldLayer.chance => '${field['pprob']![sampler.t][i].round()}',
          FieldLayer.thunder =>
            (field['storm']?[sampler.t][i] ?? 0) >= 15 ? '${field['storm']![sampler.t][i].round()}' : '',
          FieldLayer.rating => '',
        };
        if (text.isEmpty) continue;
        markers.add(
          Marker(
            point: LatLng(f.lats[r], f.lons[col]),
            width: 46,
            height: 40,
            child: IgnorePointer(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (layer == FieldLayer.wind)
                    CustomPaint(size: const Size(18, 18), painter: _MiniArrow(field['wdir']![sampler.t][i], c.text)),
                  Text(
                    text,
                    style: OgText.chip.copyWith(
                      color: c.text,
                      fontWeight: FontWeight.w700,
                      shadows: [
                        Shadow(color: c.bg, blurRadius: 4),
                        Shadow(color: c.bg, blurRadius: 8),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    }
    return MarkerLayer(markers: markers);
  }
}

class _MiniArrow extends CustomPainter {
  _MiniArrow(this.from, this.color);
  final double from;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) =>
      windArrow(canvas, Offset(size.width / 2, size.height / 2), from, color, len: 7, width: 2);
  @override
  bool shouldRepaint(_MiniArrow o) => o.from != from || o.color != color;
}
