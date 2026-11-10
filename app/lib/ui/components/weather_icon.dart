import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:path_drawing/path_drawing.dart';

import '../../theme/oratge_tokens.dart';

/// Weather glyph kinds (WeatherIcon.d.ts).
enum WeatherKind { sun, partly, cloud, rain, storm, bolt, wind, wave, heat, snow, uv, night, fog }

WeatherKind weatherKindFrom(String s) =>
    WeatherKind.values.firstWhere((k) => k.name == s, orElse: () => WeatherKind.cloud);

/// Weather glyph with the accent that matches its meaning. Ported from the React SVG (24×24 viewBox).
class OgWeatherIcon extends StatelessWidget {
  const OgWeatherIcon(this.kind, {super.key, this.size = 24});
  final WeatherKind kind;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: kind.name,
      child: CustomPaint(size: Size.square(size), painter: WeatherIconPainter(kind, context.og)),
    );
  }
}

class WeatherIconPainter extends CustomPainter {
  WeatherIconPainter(this.kind, this.c);
  final WeatherKind kind;
  final OratgeColors c;

  static final _cloud = parseSvgPathData('M7 18h10a4 4 0 0 0 .4-8 5.5 5.5 0 0 0-10.6 1.5A3.3 3.3 0 0 0 7 18z');
  static final _cloudSmall = parseSvgPathData('M8 20h9.5a3.6 3.6 0 0 0 .3-7.2 5 5 0 0 0-9.6 1.4A3 3 0 0 0 8 20z');
  static final _windP = parseSvgPathData('M3 9h11a3 3 0 1 0-3-3M3 13h15a3 3 0 1 1-3 3M3 17h7');
  static final _waveP = parseSvgPathData(
      'M2 12c2.5 0 2.5-2.2 5-2.2s2.5 2.2 5 2.2 2.5-2.2 5-2.2 2.5 2.2 5 2.2M2 17c2.5 0 2.5-2.2 5-2.2s2.5 2.2 5 2.2 2.5-2.2 5-2.2 2.5 2.2 5 2.2');
  static final _bolt = parseSvgPathData('M13 2L5 14h6l-1 8 8-12h-6z');
  static final _stormBolt = parseSvgPathData('M12.5 15l-2.5 4h3l-2 4');
  static final _thermo = parseSvgPathData('M10 4a2 2 0 0 1 4 0v10.6a4.2 4.2 0 1 1-4 0z');
  static final _moon = parseSvgPathData('M19 14.5A7.5 7.5 0 0 1 9.5 5a7.5 7.5 0 1 0 9.5 9.5z');

  Paint _stroke(Color col, [double w = 1.7]) => Paint()
    ..color = col
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  Paint _fill(Color col) => Paint()..color = col;

  void _sun(Canvas canvas, double cx, double cy, double r) {
    canvas.drawCircle(Offset(cx, cy), r, _fill(c.sun));
    final p = _stroke(c.sun, 1.6);
    for (var a = 0; a < 360; a += 45) {
      final q = a * math.pi / 180;
      canvas.drawLine(Offset(cx + math.cos(q) * (r + 2.2), cy + math.sin(q) * (r + 2.2)),
          Offset(cx + math.cos(q) * (r + 4), cy + math.sin(q) * (r + 4)), p);
    }
  }

  void _cloudAt(Canvas canvas, {double dy = 0}) {
    canvas.save();
    canvas.translate(0, dy);
    canvas.drawPath(_cloud, _stroke(c.cloud));
    canvas.restore();
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24, size.height / 24);
    switch (kind) {
      case WeatherKind.sun:
        _sun(canvas, 12, 12, 4.2);
      case WeatherKind.partly:
        _sun(canvas, 9, 9, 3.4);
        canvas.drawPath(_cloudSmall, _fill(c.bg));
        canvas.drawPath(_cloudSmall, _stroke(c.cloud));
      case WeatherKind.cloud:
        _cloudAt(canvas);
      case WeatherKind.fog:
        _cloudAt(canvas, dy: -3);
        for (final y in [17.0, 20.0]) {
          canvas.drawLine(Offset(5, y), Offset(19, y), _stroke(c.cloud, 1.6));
        }
      case WeatherKind.rain:
        _cloudAt(canvas, dy: -3);
        for (final x in [7.0, 11.0, 15.0]) {
          canvas.drawLine(Offset(x, 18), Offset(x - 1.2, 21.5), _stroke(c.water, 1.8));
        }
      case WeatherKind.storm:
        _cloudAt(canvas, dy: -3);
        canvas.drawPath(_stormBolt, _stroke(c.storm, 1.8));
      case WeatherKind.bolt:
        canvas.drawPath(_bolt, _fill(c.storm));
      case WeatherKind.wind:
        canvas.drawPath(_windP, _stroke(c.wind));
      case WeatherKind.wave:
        canvas.drawPath(_waveP, _stroke(c.water));
      case WeatherKind.heat:
        canvas.drawLine(const Offset(12, 4), const Offset(12, 14.5), _stroke(c.heat));
        canvas.drawCircle(const Offset(12, 17.5), 3, _fill(c.heat));
        canvas.drawPath(_thermo, _stroke(c.text2));
      case WeatherKind.snow:
        for (final a in [0.0, 60.0, 120.0]) {
          canvas.save();
          canvas.translate(12, 12);
          canvas.rotate(a * math.pi / 180);
          canvas.drawLine(const Offset(0, -8), const Offset(0, 8), _stroke(c.snow));
          canvas.restore();
        }
      case WeatherKind.uv:
        _sun(canvas, 12, 10, 3.2);
        final tp = TextPainter(
          text: TextSpan(
              text: 'UV',
              style: TextStyle(fontFamily: 'DMSans', fontSize: 6, fontWeight: FontWeight.w700, color: c.sun)),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(12 - tp.width / 2, 17.2));
      case WeatherKind.night:
        canvas.drawPath(_moon, _fill(c.cloud));
    }
  }

  @override
  bool shouldRepaint(WeatherIconPainter old) => old.kind != kind || old.c != c;
}

/// Weather glyph from its name in the data contract ("partly", "rain", …).
class OgWeatherIconFromName extends StatelessWidget {
  const OgWeatherIconFromName(this.name, {super.key, this.size = 24});
  final String name;
  final double size;
  @override
  Widget build(BuildContext context) => OgWeatherIcon(weatherKindFrom(name), size: size);
}
