import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show ValueListenable, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart' show LatLng;

import '../../data/activities.dart';
import '../../data/models.dart';
import '../../data/profile.dart';
import '../../data/units.dart';
import '../../theme/og_helpers.dart';
import '../../theme/oratge_tokens.dart';
import '../components/basics.dart';
import '../components/og_map.dart';
import '../components/rows_cards.dart';
import '../components/scrub.dart';
import '../components/weather_icon.dart';
import 'common.dart';

bool get _inTest => !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');

/// Weather along a GPX route at the time you'd pass each point: where and when it rains, head/tailwind,
/// how it feels, thunder, darkness — and which start time works best that day.
class RouteScreen extends StatefulWidget {
  const RouteScreen({super.key, required this.id});
  final String id;
  @override
  State<RouteScreen> createState() => _RouteScreenState();
}

class _RouteScreenState extends State<RouteScreen> {
  String? _start; // HH:MM override from the start-time chips
  String _color = 'rain';
  final _sel = ValueNotifier<int?>(null); // chart position, shown on the map

  @override
  void dispose() {
    _sel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final c = context.og;
    final a = app.activity(widget.id);
    if (a == null) {
      return OgPage(title: 'Route', back: (label: 'Back', route: '/activities'), children: [
        Text('This route was removed.', style: OgText.day.copyWith(color: c.text2)),
      ]);
    }
    final base = a.startAt(DateTime.now());
    final start = _start == null
        ? base
        : DateTime(base.year, base.month, base.day, int.parse(_start!.substring(0, 2)), int.parse(_start!.substring(3, 5)));
    return AsyncView<Json>(
      key: ValueKey('route-${a.id}-${start.toIso8601String()}'),
      load: () => app.repository.route(a, start: start),
      builder: (context, d) => _body(context, app, a, d, start),
    );
  }

  Widget _body(BuildContext context, AppState app, Activity a, Json d, DateTime start) {
    final c = context.og;
    final u = app.units;
    final rows = [for (final r in d['samples'] as List) Map<String, dynamic>.from(r as Map)];
    final ok = rows.where((r) => r['missing'] != true).toList();
    final sum = Map<String, dynamic>.from(d['summary'] as Map);
    final lines = [for (final l in sum['lines'] as List) '$l'];
    final dur = (d['duration_h'] as num).toDouble();
    final finish = start.add(Duration(minutes: (dur * 60).round()));
    String hm(DateTime t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    const wd = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final options = [for (final o in d['start_options'] as List) Map<String, dynamic>.from(o as Map)];
    final bestStart = d['best_start'] as String?;
    final scores = options.map((o) => (o['score'] as num).toDouble()).toList();
    final hiS = scores.isEmpty ? 0.0 : scores.reduce(math.max), loS = scores.isEmpty ? -1.0 : scores.reduce(math.min);

    return OgPage(
      title: a.name,
      subtitle: '${sportNames[a.sport]} · ${wd[start.weekday - 1]} ${start.day}/${start.month} · ${hm(start)}–${hm(finish)}',
      back: (label: 'Back', route: '/activities'),
      headerExtra: Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          style: TextButton.styleFrom(foregroundColor: c.text2),
          onPressed: () => context.push('/activities/edit/${a.id}'),
          icon: const Icon(Icons.edit_outlined, size: 18),
          label: const Text('Edit route'),
        ),
      ),
      children: [
        Columns(left: [
          OgCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  child: Text('${(d['distance_km'] as num).toStringAsFixed(1)} km · ↑ ${d['ascent_m']} m · ${dur.floor()} h ${((dur % 1) * 60).round()} min',
                      style: OgText.actName.copyWith(color: c.text2)),
                ),
                OgRatingDots(value: (sum['rating'] as num?) ?? 0, large: true),
              ]),
              const SizedBox(height: 10),
              for (final (i, l) in lines.indexed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 5, right: 8),
                      child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                              color: l.startsWith('Rain') || l.startsWith('Thunder')
                                  ? c.water
                                  : (l.startsWith('Headwind') ? c.wind : (l.startsWith('Dark') ? c.text3 : c.r4)),
                              shape: BoxShape.circle)),
                    ),
                    Expanded(
                        child: Text(u.convert(l),
                            style: (i == 0 ? OgText.verdictSummary : OgText.day).copyWith(color: c.text, fontWeight: i == 0 ? FontWeight.w600 : null))),
                  ]),
                ),
            ]),
          ),
          const OgSectionLabel('Start time'),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              for (final o in options)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text('${o['start']}${o['start'] == bestStart ? ' ★' : ''}'),
                    selected: o['start'] == hm(start),
                    showCheckmark: false,
                    selectedColor: c.text,
                    backgroundColor: Color.lerp(c.warnRed, c.r4, hiS == loS ? 1 : (((o['score'] as num) - loS) / (hiS - loS)).toDouble())!
                        .withValues(alpha: 0.22),
                    labelStyle: OgText.chip.copyWith(color: o['start'] == hm(start) ? c.bg : c.text),
                    onSelected: (_) => setState(() => _start = '${o['start']}'),
                  ),
                ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(bestStart == null ? '' : 'Best start that day: $bestStart (least rain, headwind, thunder and darkness).',
                style: OgText.chip.copyWith(color: c.text2)),
          ),
          const OgSectionLabel('Along the route'),
          OgCard(
            child: Scrub(
              count: ok.length,
              indexAt: (dx, w) {
                if (ok.isEmpty) return null;
                final kmMax = (ok.last['km'] as num).toDouble();
                final k = ((dx - 8) / (w - 16)).clamp(0.0, 1.0) * kmMax;
                var best = 0;
                for (var i = 1; i < ok.length; i++) {
                  if (((ok[i]['km'] as num) - k).abs() < ((ok[best]['km'] as num) - k).abs()) best = i;
                }
                return best;
              },
              chart: (sel) {
                if (_sel.value != sel) WidgetsBinding.instance.addPostFrameCallback((_) => _sel.value = sel);
                return SizedBox(height: 190, child: CustomPaint(size: Size.infinite, painter: _ProfilePainter(ok, sel, c, u)));
              },
              readout: (i, c) {
                final r = ok[i];
                final head = (r['head'] as num).toDouble();
                return (
                  'km ${(r['km'] as num).toStringAsFixed(0)} · ${r['eta']}',
                  [
                    ReadoutItem('feels', u.tempText(r['feels'] as num), color: c.heat),
                    ReadoutItem('rain', '${(r['precip'] as num).toStringAsFixed(1)} mm · ${r['pprob']} %', color: c.water),
                    ReadoutItem(head >= 0 ? 'headwind' : 'tailwind', u.windText(head.abs()), color: c.wind),
                    if ((r['storm'] as num) >= 30) ReadoutItem('thunder', '${r['storm']} %', color: c.storm),
                    if (r['ele'] != null) ReadoutItem('', '${r['ele']} m'),
                  ]
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text('Grey: elevation · blue bars: rain when you pass · green above/below the line: tail/headwind.',
                style: OgText.src.copyWith(color: c.text2)),
          ),
        ], right: [
          const OgSectionLabel('Map', top: 4),
          Wrap(spacing: 6, children: [
            for (final (k, l) in const [('rain', 'Rain'), ('wind', 'Head/tailwind'), ('temp', 'Feels like')])
              ChoiceChip(
                label: Text(l),
                selected: _color == k,
                showCheckmark: false,
                selectedColor: c.text,
                backgroundColor: c.surface,
                labelStyle: OgText.chip.copyWith(color: _color == k ? c.bg : c.text),
                onSelected: (_) => setState(() => _color = k),
              ),
          ]),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(OgRadius.card),
            child: SizedBox(height: 320, child: _inTest ? ColoredBox(color: c.surface) : _RouteMap(a: a, rows: ok, color: _color, sel: _sel)),
          ),
          const OgSectionLabel('Checkpoints'),
          OgCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: Column(children: [
              for (final (i, r) in _every(ok, 5).indexed)
                Container(
                  constraints: const BoxConstraints(minHeight: 42),
                  decoration: BoxDecoration(border: i == 0 ? null : Border(top: BorderSide(color: c.line))),
                  child: Row(children: [
                    SizedBox(width: 56, child: Text('km ${(r['km'] as num).round()}', style: OgText.chip.copyWith(color: c.text2))),
                    SizedBox(width: 48, child: Text('${r['eta']}', style: OgText.day.copyWith(color: c.text))),
                    OgWeatherIcon(weatherKindFrom('${r['sky']}'), size: 20),
                    const SizedBox(width: 8),
                    SizedBox(width: 40, child: Text(u.tempText(r['feels'] as num), style: OgText.day.copyWith(color: c.text))),
                    Expanded(
                      child: Text(
                          '${(r['pprob'] as num) >= 30 ? '${r['pprob']} % ' : ''}${(r['head'] as num) >= 4 ? 'head ${u.windText(r['head'] as num)}' : ((r['head'] as num) <= -4 ? 'tail ${u.windText(-(r['head'] as num))}' : '')}',
                          style: OgText.chip.copyWith(color: c.text2),
                          overflow: TextOverflow.ellipsis),
                    ),
                  ]),
                ),
            ]),
          ),
          OgDataSources('Open-Meteo hourly forecast at each point, at the time you pass it; elevation from the GPX or Copernicus DEM.'),
        ]),
      ],
    );
  }

  /// One row roughly every [stepKm] km, plus the finish.
  static List<Map<String, dynamic>> _every(List<Map<String, dynamic>> rows, double stepKm) {
    final out = <Map<String, dynamic>>[];
    var next = 0.0;
    for (final r in rows) {
      if ((r['km'] as num) >= next) {
        out.add(r);
        next = (r['km'] as num) + stepKm;
      }
    }
    if (rows.isNotEmpty && out.last != rows.last) out.add(rows.last);
    return out;
  }
}

class _ProfilePainter extends CustomPainter {
  _ProfilePainter(this.rows, this.sel, this.c, this.u);
  final List<Map<String, dynamic>> rows;
  final int? sel;
  final OratgeColors c;
  final Units u;

  @override
  void paint(Canvas canvas, Size size) {
    if (rows.length < 2) return;
    final kmMax = (rows.last['km'] as num).toDouble();
    double x(num km) => 8 + (km / (kmMax == 0 ? 1 : kmMax)) * (size.width - 16);
    final top = 14.0, mid = size.height * 0.55, bottom = size.height - 18;
    // Elevation area (upper part).
    final eles = [for (final r in rows) (r['ele'] as num?)?.toDouble() ?? 0];
    final lo = eles.reduce(math.min), hi = math.max(eles.reduce(math.max), lo + 50);
    double ye(double e) => mid - (e - lo) / (hi - lo) * (mid - top);
    final area = Path()..moveTo(x(rows.first['km'] as num), mid);
    for (final (i, r) in rows.indexed) {
      area.lineTo(x(r['km'] as num), ye(eles[i]));
    }
    area
      ..lineTo(x(rows.last['km'] as num), mid)
      ..close();
    canvas.drawPath(area, Paint()..color = c.text3.withValues(alpha: 0.35));
    ogText(canvas, '${hi.round()} m', 8, top - 2, color: c.text3, size: 10);
    // Rain bars (lower part, probability as height, colour by mm).
    final bw = math.max(2.0, (size.width - 16) / rows.length * 0.7);
    for (final r in rows) {
      final p = (r['pprob'] as num).toDouble() / 100;
      if (p < 0.1) continue;
      final mm = (r['precip'] as num).toDouble();
      final h = p * (bottom - mid - 6);
      canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(x(r['km'] as num) - bw / 2, bottom - h, bw, h), const Radius.circular(2)),
          Paint()..color = Color.lerp(c.water.withValues(alpha: 0.35), c.water, (mm / 2).clamp(0, 1))!);
      if ((r['storm'] as num) >= 30) {
        ogText(canvas, '⚡', x(r['km'] as num), bottom - h - 2, color: c.storm, size: 11, align: 0.5);
      }
    }
    // Head/tailwind line across the middle band: above = tailwind (helps), below = headwind.
    final band = (mid + bottom) / 2;
    final wind = Path();
    for (final (i, r) in rows.indexed) {
      final y = band + ((r['head'] as num).toDouble().clamp(-20, 20)) * 1.2;
      i == 0 ? wind.moveTo(x(r['km'] as num), y) : wind.lineTo(x(r['km'] as num), y);
    }
    canvas.drawLine(Offset(8, band), Offset(size.width - 8, band), Paint()..color = c.line);
    canvas.drawPath(wind, Paint()..color = c.wind..style = PaintingStyle.stroke..strokeWidth = 2);
    // km labels.
    for (var k = 0.0; k <= kmMax; k += kmMax > 60 ? 20 : (kmMax > 20 ? 10 : 5)) {
      ogText(canvas, '${k.round()}', x(k), size.height - 4, color: c.text3, size: 10, align: 0.5);
    }
    if (sel != null && sel! < rows.length) {
      final sx = x(rows[sel!]['km'] as num);
      canvas.drawLine(Offset(sx, top), Offset(sx, bottom), Paint()..color = c.text..strokeWidth = 1.2);
    }
  }

  @override
  bool shouldRepaint(_ProfilePainter o) => o.sel != sel || o.rows != rows || o.c != c;
}

class _RouteMap extends StatelessWidget {
  const _RouteMap({required this.a, required this.rows, required this.color, required this.sel});
  final Activity a;
  final List<Map<String, dynamic>> rows;
  final String color;
  final ValueListenable<int?> sel;

  Color _segColor(OratgeColors c, Map<String, dynamic> r) {
    switch (color) {
      case 'wind':
        final h = (r['head'] as num).toDouble();
        return h >= 0 ? Color.lerp(c.r4, c.warnRed, (h / 15).clamp(0, 1))! : c.r4;
      case 'temp':
        final f = (r['feels'] as num).toDouble();
        return Color.lerp(c.water, c.heat, ((f - 0) / 30).clamp(0, 1))!;
      default:
        final wet = (r['precip'] as num) >= 0.2 || (r['pprob'] as num) >= 60;
        final maybe = (r['pprob'] as num) >= 30;
        return wet ? c.water : (maybe ? Color.lerp(c.r4, c.water, 0.5)! : c.r4);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.og;
    final pts = [for (final p in a.track) LatLng(p[0]!, p[1]!)];
    if (pts.length < 2) return const SizedBox.shrink();
    // Colour each piece of the track by the nearest analysed sample.
    final kmAt = <double>[0];
    for (var i = 1; i < pts.length; i++) {
      kmAt.add(kmAt.last + haversineKm(pts[i - 1].latitude, pts[i - 1].longitude, pts[i].latitude, pts[i].longitude));
    }
    Map<String, dynamic> sampleAt(double km) => rows.reduce((p, q) => ((p['km'] as num) - km).abs() <= ((q['km'] as num) - km).abs() ? p : q);
    final lines = <Polyline>[];
    for (var i = 1; i < pts.length; i++) {
      lines.add(Polyline(points: [pts[i - 1], pts[i]], strokeWidth: 5, color: rows.isEmpty ? c.text : _segColor(c, sampleAt(kmAt[i]))));
    }
    final rainEdges = <Marker>[];
    if (color == 'rain') {
      bool wet(Map<String, dynamic> r) => (r['precip'] as num) >= 0.2 || (r['pprob'] as num) >= 60;
      for (var i = 1; i < rows.length; i++) {
        if (wet(rows[i]) != wet(rows[i - 1])) {
          final r = rows[i];
          rainEdges.add(Marker(
            point: LatLng((r['lat'] as num).toDouble(), (r['lon'] as num).toDouble()),
            width: 64,
            height: 26,
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(color: c.bg.withValues(alpha: 0.9), borderRadius: BorderRadius.circular(999)),
              child: Text('${wet(r) ? '☂' : '☀'} ${r['eta']}', style: OgText.chip.copyWith(color: c.text, fontSize: 11)),
            ),
          ));
        }
      }
    }
    return FlutterMap(
      options: MapOptions(
        initialCameraFit: CameraFit.coordinates(coordinates: pts, padding: const EdgeInsets.all(28)),
        interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
        backgroundColor: c.bg,
      ),
      children: [
        oratgeTiles(context),
        PolylineLayer(polylines: lines),
        MarkerLayer(markers: [
          Marker(point: pts.first, width: 16, height: 16, child: Container(decoration: BoxDecoration(color: c.r4, shape: BoxShape.circle, border: Border.all(color: c.bg, width: 3)))),
          Marker(point: pts.last, width: 16, height: 16, child: Container(decoration: BoxDecoration(color: c.text, shape: BoxShape.circle, border: Border.all(color: c.bg, width: 3)))),
          ...rainEdges,
        ]),
        ValueListenableBuilder<int?>(
          valueListenable: sel,
          builder: (context, i, _) {
            if (i == null || i >= rows.length) return const SizedBox.shrink();
            final s = rows[i];
            return MarkerLayer(markers: [
              Marker(
                  point: LatLng((s['lat'] as num).toDouble(), (s['lon'] as num).toDouble()),
                  width: 20,
                  height: 20,
                  child: Container(decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: c.text, width: 3)))),
            ]);
          },
        ),
      ],
    );
  }
}
