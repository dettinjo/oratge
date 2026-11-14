import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../data/models.dart';
import '../../data/profile.dart';
import '../../data/units.dart';
import '../../theme/og_helpers.dart';
import '../../theme/oratge_tokens.dart';
import '../charts/chart_utils.dart';
import '../components/basics.dart';
import '../components/scrub.dart';
import '../components/sheets.dart';
import '../components/weather_icon.dart';
import 'common.dart';

/// Weather quantities with a detail view (tap a tile on Today).
enum Metric { temp, feels, wind, rain, uv, humidity, pressure, visibility, cloud }

extension MetricInfo on Metric {
  String get title => switch (this) {
        Metric.temp => 'Temperature',
        Metric.feels => 'Feels like',
        Metric.wind => 'Wind',
        Metric.rain => 'Rain',
        Metric.uv => 'UV index',
        Metric.humidity => 'Humidity',
        Metric.pressure => 'Pressure',
        Metric.visibility => 'Visibility',
        Metric.cloud => 'Cloud cover',
      };

  IconData get icon => switch (this) {
        Metric.temp => Icons.thermostat_outlined,
        Metric.feels => Icons.accessibility_new,
        Metric.wind => Icons.air,
        Metric.rain => Icons.water_drop_outlined,
        Metric.uv => Icons.wb_sunny_outlined,
        Metric.humidity => Icons.opacity,
        Metric.pressure => Icons.speed,
        Metric.visibility => Icons.visibility_outlined,
        Metric.cloud => Icons.cloud_outlined,
      };

  /// Series key in /v1/hourly.
  String get key => switch (this) {
        Metric.temp => 'temp',
        Metric.feels => 'feels',
        Metric.wind => 'wind',
        Metric.rain => 'precip',
        Metric.uv => 'uv',
        Metric.humidity => 'humidity',
        Metric.pressure => 'pressure',
        Metric.visibility => 'visibility',
        Metric.cloud => 'cloud',
      };

  Color color(OratgeColors c) => switch (this) {
        Metric.temp || Metric.feels => c.heat,
        Metric.wind => c.wind,
        Metric.rain || Metric.humidity => c.water,
        Metric.uv => c.sun,
        _ => c.text2,
      };

  String get about => switch (this) {
        Metric.temp => 'Air temperature 2 m above the ground. The dots on today’s chart are what the nearest Meteocat station measured.',
        Metric.feels => 'How warm or cold it feels, combining temperature with wind (cooling) and humidity (heat). Dress for this number.',
        Metric.wind => 'Average wind 10 m above the ground; the band shows gusts, the short bursts above the average. Arrows point where the wind blows to.',
        Metric.rain => 'Bars: rain expected in each hour (mm). Line: the chance that it rains at all in that hour.',
        Metric.uv => 'UV index: 0–2 low, 3–5 moderate, 6–7 high, 8–10 very high, 11+ extreme. From 3, use sun protection; from 6, seek shade at midday.',
        Metric.humidity => 'Relative humidity: how close the air is to saturation. The dew point (line in the readout) says how muggy it feels: above 16° feels humid, above 20° oppressive.',
        Metric.pressure => 'Sea-level pressure. A fall of more than 1 hPa per 3 hours often means a front or a storm is coming; rising pressure usually brings settled weather.',
        Metric.visibility => 'How far you can see. Below 1 km is fog; below 5 km, haze or mist.',
        Metric.cloud => 'Share of the sky covered by cloud at any level.',
      };

  String unit(Units u) => switch (this) {
        Metric.temp || Metric.feels => '°',
        Metric.wind => u.windUnit(),
        Metric.rain => 'mm',
        Metric.uv => '',
        Metric.humidity || Metric.cloud => '%',
        Metric.pressure => 'hPa',
        Metric.visibility => 'km',
      };

  /// Value in the user's units.
  double show(double v, Units u) => switch (this) {
        Metric.temp || Metric.feels => u.tempValue(v),
        Metric.wind => u.windValue(v),
        _ => v,
      };

  String fmt(double? v, Units u, {bool withUnit = true}) {
    if (v == null) return '—';
    final x = show(v, u);
    final s = switch (this) {
      Metric.rain => x.toStringAsFixed(x < 10 ? 1 : 0),
      Metric.visibility || Metric.uv => x.toStringAsFixed(x < 10 ? 1 : 0),
      Metric.wind when u.wind == 'm/s' => x.toStringAsFixed(1),
      _ => x.round().toString(),
    };
    if (!withUnit) return s;
    final un = unit(u);
    return switch (un) { '°' => '$s°', '' => s, '%' => '$s %', _ => '$s $un' };
  }
}

String uvWord(double uv) => uv < 3 ? 'Low' : uv < 6 ? 'Moderate' : uv < 8 ? 'High' : uv < 11 ? 'Very high' : 'Extreme';

/// Opens the detail for a metric: a centred panel on wide windows, a tall sheet on phones.
Future<void> openMetric(BuildContext context, Metric m, {Place? place}) =>
    showOgSheet(context, maxWidth: 900, initialSize: 0.92, child: MetricDetail(metric: m, place: place));

class MetricDetail extends StatefulWidget {
  const MetricDetail({super.key, required this.metric, this.place});
  final Metric metric;
  final Place? place;
  @override
  State<MetricDetail> createState() => _MetricDetailState();
}

class _MetricDetailState extends State<MetricDetail> {
  late Metric _m = widget.metric;
  int _day = 0;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final place = widget.place ?? app.place;
    return AsyncView<HourlyData>(
      key: ValueKey('hourly-${place?.lat}-${place?.lon}'),
      load: () => app.repository.hourly(place),
      builder: (context, d) => _body(context, d, app.units),
    );
  }

  Widget _body(BuildContext context, HourlyData d, Units u) {
    final c = context.og;
    final m = _m;
    final (a, b) = d.dayRange(_day);
    final vals = (d.series[m.key] ?? const <double?>[]).sublist(a, b);
    final times = d.times.sublist(a, b);
    final day = _day < d.days.length ? d.days[_day] : const <String, dynamic>{};
    final now = DateTime.now();
    final nowIdx = _day == 0 ? times.indexWhere((t) => t.hour == now.hour) : -1;
    final observed = _day == 0 ? (d.observed[m.key] ?? const {}) : const <DateTime, double>{};
    final present = [for (final v in vals) ?v];

    // Headline: today = now; other days = the day's characteristic value.
    final (String big, String small) = _headline(m, u, vals, nowIdx, day, observed, d);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(m.icon, color: m.color(c)),
        const SizedBox(width: 10),
        Expanded(child: Text(m.title, style: OgText.verdictBest.copyWith(color: c.text))),
      ]),
      Text(d.place.name, style: OgText.day.copyWith(color: c.text2)),
      const SizedBox(height: 12),
      // Other metrics, one tap away (like Apple Weather's metric menu).
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          for (final x in Metric.values)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(
                label: Text(x.title),
                selected: x == m,
                showCheckmark: false,
                selectedColor: c.text,
                backgroundColor: c.surface,
                side: BorderSide(color: c.line),
                labelStyle: OgText.chip.copyWith(color: x == m ? c.bg : c.text),
                onSelected: (_) => setState(() => _m = x),
              ),
            ),
        ]),
      ),
      const SizedBox(height: 12),
      _DayStrip(days: d.days, selected: _day, metric: m, units: u, onSelect: (i) => setState(() => _day = i)),
      const SizedBox(height: 16),
      Text(big, style: OgText.verdictBest.copyWith(color: c.text, fontSize: 40, height: 1.05)),
      Text(small, style: OgText.day.copyWith(color: c.text2)),
      const SizedBox(height: 12),
      if (present.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 30),
          child: Text('No data for this day.', style: OgText.day.copyWith(color: c.text2)),
        )
      else
        OgCard(
          child: Scrub(
            count: vals.length,
            indexAt: (dx, w) {
              if (vals.isEmpty) return null;
              final i = ((dx - _MetricChartPainter.left) / (w - _MetricChartPainter.left - 8) * vals.length).floor();
              return i.clamp(0, vals.length - 1);
            },
            chart: (sel) => SizedBox(
              height: 210,
              child: CustomPaint(
                size: Size.infinite,
                painter: _MetricChartPainter(
                  metric: m,
                  units: u,
                  times: times,
                  values: vals,
                  gust: m == Metric.wind ? (d.series['gust'] ?? const []).sublist(a, b) : null,
                  dirs: m == Metric.wind ? (d.series['wdir'] ?? const []).sublist(a, b) : null,
                  chance: m == Metric.rain ? (d.series['pprob'] ?? const []).sublist(a, b) : null,
                  observed: observed,
                  nowIdx: nowIdx,
                  selected: sel,
                  c: c,
                ),
              ),
            ),
            readout: (i, c) {
              final t = times[i];
              return (
                '${t.hour.toString().padLeft(2, '0')}:00',
                [
                  ReadoutItem(m.title, m.fmt(vals[i], u), color: m.color(c)),
                  if (m == Metric.wind) ...[
                    ReadoutItem('gusts', m.fmt(d.series['gust']?[a + i], u), color: c.wind),
                    ReadoutItem('from', compassName(d.series['wdir']?[a + i] ?? 0)),
                  ],
                  if (m == Metric.rain) ReadoutItem('chance', '${(d.series['pprob']?[a + i] ?? 0).round()} %', color: c.water),
                  if ((d.series['storm']?[a + i] ?? 0) >= 30)
                    ReadoutItem('⚡ thunder likely', '${d.series['storm']![a + i]!.round()} %', color: c.storm),
                  if (m == Metric.humidity) ReadoutItem('dew point', Metric.temp.fmt(d.series['dew']?[a + i], u)),
                  if (m == Metric.uv) ReadoutItem('', uvWord(vals[i] ?? 0)),
                  if (observed[DateTime(t.year, t.month, t.day, t.hour)] case final o?)
                    ReadoutItem('measured', m.fmt(o, u), color: c.text),
                ]
              );
            },
          ),
        ),
      const OgSectionLabel('Summary'),
      Text(_summary(m, u, vals, times, day, observed, d.observedStation),
          style: OgText.verdictSummary.copyWith(color: c.text)),
      const OgSectionLabel('7 days'),
      OgCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Column(children: [
          for (final (i, x) in d.days.indexed)
            InkWell(
              onTap: () => setState(() => _day = i),
              child: Container(
                constraints: const BoxConstraints(minHeight: 44),
                decoration: BoxDecoration(border: i == d.days.length - 1 ? null : Border(bottom: BorderSide(color: c.line))),
                child: Row(children: [
                  SizedBox(
                      width: 58,
                      child: Text('${x['day']}',
                          style: OgText.day.copyWith(color: c.text, fontWeight: i == _day ? FontWeight.w700 : FontWeight.w400))),
                  OgWeatherIcon(weatherKindFrom('${x['sky']}'), size: 22),
                  const SizedBox(width: 12),
                  Expanded(child: Text(_dayLine(m, u, x, d, i), style: OgText.day.copyWith(color: c.text2))),
                ]),
              ),
            ),
        ]),
      ),
      const OgSectionLabel('About'),
      Text(m.about, style: OgText.verdictSummary.copyWith(color: c.text2)),
      const SizedBox(height: 10),
      OgDataSources(d.sources),
    ]);
  }

  (String, String) _headline(Metric m, Units u, List<double?> vals, int nowIdx, Json day, Map<DateTime, double> obs, HourlyData d) {
    final present = [for (final v in vals) ?v];
    if (present.isEmpty) return ('—', '');
    if (nowIdx >= 0 && vals[nowIdx] != null) {
      final now = DateTime.now();
      final measured = obs[DateTime(now.year, now.month, now.day, now.hour)] ?? (obs.isEmpty ? null : obs.values.last);
      final v = (m != Metric.rain && measured != null) ? measured : vals[nowIdx]!;
      final src = (m != Metric.rain && measured != null) ? 'measured now' : 'forecast now';
      final extra = switch (m) {
        Metric.uv => ' · ${uvWord(v)}',
        Metric.wind => ' · gusts ${m.fmt(d.series['gust']?[d.dayRange(0).$1 + nowIdx], u)}',
        Metric.rain => ' · ${(d.series['pprob']?[d.dayRange(0).$1 + nowIdx] ?? 0).round()} % chance this hour',
        _ => '',
      };
      return (m.fmt(v, u), '$src$extra');
    }
    final hi = present.reduce(math.max), lo = present.reduce(math.min);
    return switch (m) {
      Metric.rain => (m.fmt(present.fold<double>(0, (a, b) => a + b), u), 'total for the day · up to ${day['pprob'] ?? '—'} % chance'),
      Metric.temp || Metric.feels => ('${m.fmt(hi, u)} / ${m.fmt(lo, u)}', 'high / low'),
      Metric.uv => (m.fmt(hi, u), 'max · ${uvWord(hi)}'),
      Metric.wind => (m.fmt(hi, u), 'strongest average · gusts up to ${m.fmt(d.days.isEmpty ? null : (day['gustMax'] as num?)?.toDouble(), u)}'),
      _ => ('${m.fmt(lo, u, withUnit: false)}–${m.fmt(hi, u)}', 'range over the day'),
    };
  }

  String _summary(Metric m, Units u, List<double?> vals, List<DateTime> times, Json day, Map<DateTime, double> obs, String? station) {
    final idx = [for (var i = 0; i < vals.length; i++) if (vals[i] != null) i];
    if (idx.isEmpty) return 'No forecast for this day.';
    String at(int i) => '${times[i].hour.toString().padLeft(2, '0')}:00';
    final hiI = idx.reduce((a, b) => vals[a]! >= vals[b]! ? a : b);
    final loI = idx.reduce((a, b) => vals[a]! <= vals[b]! ? a : b);
    final measured = obs.isEmpty || station == null
        ? ''
        : ' $station has measured ${m.fmt(obs.values.reduce(math.max), u)} at most so far${m == Metric.rain ? ' per hour' : ''}.';
    switch (m) {
      case Metric.rain:
        final wet = [for (final i in idx) if (vals[i]! >= 0.1) i];
        if (wet.isEmpty) return 'Dry: no rain expected.$measured';
        final total = wet.fold<double>(0, (a, i) => a + vals[i]!);
        return 'Rain from ${at(wet.first)} to ${at(wet.last)}, ${m.fmt(total, u)} in total, heaviest around ${at(hiI)} '
            '(${m.fmt(vals[hiI], u)}).$measured';
      case Metric.uv:
        final prot = [for (final i in idx) if (vals[i]! >= 3) i];
        return prot.isEmpty
            ? 'UV stays low all day (max ${m.fmt(vals[hiI], u)}).'
            : 'Use sun protection from ${at(prot.first)} to ${at(prot.last)}. Peak ${m.fmt(vals[hiI], u)} at ${at(hiI)} (${uvWord(vals[hiI]!)}).';
      case Metric.wind:
        final dir = (day['windDir'] as num?)?.toDouble();
        return 'Mostly from the ${dir == null ? '—' : compassName(dir)}. Strongest around ${at(hiI)} at ${m.fmt(vals[hiI], u)}, '
            'calmest around ${at(loI)} (${m.fmt(vals[loI], u)}). Gusts up to ${m.fmt((day['gustMax'] as num?)?.toDouble(), u)}.$measured';
      case Metric.pressure:
        final first = vals[idx.first]!, last = vals[idx.last]!;
        final d = last - first;
        final word = d <= -3 ? 'falls markedly' : d < -1 ? 'falls' : d > 3 ? 'rises markedly' : d > 1 ? 'rises' : 'stays steady';
        return 'Pressure $word over the day (${first.round()} → ${last.round()} hPa).';
      default:
        return 'Highest ${m.fmt(vals[hiI], u)} at ${at(hiI)}, lowest ${m.fmt(vals[loI], u)} at ${at(loI)}.$measured';
    }
  }

  String _dayLine(Metric m, Units u, Json x, HourlyData d, int i) {
    double? n(String k) => (x[k] as num?)?.toDouble();
    switch (m) {
      case Metric.temp:
        return '${m.fmt(n('min'), u)} – ${m.fmt(n('max'), u)}';
      case Metric.wind:
        return '${m.fmt(n('windMax'), u)} · gusts ${m.fmt(n('gustMax'), u)} · from ${compassName(n('windDir') ?? 0)}';
      case Metric.rain:
        return '${m.fmt(n('precip'), u)} · ${x['pprob'] ?? '—'} % chance';
      case Metric.uv:
        return 'max ${m.fmt(n('uvMax'), u)} · ${uvWord(n('uvMax') ?? 0)}';
      default:
        final (a, b) = d.dayRange(i);
        final v = [for (final y in (d.series[m.key] ?? const <double?>[]).sublist(a, b)) ?y];
        if (v.isEmpty) return '—';
        return '${m.fmt(v.reduce(math.min), u, withUnit: false)} – ${m.fmt(v.reduce(math.max), u)}';
    }
  }
}

class _DayStrip extends StatelessWidget {
  const _DayStrip({required this.days, required this.selected, required this.metric, required this.units, required this.onSelect});
  final List<Json> days;
  final int selected;
  final Metric metric;
  final Units units;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final c = context.og;
    return SizedBox(
      height: 78,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: days.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (context, i) {
          final x = days[i], on = i == selected;
          return Semantics(
            button: true,
            selected: on,
            label: '${x['day']}',
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => onSelect(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 62,
                decoration: BoxDecoration(
                  color: on ? c.text : c.surface,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(i == 0 ? 'Today' : '${x['day']}',
                      style: OgText.chip.copyWith(color: on ? c.bg : c.text2, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  OgWeatherIcon(weatherKindFrom('${x['sky']}'), size: 22),
                  const SizedBox(height: 2),
                  Text(units.tempText(x['max'] as num?), style: OgText.chip.copyWith(color: on ? c.bg : c.text)),
                ]),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MetricChartPainter extends CustomPainter {
  _MetricChartPainter({
    required this.metric,
    required this.units,
    required this.times,
    required this.values,
    required this.observed,
    required this.nowIdx,
    required this.selected,
    required this.c,
    this.gust,
    this.dirs,
    this.chance,
  });
  final Metric metric;
  final Units units;
  final List<DateTime> times;
  final List<double?> values;
  final List<double?>? gust, dirs, chance;
  final Map<DateTime, double> observed;
  final int nowIdx;
  final int? selected;
  final OratgeColors c;

  static const left = 34.0;

  @override
  void paint(Canvas canvas, Size size) {
    final n = values.length;
    if (n == 0) return;
    final top = metric == Metric.wind ? 22.0 : 10.0, bottom = size.height - 20;
    final w = size.width - left - 8;
    double x(int i) => left + (i + 0.5) / n * w;
    final shown = [
      for (final v in [...values, ...?gust, ...observed.values]) if (v != null) metric.show(v, units),
    ];
    var lo = shown.isEmpty ? 0.0 : shown.reduce(math.min), hi = shown.isEmpty ? 1.0 : shown.reduce(math.max);
    if (metric == Metric.rain || metric == Metric.uv || metric == Metric.wind || metric == Metric.cloud) lo = 0;
    if (metric == Metric.rain) hi = math.max(hi, 2);
    if (metric == Metric.uv) hi = math.max(hi, 6);
    if (metric == Metric.humidity || metric == Metric.cloud) {
      lo = 0;
      hi = 100;
    }
    if (hi - lo < 4 && metric != Metric.rain && metric != Metric.uv) {
      final mid = (hi + lo) / 2;
      lo = mid - 2;
      hi = mid + 2;
    }
    double y(double v) => bottom - (metric.show(v, units) - lo) / (hi - lo) * (bottom - top);
    double yShown(double v) => bottom - (v - lo) / (hi - lo) * (bottom - top);

    // Grid + y labels.
    final grid = Paint()..color = c.line;
    for (var k = 0; k <= 2; k++) {
      final v = lo + (hi - lo) * k / 2;
      final gy = yShown(v);
      canvas.drawLine(Offset(left, gy), Offset(size.width - 8, gy), grid);
      ogText(canvas, v.toStringAsFixed(metric == Metric.rain && hi < 5 ? 1 : 0), left - 6, gy + 4, color: c.text3, size: 10, align: 1);
    }
    // x labels every 6 h.
    for (var i = 0; i < n; i++) {
      if (times[i].hour % 6 == 0) ogText(canvas, times[i].hour.toString().padLeft(2, '0'), x(i), size.height - 4, color: c.text3, size: 10, align: 0.5);
    }
    // UV risk bands.
    if (metric == Metric.uv) {
      for (final (from, to, col) in [(3.0, 6.0, c.sun), (6.0, 8.0, c.heat), (8.0, 20.0, c.warnRed)]) {
        if (from >= hi) continue;
        canvas.drawRect(Rect.fromLTRB(left, yShown(math.min(to, hi)), size.width - 8, yShown(from)), Paint()..color = col.withValues(alpha: 0.07));
      }
    }
    final col = metric.color(c);
    // Now marker.
    if (nowIdx >= 0) {
      canvas.drawLine(Offset(x(nowIdx), top - 6), Offset(x(nowIdx), bottom), Paint()..color = c.text2..strokeWidth = 1);
      ogText(canvas, 'now', x(nowIdx), top - 8, color: c.text2, size: 10, align: 0.5);
    }
    if (metric == Metric.rain) {
      final bw = w / n * 0.7;
      for (var i = 0; i < n; i++) {
        final v = values[i];
        if (v == null || v <= 0) continue;
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTRB(x(i) - bw / 2, y(v), x(i) + bw / 2, bottom), const Radius.circular(2)),
            Paint()..color = col.withValues(alpha: selected == i ? 1 : 0.75));
      }
      // Chance line on its own 0–100 scale.
      if (chance != null) {
        final p = Path();
        var started = false;
        for (var i = 0; i < n; i++) {
          final v = chance![i];
          if (v == null) continue;
          final py = bottom - v / 100 * (bottom - top);
          started ? p.lineTo(x(i), py) : p.moveTo(x(i), py);
          started = true;
        }
        canvas.drawPath(p, Paint()..color = c.text2..style = PaintingStyle.stroke..strokeWidth = 1.5);
      }
    } else {
      // Gust band.
      if (gust != null) {
        final band = Path();
        final pts = [for (var i = 0; i < n; i++) if (values[i] != null && gust![i] != null) i];
        if (pts.isNotEmpty) {
          band.moveTo(x(pts.first), y(gust![pts.first]!));
          for (final i in pts.skip(1)) {
            band.lineTo(x(i), y(gust![i]!));
          }
          for (final i in pts.reversed) {
            band.lineTo(x(i), y(values[i]!));
          }
          band.close();
          canvas.drawPath(band, Paint()..color = col.withValues(alpha: 0.18));
        }
      }
      // Area + line.
      final line = Path(), area = Path();
      var first = -1, last = -1;
      for (var i = 0; i < n; i++) {
        final v = values[i];
        if (v == null) continue;
        if (first < 0) {
          line.moveTo(x(i), y(v));
          area.moveTo(x(i), bottom);
          area.lineTo(x(i), y(v));
          first = i;
        } else {
          line.lineTo(x(i), y(v));
          area.lineTo(x(i), y(v));
        }
        last = i;
      }
      if (first >= 0) {
        area
          ..lineTo(x(last), bottom)
          ..close();
        canvas.drawPath(
            area,
            Paint()
              ..shader = LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [col.withValues(alpha: 0.28), col.withValues(alpha: 0.02)],
              ).createShader(Rect.fromLTRB(0, top, size.width, bottom)));
        canvas.drawPath(line, Paint()..color = col..style = PaintingStyle.stroke..strokeWidth = 2.2..strokeJoin = StrokeJoin.round);
      }
      // Wind direction arrows along the top.
      if (dirs != null) {
        for (var i = 0; i < n; i += 3) {
          final dv = dirs![i];
          if (dv != null) windArrow(canvas, Offset(x(i), 9), dv, c.text2, len: 6, width: 1.5);
        }
      }
    }
    // Measured today (dots).
    for (var i = 0; i < n; i++) {
      final t = times[i];
      final o = observed[DateTime(t.year, t.month, t.day, t.hour)];
      if (o == null) continue;
      if (metric == Metric.rain) continue;
      canvas.drawCircle(Offset(x(i), y(o)), 3.2, Paint()..color = c.text);
      canvas.drawCircle(Offset(x(i), y(o)), 3.2, Paint()..color = c.bg..style = PaintingStyle.stroke..strokeWidth = 1);
    }
    // Selection cursor.
    if (selected != null && selected! < n) {
      final sx = x(selected!);
      canvas.drawLine(Offset(sx, top), Offset(sx, bottom), Paint()..color = c.text..strokeWidth = 1.2);
      final v = values[selected!];
      if (v != null && metric != Metric.rain) canvas.drawCircle(Offset(sx, y(v)), 4.5, Paint()..color = col);
    }
  }

  @override
  bool shouldRepaint(_MetricChartPainter o) =>
      o.selected != selected || o.values != values || o.metric != metric || o.units != units || o.c != c;
}
