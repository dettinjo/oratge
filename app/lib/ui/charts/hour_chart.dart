import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/og_helpers.dart';
import '../../theme/oratge_tokens.dart';
import '../components/weather_icon.dart';

/// One row of the planner meteogram (HourChart.d.ts `HourRow`).
class HourRow {
  HourRow({
    required this.type,
    required this.label,
    this.unit,
    this.values = const [],
    this.icons = const [],
    this.labels = const [],
    this.min,
    this.max,
    this.accent,
    this.band,
    this.companion,
    this.range,
    this.rangeLabel,
    this.labelAt = const [],
    this.labelEvery,
    this.decimals = 0,
    this.highlight,
    this.shore,
    this.offshoreGood = false,
    this.every,
    this.suffix = '',
    this.emphasizeAbove,
    this.styles = const {},
    this.height,
  });

  /// icons | rating | line | bars | arrows | numbers | category
  final String type;
  final String label;
  final String? unit;
  final List<num> values;
  final List<WeatherKind> icons;
  final List<String> labels; // category values
  final num? min;
  final num? max;
  final OgAccent? accent;
  final List<num>? band;
  final List<num>? companion;
  final List<num>? range;
  final String? rangeLabel;
  final List<int> labelAt;
  final int? labelEvery;
  final int decimals;
  final List<int>? highlight;
  final List<String>? shore;

  /// Surf: offshore wind is what you want, so don't flag it as a warning.
  final bool offshoreGood;
  final int? every;
  final String suffix;
  final num? emphasizeAbove;
  final Map<String, CategoryStyle> styles;
  final double? height;

  factory HourRow.fromJson(Map<String, dynamic> j) {
    List<num>? nums(String k) => (j[k] as List?)?.map((e) => e as num).toList();
    final type = j['type'] as String;
    return HourRow(
      type: type,
      label: j['label'] as String? ?? '',
      unit: j['unit'] as String?,
      values: type == 'icons' || type == 'category'
          ? const []
          : (nums(type == 'arrows' ? 'directions' : 'values') ?? const []),
      icons: type == 'icons' ? [for (final v in j['values'] as List) weatherKindFrom(v as String)] : const [],
      labels: type == 'category' ? [for (final v in j['values'] as List) v as String] : const [],
      min: j['min'] as num?,
      max: j['max'] as num?,
      accent: accentFromString(j['accent'] as String?),
      band: nums('band'),
      companion: nums('companion'),
      range: nums('range'),
      rangeLabel: j['rangeLabel'] as String?,
      labelAt: [for (final v in (j['labelAt'] as List? ?? const [])) (v as num).toInt()],
      labelEvery: (j['labelEvery'] as num?)?.toInt(),
      decimals: (j['decimals'] as num?)?.toInt() ?? 0,
      highlight: (j['highlight'] as List?)?.map((e) => (e as num).toInt()).toList(),
      shore: (j['shore'] as List?)?.map((e) => e as String).toList(),
      offshoreGood: j['offshoreGood'] == true,
      every: (j['every'] as num?)?.toInt(),
      suffix: j['suffix'] as String? ?? '',
      emphasizeAbove: j['emphasizeAbove'] as num?,
      styles: {
        for (final e in (j['styles'] as Map<String, dynamic>? ?? const {}).entries)
          e.key: CategoryStyle.fromJson(e.value as Map<String, dynamic>)
      },
      height: (j['height'] as num?)?.toDouble(),
    );
  }
}

class CategoryStyle {
  CategoryStyle({required this.accent, this.opacity = 1, this.text});
  final String accent; // 'water' or 'empty'
  final double opacity;
  final String? text;
  factory CategoryStyle.fromJson(Map<String, dynamic> j) {
    // Sample data stores hex colours from the design; map them to semantic accents.
    final color = (j['color'] as String? ?? '').toLowerCase();
    final accent = j['accent'] as String? ?? (color.contains('8aaef2') || color.contains('water') ? 'water' : 'empty');
    return CategoryStyle(accent: accent, opacity: (j['opacity'] as num?)?.toDouble() ?? 1, text: j['text'] as String?);
  }
}

const _rowH = {'icons': 28.0, 'rating': 22.0, 'line': 84.0, 'bars': 36.0, 'arrows': 26.0, 'numbers': 24.0, 'category': 24.0};

/// The planner meteogram: one row per variable on shared hour columns, night shaded, best window framed.
class OgHourChart extends StatelessWidget {
  const OgHourChart({
    super.key,
    required this.hours,
    required this.rows,
    this.best,
    this.sunrise = 7.6,
    this.sunset = 17.6,
    this.semanticLabel,
  });
  final List<int> hours;
  final List<HourRow> rows;
  final List<num>? best;
  final double sunrise;
  final double sunset;
  final String? semanticLabel;

  static const labW = 58.0;

  static bool _inlineUnit(HourRow r) =>
      r.unit != null && (r.type == 'numbers' || (r.type == 'arrows' && r.shore == null)) && r.label.length + r.unit!.length <= 8;

  static double rowHeight(HourRow r) {
    final base = r.height ?? _rowH[r.type] ?? 24;
    return r.unit != null && !_inlineUnit(r) ? math.max(base, 34) : base;
  }

  @override
  Widget build(BuildContext context) {
    final total = 20 + rows.fold<double>(0, (a, r) => a + rowHeight(r));
    return Semantics(
      label: semanticLabel ?? 'Hour by hour chart',
      excludeSemantics: true,
      child: LayoutBuilder(
        builder: (context, box) => CustomPaint(
          size: Size(box.maxWidth, total),
          painter: _HourChartPainter(this, context.og),
        ),
      ),
    );
  }
}

class _HourChartPainter extends CustomPainter {
  _HourChartPainter(this.w, this.c);
  final OgHourChart w;
  final OratgeColors c;

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    const lab = OgHourChart.labW;
    final hours = w.hours;
    final cw = (width - lab) / hours.length;
    final h0 = hours.first;
    double cx(int i) => lab + i * cw + cw / 2;
    double hx(num h) => lab + (h - h0) * cw;
    final total = size.height;

    // Night shading.
    final night = Paint()..color = c.night;
    canvas.drawRect(Rect.fromLTRB(lab, 16, math.max(lab, hx(w.sunrise)), total), night);
    canvas.drawRect(Rect.fromLTRB(math.min(width, hx(w.sunset)), 16, width, total), night);

    // Hour axis (every 2 h).
    for (var i = 0; i < hours.length; i++) {
      if (hours[i] % 2 == 0) {
        ogText(canvas, hours[i].toString().padLeft(2, '0'), cx(i), 12, color: c.text2, align: 0.5);
      }
    }

    var y = 20.0;
    for (var k = 0; k < w.rows.length; k++) {
      final r = w.rows[k];
      final h = OgHourChart.rowHeight(r);
      if (k > 0) {
        canvas.drawLine(Offset(0, y), Offset(width, y), Paint()
          ..color = c.line
          ..strokeWidth = 0.6);
      }
      // Row label (+ unit inline or on a second line).
      final ly = y + math.min(h / 2 + 4, 16);
      ogText(canvas, r.label, 0, ly, color: c.text2, weight: FontWeight.w500);
      if (r.unit != null) {
        if (OgHourChart._inlineUnit(r)) {
          ogText(canvas, r.unit!, ogTextWidth(r.label, weight: FontWeight.w500) + 3, ly, color: c.text3);
        } else {
          ogText(canvas, r.unit!, 0, ly + 13, color: c.text3);
        }
      }
      _row(canvas, r, y, h, width, cx, cw);
      y += h;
    }

    // Best window frame (drawn last, over the rows).
    if (w.best != null && w.best!.length == 2) {
      final rect = RRect.fromRectAndRadius(
          Rect.fromLTRB(hx(w.best![0]), 15, hx(w.best![1]), total - 1), const Radius.circular(6));
      _dashedRRect(canvas, rect, Paint()
        ..color = c.text.withValues(alpha: 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1);
    }
  }

  void _row(Canvas canvas, HourRow r, double y, double h, double width, double Function(int) cx, double cw) {
    const lab = OgHourChart.labW;
    switch (r.type) {
      case 'icons':
        for (var i = 0; i < r.icons.length; i += 2) {
          canvas.save();
          canvas.translate(cx(i) - 9, y + 4);
          WeatherIconPainter(r.icons[i], c).paint(canvas, const Size.square(18));
          canvas.restore();
        }
      case 'rating':
        for (var i = 0; i < r.values.length; i++) {
          canvas.drawRRect(
              RRect.fromRectAndRadius(Rect.fromLTWH(lab + i * cw + 1, y + 4, cw - 2, h - 8), const Radius.circular(3)),
              Paint()..color = r.values[i] > 0 ? c.ratingColor(r.values[i]) : c.r0);
        }
      case 'line':
        final top = y + 12, bot = y + h - 6;
        final lo = (r.min ?? 0).toDouble(), hi = (r.max ?? 1).toDouble();
        double yy(num v) => bot - (v - lo) / (hi - lo) * (bot - top);
        final col = c.accent(r.accent ?? OgAccent.neutral);
        if (r.range != null && r.range!.length == 2) {
          final a = yy(math.min(r.range![1], hi)), b = yy(math.max(r.range![0], lo));
          _hatch(canvas, Rect.fromLTRB(lab, a, width, b));
          if (r.rangeLabel != null) ogText(canvas, r.rangeLabel!, width - 2, a - 3, color: c.text2, align: 1);
        }
        final pts = [for (var i = 0; i < r.values.length; i++) Offset(cx(i), yy(r.values[i]))];
        if (r.band != null) {
          final up = [for (var i = 0; i < r.band!.length; i++) Offset(cx(i), yy(r.band![i]))];
          final p = Path()..addPolygon([...up, ...pts.reversed], true);
          canvas.drawPath(p, Paint()..color = col.withValues(alpha: 0.25));
        }
        if (r.companion != null) {
          final cp = [for (var i = 0; i < r.companion!.length; i++) Offset(cx(i), yy(r.companion![i]))];
          _dashedPolyline(canvas, cp, Paint()
            ..color = col
            ..strokeWidth = 1.6
            ..style = PaintingStyle.stroke);
        }
        canvas.drawPath(Path()..addPolygon(pts, false), Paint()
          ..color = col
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round);
        for (final i in r.labelAt) {
          if (i >= pts.length) continue;
          canvas.drawCircle(pts[i], 3, Paint()..color = col);
          ogText(canvas, _fmt(r.values[i], r.decimals), pts[i].dx, pts[i].dy - 6, color: c.text, weight: FontWeight.w600, align: 0.5);
        }
      case 'bars':
        final top = y + (r.labelEvery != null ? 15 : 5), bot = y + h - 4;
        final col = c.accent(r.accent ?? OgAccent.neutral);
        final mx = (r.max ?? 1).toDouble();
        for (var i = 0; i < r.values.length; i++) {
          final v = r.values[i];
          if (v == 0) continue;
          final bh = math.max(2.0, v / mx * (bot - top));
          final hi = r.highlight == null || r.highlight!.contains(i);
          canvas.drawRRect(
              RRect.fromRectAndRadius(Rect.fromLTWH(cx(i) - cw * 0.32, bot - bh, cw * 0.64, bh), const Radius.circular(2.5)),
              Paint()..color = col.withValues(alpha: hi ? 1 : 0.5));
          if (r.labelEvery != null && i % r.labelEvery! == 0 && cw >= 14) {
            ogText(canvas, _fmt(v, r.decimals), cx(i), bot - bh - 3, color: c.text2, align: 0.5);
          }
        }
      case 'arrows':
        final col = c.accent(r.accent ?? OgAccent.wind);
        for (var i = 0; i < r.values.length; i++) {
          if (r.every != null && i % r.every! != 0) continue;
          final ay = y + (r.shore != null ? 11 : h / 2);
          _arrow(canvas, Offset(cx(i), ay), r.values[i].toDouble(), col, 6);
          if (r.shore != null && i < r.shore!.length && i % 2 == 0) {
            final t = r.shore![i];
            ogText(canvas, t == 'side-on' ? 'S-on' : t, cx(i), y + h - 3,
                color: t == 'off' && !r.offshoreGood ? c.warnRed : (t == 'off' ? c.text : c.text2),
                weight: t == 'off' ? FontWeight.w700 : FontWeight.w400,
                align: 0.5);
          }
        }
      case 'numbers':
        final every = r.every ?? (cw < 22 ? 2 : 1);
        for (var i = 0; i < r.values.length; i += every) {
          final v = r.values[i];
          final emph = r.emphasizeAbove != null && v > r.emphasizeAbove!;
          ogText(canvas, '${_fmt(v, r.decimals)}${r.suffix}', cx(i), y + h / 2 + 4,
              color: emph ? c.text : c.text2, weight: emph ? FontWeight.w700 : FontWeight.w400, align: 0.5);
        }
      case 'category':
        for (var i = 0; i < r.labels.length; i++) {
          final s = r.styles[r.labels[i]];
          if (s == null) continue;
          final base = s.accent == 'water' ? c.water : c.r0;
          canvas.drawRRect(
              RRect.fromRectAndRadius(Rect.fromLTWH(lab + i * cw + 1, y + 5, cw - 2, h - 10), const Radius.circular(3)),
              Paint()..color = base.withValues(alpha: s.opacity));
        }
        for (var i = 0; i < r.labels.length; i++) {
          final s = r.styles[r.labels[i]];
          if (s?.text == null || (i > 0 && r.labels[i - 1] == r.labels[i])) continue;
          var run = 1;
          while (i + run < r.labels.length && r.labels[i + run] == r.labels[i]) {
            run++;
          }
          if (run * cw >= ogTextWidth(s!.text!) + 6) {
            ogText(canvas, s.text!, lab + i * cw + 4, y + h / 2 + 4, color: c.bg, weight: FontWeight.w600);
          }
        }
    }
  }

  String _fmt(num v, int decimals) => decimals > 0 ? v.toStringAsFixed(decimals) : v.round().toString();

  void _arrow(Canvas canvas, Offset at, double from, Color col, double len) {
    canvas.save();
    canvas.translate(at.dx, at.dy);
    canvas.rotate((from + 180) * math.pi / 180);
    final p = Paint()
      ..color = col
      ..strokeWidth = 1.7
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawLine(Offset(0, -len), Offset(0, len), p);
    canvas.drawPath(Path()
      ..moveTo(-3, len - 3.5)
      ..lineTo(0, len)
      ..lineTo(3, len - 3.5), p);
    canvas.restore();
  }

  void _hatch(Canvas canvas, Rect r) {
    canvas.save();
    canvas.clipRect(r);
    final p = Paint()
      ..color = c.line
      ..strokeWidth = 1.4;
    for (var x = r.left - r.height; x < r.right; x += 5) {
      canvas.drawLine(Offset(x, r.bottom), Offset(x + r.height, r.top), p);
    }
    canvas.restore();
  }

  void _dashedPolyline(Canvas canvas, List<Offset> pts, Paint p) {
    for (var i = 0; i < pts.length - 1; i++) {
      final a = pts[i], b = pts[i + 1];
      final d = (b - a).distance;
      final dir = (b - a) / d;
      for (var t = 0.0; t < d; t += 5) {
        canvas.drawLine(a + dir * t, a + dir * math.min(t + 2, d), p);
      }
    }
  }

  void _dashedRRect(Canvas canvas, RRect r, Paint p) {
    final path = Path()..addRRect(r);
    for (final m in path.computeMetrics()) {
      for (var t = 0.0; t < m.length; t += 5) {
        canvas.drawPath(m.extractPath(t, t + 2), p);
      }
    }
  }

  @override
  bool shouldRepaint(_HourChartPainter old) => old.w != w || old.c != c;
}
