import 'dart:math' as math;

import 'package:flutter/material.dart';

Paint strokePaint(Color c, [double w = 2]) => Paint()
  ..color = c
  ..strokeWidth = w
  ..style = PaintingStyle.stroke
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round;

Paint fillPaint(Color c) => Paint()..color = c;

Path polyline(List<Offset> pts) => Path()..addPolygon(pts, false);

void dashedPolyline(Canvas canvas, List<Offset> pts, Paint p, {double dash = 3, double gap = 3}) {
  for (var i = 0; i < pts.length - 1; i++) {
    final a = pts[i], b = pts[i + 1];
    final d = (b - a).distance;
    if (d == 0) continue;
    final dir = (b - a) / d;
    for (var t = 0.0; t < d; t += dash + gap) {
      canvas.drawLine(a + dir * t, a + dir * math.min(t + dash, d), p);
    }
  }
}

void dashedLine(Canvas canvas, Offset a, Offset b, Paint p, {double dash = 2, double gap = 3}) =>
    dashedPolyline(canvas, [a, b], p, dash: dash, gap: gap);

void dashedPath(Canvas canvas, Path path, Paint p, {double dash = 2, double gap = 3}) {
  for (final m in path.computeMetrics()) {
    for (var t = 0.0; t < m.length; t += dash + gap) {
      canvas.drawPath(m.extractPath(t, t + dash), p);
    }
  }
}

void hatchRect(Canvas canvas, Rect r, Color col) {
  canvas.save();
  canvas.clipRect(r);
  final p = Paint()
    ..color = col
    ..strokeWidth = 1.4;
  for (var x = r.left - r.height; x < r.right; x += 5) {
    canvas.drawLine(Offset(x, r.bottom), Offset(x + r.height, r.top), p);
  }
  canvas.restore();
}

/// Arrow pointing downwind for a wind/swell coming FROM `from` degrees.
void windArrow(Canvas canvas, Offset at, double from, Color col, {double len = 6, double width = 1.7}) {
  canvas.save();
  canvas.translate(at.dx, at.dy);
  canvas.rotate((from + 180) * math.pi / 180);
  final p = strokePaint(col, width);
  canvas.drawLine(Offset(0, -len), Offset(0, len), p);
  canvas.drawPath(Path()
    ..moveTo(-len * 0.5, len - len * 0.55)
    ..lineTo(0, len)
    ..lineTo(len * 0.5, len - len * 0.55), p);
  canvas.restore();
}

/// Band between an upper series and a lower series.
Path bandPath(List<Offset> upper, List<Offset> lower) => Path()..addPolygon([...upper, ...lower.reversed], true);

const _compass = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];

/// Eight-point compass name for a direction in degrees.
String compassName(double deg) => _compass[(((deg % 360) + 22.5) ~/ 45) % 8];
