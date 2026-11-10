import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/og_helpers.dart';
import '../../theme/oratge_tokens.dart';
import '../components/weather_icon.dart';
import 'chart_utils.dart';

export 'hour_chart.dart';

/// Wraps a painter with full-width layout and an accessibility label.
class _Chart extends StatelessWidget {
  const _Chart({required this.height, required this.label, required this.builder, this.width});
  final double height;
  final double? width;
  final String label;
  final CustomPainter Function(OratgeColors c) builder;

  @override
  Widget build(BuildContext context) => Semantics(
        label: label,
        excludeSemantics: true,
        child: LayoutBuilder(
          builder: (context, box) => CustomPaint(
            size: Size(width ?? box.maxWidth, height),
            painter: builder(context.og),
          ),
        ),
      );
}

String _hh(int h) => '${(h % 24).toString().padLeft(2, '0')} h';

// ───────────────────────────── WindBand ─────────────────────────────
class OgWindBand extends StatelessWidget {
  const OgWindBand(
      {super.key,
      required this.mean,
      required this.gust,
      this.directions,
      this.range,
      this.days = const [],
      this.night = const [],
      this.best,
      this.max = 35,
      this.semanticLabel});
  final List<num> mean, gust;
  final List<num>? directions;
  final List<num>? range;
  final List<String> days;
  final List<List<num>> night;
  final List<num>? best;
  final double max;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) => _Chart(
      height: 190, label: semanticLabel ?? 'Wind and gusts, next days', builder: (c) => _WindBandPainter(this, c));
}

class _WindBandPainter extends CustomPainter {
  _WindBandPainter(this.w, this.c);
  final OgWindBand w;
  final OratgeColors c;
  @override
  void paint(Canvas canvas, Size s) {
    const top = 24.0;
    final bot = s.height - 36, n = w.mean.length;
    double x(num i) => 4 + i * (s.width - 30) / (n - 1);
    double y(num k) => bot - k / w.max * (bot - top);
    for (final nr in w.night) {
      canvas.drawRect(Rect.fromLTRB(x(nr[0]), top, x(math.min(nr[1], n - 1)), bot), fillPaint(c.night));
    }
    if (w.range != null) hatchRect(canvas, Rect.fromLTRB(x(0), y(w.range![1]), x(n - 1), y(w.range![0])), c.line);
    for (final k in [0, 10, 20, 30]) {
      if (k > w.max) continue;
      canvas.drawLine(Offset(x(0), y(k)), Offset(x(n - 1), y(k)), strokePaint(c.line, k == 0 ? 1 : 0.6));
      ogText(canvas, '$k', s.width, y(k) + 4, color: c.text2, align: 1);
    }
    ogText(canvas, 'kn', s.width, top - 6, color: c.text2, align: 1);
    final mp = [for (var i = 0; i < n; i++) Offset(x(i), y(w.mean[i]))];
    final gp = [for (var i = 0; i < n; i++) Offset(x(i), y(w.gust[i]))];
    canvas.drawPath(bandPath(gp, mp), fillPaint(c.wind.withValues(alpha: 0.28)));
    canvas.drawPath(polyline(mp), strokePaint(c.wind));
    if (w.best != null) {
      final r = RRect.fromRectAndRadius(Rect.fromLTRB(x(w.best![0]), top - 2, x(w.best![1]), bot), const Radius.circular(4));
      dashedPath(canvas, Path()..addRRect(r), strokePaint(c.text, 1));
      ogText(canvas, 'best', (x(w.best![0]) + x(w.best![1])) / 2, bot + 32, color: c.text, align: 0.5);
    }
    if (w.directions != null) {
      for (var i = 2; i < n; i += 6) {
        windArrow(canvas, Offset(x(i), 10), w.directions![i].toDouble(), c.text2);
      }
    }
    for (var k = 0; k < w.days.length; k++) {
      ogText(canvas, w.days[k], x(math.min(k * 24 + 12, n - 1)), bot + 17, color: c.text2, weight: FontWeight.w500, align: 0.5);
      if (k > 0) canvas.drawLine(Offset(x(k * 24), top), Offset(x(k * 24), bot + 6), strokePaint(c.line, 1));
    }
  }

  @override
  bool shouldRepaint(_WindBandPainter o) => o.w != w || o.c != c;
}

// ───────────────────────────── WaveBars ─────────────────────────────
class OgWaveBars extends StatelessWidget {
  const OgWaveBars(
      {super.key,
      required this.heights,
      required this.periods,
      this.windFrom,
      this.days = const [],
      this.best = const [],
      this.max = 1.6,
      this.semanticLabel});
  final List<num> heights, periods;
  final List<num>? windFrom;
  final List<String> days;
  final List<int> best;
  final double max;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) =>
      _Chart(height: 220, label: semanticLabel ?? 'Wave height and period', builder: (c) => _WaveBarsPainter(this, c));
}

class _WaveBarsPainter extends CustomPainter {
  _WaveBarsPainter(this.w, this.c);
  final OgWaveBars w;
  final OratgeColors c;
  @override
  void paint(Canvas canvas, Size s) {
    const top = 30.0, bot = 152.0;
    final n = w.heights.length, bw = (s.width - 30) / n;
    double x(num i) => 4 + i * bw;
    double y(num v) => bot - v / w.max * (bot - top);
    final per = w.days.isEmpty ? n.toDouble() : n / w.days.length;
    ogText(canvas, 'm', 0, 14, color: c.text2);
    for (final k in [0.5, 1.0, 1.5]) {
      if (k > w.max) continue;
      canvas.drawLine(Offset(0, y(k)), Offset(s.width - 24, y(k)), strokePaint(c.line, 0.6));
      ogText(canvas, '$k', s.width, y(k) + 4, color: c.text2, align: 1);
    }
    canvas.drawLine(Offset(0, bot), Offset(s.width - 24, bot), strokePaint(c.line, 1));
    for (var i = 0; i < n; i++) {
      final hi = w.best.contains(i) || w.best.isEmpty;
      canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTRB(x(i) + 1, y(w.heights[i]), x(i) + bw - 1, bot), const Radius.circular(3)),
          fillPaint(c.water.withValues(alpha: hi ? 1 : 0.55)));
      if (i % 3 == 0) {
        ogText(canvas, '${w.periods[i].round()}s', x(i) + bw / 2, y(w.heights[i]) - 5,
            color: w.best.contains(i) ? c.text : c.text2, weight: w.best.contains(i) ? FontWeight.w700 : FontWeight.w400, align: 0.5);
      }
      if (w.windFrom != null && i % 2 == 1) windArrow(canvas, Offset(x(i), bot + 16), w.windFrom![i].toDouble(), c.wind, len: 5);
    }
    for (var k = 0; k < w.days.length; k++) {
      ogText(canvas, w.days[k], x(k * per + per / 2), bot + 44, color: c.text2, weight: FontWeight.w500, align: 0.5);
      if (k > 0) canvas.drawLine(Offset(x(k * per), top - 10), Offset(x(k * per), bot + 28), strokePaint(c.line, 1));
    }
  }

  @override
  bool shouldRepaint(_WaveBarsPainter o) => o.w != w || o.c != c;
}

// ───────────────────────────── WindCompass ─────────────────────────────
class OgWindCompass extends StatelessWidget {
  const OgWindCompass(
      {super.key, required this.from, required this.speed, required this.shoreFacing, this.caption, this.size = 140});
  final num from, speed, shoreFacing;
  final String? caption;
  final double size;

  @override
  Widget build(BuildContext context) => _Chart(
      width: size,
      height: size + (caption != null ? 18 : 0),
      label: 'Wind from ${from.round()} degrees, ${speed.round()} knots${caption != null ? ', $caption' : ''}',
      builder: (c) => _CompassPainter(this, c));
}

class _CompassPainter extends CustomPainter {
  _CompassPainter(this.w, this.c);
  final OgWindCompass w;
  final OratgeColors c;
  @override
  void paint(Canvas canvas, Size s) {
    final cc = w.size / 2, r = cc - 13;
    final ctr = Offset(cc, cc);
    void sector(double a0, double sweep, Color col) {
      canvas.drawArc(Rect.fromCircle(center: ctr, radius: r), (a0 - 90) * math.pi / 180, sweep * math.pi / 180, true,
          fillPaint(col));
    }

    final sf = w.shoreFacing.toDouble();
    sector(sf + 90, 180, c.text.withValues(alpha: 0.04));
    sector(sf - 90, 180, c.wind.withValues(alpha: 0.12));
    canvas.drawCircle(ctr, r, strokePaint(c.line, 1));
    for (var k = 0; k < 12; k++) {
      canvas.drawLine(polar(cc, cc, r - 4, k * 30.0), polar(cc, cc, r, k * 30.0), strokePaint(c.text3, 1));
    }
    for (final e in const [('N', 0.0), ('E', 90.0), ('S', 180.0), ('W', 270.0)]) {
      final p = polar(cc, cc, r - 14, e.$2);
      ogText(canvas, e.$1, p.dx, p.dy + 4, color: c.text2, align: 0.5);
    }
    dashedLine(canvas, polar(cc, cc, r + 4, sf - 90), polar(cc, cc, r + 4, sf + 90), strokePaint(c.sand, 1.2), dash: 3, gap: 3);
    canvas.save();
    canvas.translate(cc, cc);
    canvas.rotate((w.from + 180) * math.pi / 180);
    final p = strokePaint(c.wind, 2.6);
    canvas.drawLine(const Offset(0, -26), const Offset(0, 30), p);
    canvas.drawPath(Path()
      ..moveTo(-6, 21)
      ..lineTo(0, 30)
      ..lineTo(6, 21), p);
    canvas.restore();
    canvas.drawCircle(ctr, 16, fillPaint(c.surface));
    ogText(canvas, '${w.speed.round()}', cc, cc + 6, color: c.text, size: 15, weight: FontWeight.w700, align: 0.5);
    if (w.caption != null) ogText(canvas, w.caption!, 2, w.size + 14, color: c.text2);
  }

  @override
  bool shouldRepaint(_CompassPainter o) => o.w != w || o.c != c;
}

// ───────────────────────────── SwellWindow ─────────────────────────────
class OgSwellWindow extends StatelessWidget {
  const OgSwellWindow({super.key, required this.swellFrom, required this.exposure, this.size = 180});
  final num swellFrom;
  final List<num> exposure;
  final double size;

  @override
  Widget build(BuildContext context) => _Chart(
      width: size,
      height: size,
      label: 'Swell from ${swellFrom.round()} degrees; beach open from ${exposure[0]} to ${exposure[1]} degrees',
      builder: (c) => _SwellPainter(this, c));
}

class _SwellPainter extends CustomPainter {
  _SwellPainter(this.w, this.c);
  final OgSwellWindow w;
  final OratgeColors c;
  @override
  void paint(Canvas canvas, Size s) {
    final cc = w.size / 2, r = cc - 12;
    final a0 = w.exposure[0].toDouble(), a1 = w.exposure[1].toDouble();
    final sweep = (a1 - a0 + 360) % 360;
    canvas.drawArc(Rect.fromCircle(center: Offset(cc, cc), radius: r), (a0 - 90) * math.pi / 180, sweep * math.pi / 180, true,
        fillPaint(c.water.withValues(alpha: 0.16)));
    canvas.drawCircle(Offset(cc, cc), r, strokePaint(c.line, 1));
    for (final e in const [('N', 0.0), ('E', 90.0), ('S', 180.0), ('W', 270.0)]) {
      final p = polar(cc, cc, r - 12, e.$2);
      ogText(canvas, e.$1, p.dx, p.dy + 4, color: c.text2, align: 0.5);
    }
    final mid = a0 + sweep / 2;
    dashedLine(canvas, polar(cc, cc, r + 2, mid - 90), polar(cc, cc, r + 2, mid + 90), strokePaint(c.sand, 1.2), dash: 3, gap: 3);
    final a = polar(cc, cc, r - 4, w.swellFrom.toDouble()), b = polar(cc, cc, 8, w.swellFrom.toDouble());
    final ang = math.atan2(b.dy - a.dy, b.dx - a.dx);
    final p = strokePaint(c.water, 2.6);
    canvas.drawLine(a, b, p);
    canvas.drawPath(Path()
      ..moveTo(b.dx - 9 * math.cos(ang + 0.5), b.dy - 9 * math.sin(ang + 0.5))
      ..lineTo(b.dx, b.dy)
      ..lineTo(b.dx - 9 * math.cos(ang - 0.5), b.dy - 9 * math.sin(ang - 0.5)), p);
    canvas.drawCircle(Offset(cc, cc), 3, fillPaint(c.sand));
  }

  @override
  bool shouldRepaint(_SwellPainter o) => o.w != w || o.c != c;
}

// ───────────────────────────── TrendLine ─────────────────────────────
class OgTrendLine extends StatelessWidget {
  const OgTrendLine(
      {super.key,
      required this.values,
      required this.accent,
      this.band,
      this.compare,
      this.nowIndex,
      this.nowLabel,
      this.caption,
      this.endLabels,
      this.min,
      this.max,
      this.height = 70,
      this.semanticLabel});
  final List<num> values;
  final OgAccent accent;
  final List<num>? band, compare;
  final int? nowIndex;
  final String? nowLabel;
  final List<String>? caption, endLabels;
  final num? min, max;
  final double height;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) =>
      _Chart(height: height, label: semanticLabel ?? 'Trend', builder: (c) => _TrendPainter(this, c));
}

class _TrendPainter extends CustomPainter {
  _TrendPainter(this.w, this.c);
  final OgTrendLine w;
  final OratgeColors c;
  @override
  void paint(Canvas canvas, Size s) {
    final all = [...w.values, ...?w.band, ...?w.compare];
    final lo = (w.min ?? all.reduce(math.min)).toDouble(), hi = (w.max ?? all.reduce(math.max)).toDouble();
    final n = math.max(w.values.length, w.compare?.length ?? 0);
    final top = (w.endLabels != null || w.nowLabel != null) ? 18.0 : 4.0;
    final bot = s.height - (w.caption != null ? 16 : 4);
    double x(num i) => 4 + i * (s.width - 8) / (n - 1);
    double y(num v) => bot - (v - lo) / ((hi - lo) == 0 ? 1 : (hi - lo)) * (bot - top);
    final col = c.accent(w.accent);
    final pts = [for (var i = 0; i < w.values.length; i++) Offset(x(i), y(w.values[i]))];
    if (w.band != null) {
      canvas.drawPath(bandPath([for (var i = 0; i < w.band!.length; i++) Offset(x(i), y(w.band![i]))], pts),
          fillPaint(col.withValues(alpha: 0.25)));
    }
    if (w.compare != null) {
      dashedPolyline(canvas, [for (var i = 0; i < w.compare!.length; i++) Offset(x(i), y(w.compare![i]))],
          strokePaint(c.text2, 1.6));
    }
    canvas.drawPath(polyline(pts), strokePaint(col));
    if (w.nowIndex != null && w.nowIndex! < pts.length) {
      final p = pts[w.nowIndex!];
      canvas.drawCircle(p, 3.5, fillPaint(col));
      if (w.nowLabel != null) {
        final align = w.nowIndex! >= n - 2 ? 1.0 : (w.nowIndex! <= 1 ? 0.0 : 0.5);
        ogText(canvas, w.nowLabel!, p.dx, p.dy - 7, color: c.text, weight: FontWeight.w600, align: align);
      }
    }
    if (w.endLabels != null) {
      ogText(canvas, w.endLabels![0], pts.first.dx, pts.first.dy - 6, color: c.text);
      ogText(canvas, w.endLabels![1], pts.last.dx, pts.last.dy - 6, color: c.text, align: 1);
    }
    if (w.caption != null) {
      ogText(canvas, w.caption![0], 0, s.height - 2, color: c.text2);
      ogText(canvas, w.caption![1], s.width, s.height - 2, color: c.text2, align: 1);
    }
  }

  @override
  bool shouldRepaint(_TrendPainter o) => o.w != w || o.c != c;
}

// ───────────────────────────── NextHours ─────────────────────────────
class OgNextHours extends StatelessWidget {
  const OgNextHours(
      {super.key, required this.temps, required this.rain, required this.sky, required this.startHour, this.semanticLabel});
  final List<num> temps, rain;
  final List<WeatherKind> sky;
  final int startHour;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) =>
      _Chart(height: 128, label: semanticLabel ?? 'Next 24 hours', builder: (c) => _NextHoursPainter(this, c));
}

class _NextHoursPainter extends CustomPainter {
  _NextHoursPainter(this.w, this.c);
  final OgNextHours w;
  final OratgeColors c;
  @override
  void paint(Canvas canvas, Size s) {
    final n = w.temps.length;
    final lo = w.temps.reduce(math.min), hi = w.temps.reduce(math.max);
    double x(num i) => 10 + i * (s.width - 20) / (n - 1);
    double y(num t) => 72 - (t - lo) / ((hi - lo) == 0 ? 1 : (hi - lo)) * 30;
    for (var i = 0; i < w.sky.length; i += 3) {
      canvas.save();
      canvas.translate(x(i) - 8, 0);
      WeatherIconPainter(w.sky[i], c).paint(canvas, const Size.square(16));
      canvas.restore();
    }
    final pts = [for (var i = 0; i < n; i++) Offset(x(i), y(w.temps[i]))];
    canvas.drawPath(polyline(pts), strokePaint(c.heat));
    final iMax = w.temps.indexOf(hi), iMin = w.temps.lastIndexOf(lo);
    for (final e in [(0, -8.0), (iMax, -8.0), (iMin, 17.0)]) {
      canvas.drawCircle(pts[e.$1], 3.5, fillPaint(c.heat));
      ogText(canvas, '${w.temps[e.$1].round()}°', pts[e.$1].dx, pts[e.$1].dy + e.$2, color: c.text,
          weight: FontWeight.w600, align: e.$1 == 0 ? 0 : (e.$1 >= n - 2 ? 1 : 0.5));
    }
    const base = 108.0;
    canvas.drawLine(Offset(0, base), Offset(s.width, base), strokePaint(c.line, 1));
    var peak = 0;
    for (var i = 0; i < w.rain.length; i++) {
      if (w.rain[i] > w.rain[peak]) peak = i;
      if (w.rain[i] <= 0) continue;
      final h = w.rain[i] / 100 * 24;
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x(i) - 4.5, base - h, 9, h), const Radius.circular(2)),
          fillPaint(c.water));
    }
    if (w.rain[peak] > 0) {
      final label = '${w.rain[peak].round()}% rain ${_hh(w.startHour + peak)}';
      final right = x(peak) + 8 + ogTextWidth(label) > s.width;
      ogText(canvas, label, right ? x(peak) - 8 : x(peak) + 8, base - 28, color: c.text2, align: right ? 1 : 0);
    }
    for (final i in [0, 6, 12, 18]) {
      if (i < n) ogText(canvas, _hh(w.startHour + i), x(i), 126, color: c.text2, align: i == 0 ? 0 : 0.5);
    }
  }

  @override
  bool shouldRepaint(_NextHoursPainter o) => o.w != w || o.c != c;
}

// ───────────────────────────── CalendarHeatmap ─────────────────────────────
class OgCalendarHeatmap extends StatelessWidget {
  const OgCalendarHeatmap({super.key, required this.weeks, this.months = const [], this.legend, this.semanticLabel});
  final List<List<int>> weeks;
  final List<String> months;
  final List<String>? legend;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) => _Chart(
      height: legend != null ? 150 : 128,
      label: semanticLabel ?? 'Rideable hours per day',
      builder: (c) => _HeatmapPainter(this, c));
}

class _HeatmapPainter extends CustomPainter {
  _HeatmapPainter(this.w, this.c);
  final OgCalendarHeatmap w;
  final OratgeColors c;
  @override
  void paint(Canvas canvas, Size s) {
    const left = 18.0;
    final cell = math.min(16.0, (s.width - left) / w.weeks.length);
    for (final e in const [(0, 'M'), (2, 'W'), (4, 'F'), (6, 'S')]) {
      ogText(canvas, e.$2, 0, e.$1 * (cell + 1) + cell - 2, color: c.text2);
    }
    for (var x = 0; x < w.weeks.length; x++) {
      for (var d = 0; d < w.weeks[x].length; d++) {
        final v = w.weeks[x][d];
        canvas.drawRRect(
            RRect.fromRectAndRadius(Rect.fromLTWH(left + x * cell, d * (cell + 1), cell - 2, cell - 1), const Radius.circular(2.5)),
            fillPaint(v > 0 ? c.ratingColor(v) : c.r0));
      }
    }
    final gridBottom = 7 * (cell + 1);
    for (var i = 0; i < w.months.length; i++) {
      ogText(canvas, w.months[i], left + i * w.weeks.length * cell / w.months.length, gridBottom + 16, color: c.text2);
    }
    if (w.legend != null) {
      final lx = s.width - 150;
      final ly = gridBottom + 38;
      ogText(canvas, w.legend![0], lx, ly, color: c.text2);
      for (var i = 0; i < 5; i++) {
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(lx + 30 + i * 14, ly - 10, 12, 10), const Radius.circular(2)),
            fillPaint(c.rating[i]));
      }
      ogText(canvas, w.legend![1], lx + 104, ly, color: c.text2);
    }
  }

  @override
  bool shouldRepaint(_HeatmapPainter o) => o.w != w || o.c != c;
}

// ───────────────────────────── MonthBars ─────────────────────────────
class OgMonthBars extends StatelessWidget {
  const OgMonthBars(
      {super.key, required this.values, this.accent = OgAccent.wind, this.highlight, this.current, this.semanticLabel});
  final List<num> values;
  final OgAccent accent;
  final int? highlight, current;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) =>
      _Chart(height: 152, label: semanticLabel ?? 'Values per month', builder: (c) => _MonthBarsPainter(this, c));
}

class _MonthBarsPainter extends CustomPainter {
  _MonthBarsPainter(this.w, this.c);
  final OgMonthBars w;
  final OratgeColors c;
  @override
  void paint(Canvas canvas, Size s) {
    const bot = 126.0, top = 14.0;
    final bw = (s.width - 24) / 12;
    final mx = w.values.reduce(math.max) * 1.12;
    double y(num k) => bot - k / mx * (bot - top);
    final col = c.accent(w.accent);
    for (final k in [(mx / 2.4).round(), (mx / 1.2).round()]) {
      canvas.drawLine(Offset(0, y(k)), Offset(s.width - 24, y(k)), strokePaint(c.line, 0.6));
      ogText(canvas, '$k', s.width, y(k) + 4, color: c.text2, align: 1);
    }
    const letters = 'JFMAMJJASOND';
    for (var i = 0; i < 12; i++) {
      canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTRB(i * bw + 3, y(w.values[i]), i * bw + bw - 3, bot), const Radius.circular(3)),
          fillPaint(col.withValues(alpha: i == w.highlight ? 1 : 0.5)));
      ogText(canvas, letters[i], i * bw + bw / 2, bot + 16,
          color: i == w.current ? c.text : c.text2, weight: i == w.current ? FontWeight.w700 : FontWeight.w400, align: 0.5);
    }
    if (w.highlight != null) {
      ogText(canvas, '${w.values[w.highlight!]}', w.highlight! * bw + bw / 2, y(w.values[w.highlight!]) - 5,
          color: c.text, weight: FontWeight.w600, align: 0.5);
    }
    canvas.drawLine(Offset(0, bot), Offset(s.width - 24, bot), strokePaint(c.line, 1));
  }

  @override
  bool shouldRepaint(_MonthBarsPainter o) => o.w != w || o.c != c;
}

// ───────────────────────────── AltitudeProfile ─────────────────────────────
class AltitudePoint {
  const AltitudePoint(this.altitude, this.temp, [this.label]);
  final num altitude, temp;
  final String? label;
}

class OgAltitudeProfile extends StatelessWidget {
  const OgAltitudeProfile({super.key, required this.points, this.snowLevel, this.semanticLabel});
  final List<AltitudePoint> points;
  final num? snowLevel;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) =>
      _Chart(height: 160, label: semanticLabel ?? 'Temperature by altitude', builder: (c) => _AltitudePainter(this, c));
}

class _AltitudePainter extends CustomPainter {
  _AltitudePainter(this.w, this.c);
  final OgAltitudeProfile w;
  final OratgeColors c;
  @override
  void paint(Canvas canvas, Size s) {
    final alts = w.points.map((p) => p.altitude), temps = w.points.map((p) => p.temp);
    final aLo = (alts.reduce(math.min) / 500).floor() * 500.0, aHi = (alts.reduce(math.max) / 500).ceil() * 500.0;
    final tLo = math.min(-4, temps.reduce(math.min)) - 1.0, tHi = temps.reduce(math.max) + 5.0;
    double x(num t) => 50 + (t - tLo) / (tHi - tLo) * (s.width - 62);
    double y(num a) => 140 - (a - aLo) / (aHi - aLo) * 124;
    for (var a = aLo + 500; a <= aHi; a += 500) {
      canvas.drawLine(Offset(44, y(a)), Offset(s.width, y(a)), strokePaint(c.line, 0.5));
      ogText(canvas, '${a.round()} m', 0, y(a) + 4, color: c.text2);
    }
    dashedLine(canvas, Offset(x(0), 8), Offset(x(0), 144), strokePaint(c.snow, 1));
    ogText(canvas, '0 °C', x(0) + 4, 156, color: c.text2);
    if (w.snowLevel != null) {
      canvas.drawLine(Offset(44, y(w.snowLevel!)), Offset(s.width, y(w.snowLevel!)), strokePaint(c.snow.withValues(alpha: 0.7), 1));
      ogText(canvas, 'snow level ${w.snowLevel} m', s.width, y(w.snowLevel!) - 5, color: c.text2, align: 1);
    }
    final pts = [for (final p in w.points) Offset(x(p.temp), y(p.altitude))];
    canvas.drawPath(polyline(pts), strokePaint(c.heat));
    for (var i = 0; i < w.points.length; i++) {
      canvas.drawCircle(pts[i], 3.5, fillPaint(c.heat));
      final p = w.points[i];
      if (p.label != null) {
        // Labels sit right of the point; the top (summit) label goes above it to clear the altitude axis.
        final top = i == w.points.length - 1;
        ogText(canvas, '${p.label} ${p.temp}°', pts[i].dx + (top ? 6 : 8), pts[i].dy + (top ? -9 : 4), color: c.text);
      }
    }
  }

  @override
  bool shouldRepaint(_AltitudePainter o) => o.w != w || o.c != c;
}

// ───────────────────────────── RouteWind ─────────────────────────────
class OgRouteWind extends StatelessWidget {
  const OgRouteWind(
      {super.key, required this.points, required this.windFrom, required this.windLabel, this.title, this.labels = const []});
  /// Route polyline in a 322×150 design box (scaled to the available width).
  final List<Offset> points;
  final num windFrom;
  final String windLabel;
  final String? title;
  final List<(Offset, String)> labels;

  @override
  Widget build(BuildContext context) =>
      _Chart(height: 184, label: title ?? 'Wind along the route', builder: (c) => _RouteWindPainter(this, c));
}

class _RouteWindPainter extends CustomPainter {
  _RouteWindPainter(this.w, this.c);
  final OgRouteWind w;
  final OratgeColors c;
  @override
  void paint(Canvas canvas, Size s) {
    final sx = s.width / 322;
    Offset t(Offset p) => Offset(p.dx * sx, p.dy + 8);
    for (var i = 0; i < w.points.length - 1; i++) {
      final a = w.points[i], b = w.points[i + 1];
      final bearing = (math.atan2(b.dx - a.dx, a.dy - b.dy) * 180 / math.pi + 360) % 360;
      final rel = math.cos((bearing - (w.windFrom + 180)) * math.pi / 180);
      final col = rel > 0.35 ? c.wind : (rel < -0.35 ? c.heat : c.text3);
      canvas.drawLine(t(a), t(b), strokePaint(col, 5));
    }
    canvas.drawCircle(t(w.points.first), 5, fillPaint(c.text));
    for (final l in w.labels) {
      ogText(canvas, l.$2, l.$1.dx * sx, l.$1.dy + 8, color: c.text2);
    }
    windArrow(canvas, Offset(s.width - 22, 30), w.windFrom.toDouble(), c.wind, len: 9, width: 2);
    ogText(canvas, w.windLabel, s.width - 22, 56, color: c.text2, align: 0.5);
    if (w.title != null) ogText(canvas, w.title!, 0, 14, color: c.text, weight: FontWeight.w600);
    var lx = 0.0;
    for (final e in [('tailwind', c.wind), ('crosswind', c.text3), ('headwind', c.heat)]) {
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(lx, 170, 10, 10), const Radius.circular(3)), fillPaint(e.$2));
      ogText(canvas, e.$1, lx + 16, 180, color: c.text2);
      lx += 92;
    }
  }

  @override
  bool shouldRepaint(_RouteWindPainter o) => o.w != w || o.c != c;
}
