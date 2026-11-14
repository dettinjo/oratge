import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/models.dart';
import '../../data/profile.dart';
import '../../data/units.dart';
import '../../data/wing_calc.dart';
import '../../theme/og_helpers.dart';
import '../../theme/oratge_tokens.dart';
import '../components/basics.dart';
import 'common.dart';

/// Which wind your quiver works in, and which wing to take — for "what if" wind and for today's hours.
class WingGearScreen extends StatefulWidget {
  const WingGearScreen({super.key, this.wind, this.gust});
  final double? wind, gust;
  @override
  State<WingGearScreen> createState() => _WingGearScreenState();
}

class _WingGearScreenState extends State<WingGearScreen> {
  late double _wind = widget.wind ?? 16, _gust = widget.gust ?? 21;
  Future<PlannerData>? _today;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _today ??= AppScope.of(context).repository.planner('wing');
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final c = context.og;
    final u = app.units;
    final p = app.profile;
    final g = WingGear.of(p);
    final choice = g.pick(_wind, _gust);
    final color = switch (choice.state) {
      'ok' => c.r4,
      'gap' => c.sun,
      _ => c.warnRed,
    };
    final wingStep = setupSteps.indexWhere((s) => s.id == 'wing') + 1;

    Widget slider(String label, double v, double min, double max, ValueChanged<double> on) => Row(
      children: [
        SizedBox(
          width: 64,
          child: Text(label, style: OgText.chip.copyWith(color: c.text2)),
        ),
        Expanded(
          child: Slider(
            value: v.clamp(min, max),
            min: min,
            max: max,
            divisions: (max - min).round(),
            activeColor: c.wind,
            inactiveColor: c.line,
            label: u.windText(v),
            onChanged: on,
          ),
        ),
        SizedBox(
          width: 72,
          child: Text(
            u.windText(v),
            textAlign: TextAlign.right,
            style: OgText.actName.copyWith(color: c.text),
          ),
        ),
      ],
    );

    return OgPage(
      title: 'Wing gear',
      subtitle: 'Your quiver, your weight, your board and foil',
      back: (label: 'Back to Wing foil', route: '/activities/wing'),
      children: [
        Columns(
          left: [
            OgCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('TRY CONDITIONS', style: OgText.label.copyWith(color: c.text2)),
                  const SizedBox(height: 6),
                  slider(
                    'Wind',
                    _wind,
                    0,
                    40,
                    (v) => setState(() {
                      _wind = v;
                      if (_gust < v) _gust = v;
                    }),
                  ),
                  slider('Gusts', _gust, 0, 50, (v) => setState(() => _gust = math.max(v, _wind))),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          choice.state == 'ok' ? 'Take your ${choice.text}' : choice.text,
                          style: OgText.verdictBest.copyWith(color: c.text, fontSize: 22),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const OgSectionLabel('Your quiver'),
            OgCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 34.0 * g.wings.length + 40,
                    child: CustomPaint(
                      size: Size.infinite,
                      painter: _QuiverPainter(
                        g,
                        _wind,
                        _gust,
                        double.tryParse('${p['windFrom']}'),
                        double.tryParse('${p['windTo']}'),
                        u,
                        c,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Bars: from the wind that gets you foiling to the gusts you still control. Shaded: your wind range from setup. '
                    'Line: wind; dashed: gusts.',
                    style: OgText.src.copyWith(color: c.text2),
                  ),
                  if (double.tryParse('${p['windFrom']}') case final from? when from < g.minWind - 1) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Your wind range starts at ${u.windText(from)}, but your gear needs about ${u.windText(g.minWind)}.',
                      style: OgText.chip.copyWith(color: c.sun, fontSize: 13),
                    ),
                  ],
                ],
              ),
            ),
          ],
          right: [
            const OgSectionLabel('Today at Castelldefels', top: 4),
            FutureBuilder<PlannerData>(
              future: _today,
              builder: (context, snap) {
                final d = snap.data;
                if (d == null) {
                  return OgCard(
                    child: Text(
                      snap.hasError ? 'No forecast right now.' : 'Loading…',
                      style: OgText.chip.copyWith(color: c.text2),
                    ),
                  );
                }
                final rows = {for (final r in d.hourChart['rows'] as List) r['label']: r};
                final hours = [for (final h in d.hourChart['hours'] as List) (h as num).toInt()];
                List<double> vals(String k) => [
                  for (final v in ((rows[k] as Map?)?['values'] as List? ?? const [])) (v as num).toDouble(),
                ];
                final wind = vals('Wind'), gust = vals('Gust');
                return OgCard(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Column(
                    children: [
                      for (var i = 0; i < math.min(hours.length, math.min(wind.length, gust.length)); i++)
                        InkWell(
                          onTap: () => setState(() {
                            _wind = wind[i];
                            _gust = math.max(gust[i], wind[i]);
                          }),
                          child: Container(
                            constraints: const BoxConstraints(minHeight: 40),
                            decoration: BoxDecoration(
                              border: i == 0 ? null : Border(top: BorderSide(color: c.line)),
                            ),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 48,
                                  child: Text(
                                    '${hours[i].toString().padLeft(2, '0')} h',
                                    style: OgText.day.copyWith(color: c.text2),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    '${u.windText(wind[i])} · gusts ${u.windText(gust[i], unit: false)}',
                                    style: OgText.day.copyWith(color: c.text),
                                  ),
                                ),
                                _ChoiceChip(g.pick(wind[i], gust[i]), c),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
            const OgSectionLabel('How it’s estimated'),
            OgCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _line(c, 'Weight ${g.weight.round()} kg', '${g.parts['base']} kn', 'base for a 5 m wing'),
                  _line(
                    c,
                    'Board ${g.board.round()} l (${(g.board / g.weight).toStringAsFixed(2)} l/kg)',
                    _signed(g.parts['board']!),
                    'floaty boards pump up earlier',
                  ),
                  _line(c, 'Front wing ${g.frontWing.round()} cm²', _signed(g.parts['foil']!), 'bigger foils lift earlier'),
                  _line(c, 'Level: ${g.level.toLowerCase()}', _signed(g.parts['level']!), 'learning needs more power'),
                  Divider(color: c.line),
                  Text(
                    'Other wing sizes: the minimum scales with √(5 ÷ size), because a wing’s pull grows with its area and the square of the wind. '
                    'Gust limit: about 31 kn on a 4 m at 75 kg, a little more for heavier riders. '
                    'These are rules of thumb; once the station check runs, they can be compared with real wind.',
                    style: OgText.src.copyWith(color: c.text2),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    style: TextButton.styleFrom(padding: EdgeInsets.zero, foregroundColor: c.text),
                    onPressed: () => context.go('/setup/$wingStep'),
                    child: const Text('Edit your gear ›'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  static String _signed(double v) => v == 0 ? '±0 kn' : '${v > 0 ? '+' : '−'}${v.abs().toStringAsFixed(1)} kn';

  Widget _line(OratgeColors c, String what, String value, String why) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(what, style: OgText.day.copyWith(color: c.text)),
              Text(why, style: OgText.chip.copyWith(color: c.text3)),
            ],
          ),
        ),
        Text(value, style: OgText.actName.copyWith(color: c.text)),
      ],
    ),
  );
}

class _ChoiceChip extends StatelessWidget {
  const _ChoiceChip(this.ch, this.c);
  final WingChoice ch;
  final OratgeColors c;
  @override
  Widget build(BuildContext context) {
    final (bg, label) = switch (ch.state) {
      'ok' => (c.r4, WingGear.label(ch.size)),
      'gap' => (c.sun, '${WingGear.label(ch.size)}?'),
      'under' => (c.text3, 'too light'),
      _ => (c.warnRed, 'too strong'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(color: bg.withValues(alpha: 0.22), borderRadius: BorderRadius.circular(999)),
      child: Text(
        label,
        style: OgText.chip.copyWith(color: c.text, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _QuiverPainter extends CustomPainter {
  _QuiverPainter(this.g, this.wind, this.gust, this.from, this.to, this.u, this.c);
  final WingGear g;
  final double wind, gust;
  final double? from, to;
  final Units u;
  final OratgeColors c;

  static const maxKn = 45.0, left = 46.0;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width - left - 8;
    double x(double kn) => left + (kn.clamp(0, maxKn) / maxKn) * w;
    final bottom = size.height - 20;
    // Your range.
    if (from != null && to != null) {
      canvas.drawRect(Rect.fromLTRB(x(from!), 0, x(to!), bottom), Paint()..color = c.wind.withValues(alpha: 0.08));
    }
    // Axis.
    for (var kn = 0.0; kn <= maxKn; kn += 10) {
      canvas.drawLine(Offset(x(kn), 0), Offset(x(kn), bottom), Paint()..color = c.line);
      ogText(canvas, u.windText(kn, unit: false), x(kn), size.height - 4, color: c.text3, size: 10, align: 0.5);
    }
    ogText(canvas, u.windUnit(), size.width - 8, size.height - 4, color: c.text3, size: 10, align: 1);
    // Wings, biggest at the top.
    final wings = [...g.wings]..sort((a, b) => b.size.compareTo(a.size));
    for (final (i, r) in wings.indexed) {
      final y = 10 + i * 34.0;
      final ok = r.low <= wind && r.high >= gust;
      ogText(canvas, WingGear.label(r.size), 0, y + 13, color: c.text, size: 13, weight: FontWeight.w600);
      final rect = RRect.fromRectAndRadius(Rect.fromLTRB(x(r.low), y, x(r.high), y + 18), const Radius.circular(9));
      canvas.drawRRect(
        rect,
        Paint()
          ..shader = LinearGradient(colors: [c.wind2, c.wind4]).createShader(rect.outerRect)
          ..color = Colors.white.withValues(alpha: ok ? 1 : 0.45),
      );
      if (ok) {
        canvas.drawRRect(
          rect,
          Paint()
            ..color = c.text
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
      }
    }
    // Wind and gust markers.
    canvas.drawLine(
      Offset(x(wind), 0),
      Offset(x(wind), bottom),
      Paint()
        ..color = c.text
        ..strokeWidth = 2,
    );
    for (var yy = 0.0; yy < bottom; yy += 6) {
      canvas.drawLine(
        Offset(x(gust), yy),
        Offset(x(gust), math.min(yy + 3, bottom)),
        Paint()
          ..color = c.text2
          ..strokeWidth = 1.5,
      );
    }
  }

  @override
  bool shouldRepaint(_QuiverPainter o) => o.wind != wind || o.gust != gust || o.g != g || o.c != c;
}
