import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/models.dart';
import '../../data/profile.dart';
import '../../data/wing_calc.dart';
import '../../theme/og_helpers.dart';
import '../../theme/oratge_tokens.dart';
import '../components/basics.dart';
import '../components/blocks.dart';
import '../components/rows_cards.dart';
import '../components/sheets.dart';
import 'common.dart';
import '../components/modules.dart';

/// Daily planner for one sport: answer → key numbers → hour chart → advice → method (collapsed).
class PlannerScreen extends StatefulWidget {
  const PlannerScreen({super.key, required this.sport});
  final String sport;

  @override
  State<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends State<PlannerScreen> {
  int _day = 0;
  String? _chip;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final layout = ScreenLayout('planner', plannerModules, app);
    return AsyncView<PlannerData>(
      key: ValueKey('${widget.sport}-$_day'),
      load: () => app.repository.planner(widget.sport, day: _day),
      builder: (context, d) {
        return OgPage(
          title: d.title,
          subtitle: d.date,
          back: (label: 'Back to Activities', route: '/activities'),
          children: [
            Row(
              children: [
                Expanded(
                  child: OgDayTabs(
                    days: [for (final t in d.days) (weekday: t.weekday, date: t.date, rating: t.rating, outlook: t.outlook)],
                    selected: _day,
                    onSelect: (i) => setState(() => _day = i),
                  ),
                ),
                const SizedBox(width: 8),
                CustomiseButton(layout: layout, compact: true),
              ],
            ),
            const SizedBox(height: 14),
            ModuleGrid(layout: layout, builder: (context, def, size) => _module(context, def.id, size, d)),
            OgDataSources(d.sources),
          ],
        );
      },
    );
  }

  static bool _isMeteocat(LabeledBlocks v) => (v.label ?? '').startsWith('Meteocat') || (v.label ?? '').startsWith('Lightning');

  Widget? _module(BuildContext context, String id, ModuleSize size, PlannerData d) {
    final c = context.og;
    final minimal = size == ModuleSize.minimal;
    final v = d.verdict;
    Widget section(String? label, Widget child) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null && label.isNotEmpty) ...[
          Text(label.toUpperCase(), style: OgText.label.copyWith(color: c.text2)),
          const SizedBox(height: 8),
        ],
        child,
      ],
    );
    switch (id) {
      case 'verdict':
        if (minimal) {
          return ValueTile(
            icon: Icons.emoji_events_outlined,
            label: 'Verdict · ${(v['rating'] as num).toInt()} of 5',
            value: '${v['best']}',
            sub: '${v['summary']}',
            minHeight: 0,
            onTap: () => showVerdictSheet(context, v, d.analysis),
          );
        }
        return Semantics(
          button: true,
          label: 'Verdict: ${v['best']}. Show how the rating is made',
          child: InkWell(
            borderRadius: BorderRadius.circular(OgRadius.card),
            onTap: () => showVerdictSheet(context, v, d.analysis),
            child: OgVerdictCard(
              rating: (v['rating'] as num).toInt(),
              best: '${v['best']}',
              summary: '${v['summary']}',
              confidence: v['confidence'] as String?,
            ),
          ),
        );
      case 'facts':
        final facts = minimal ? d.keyFacts.take(2).toList() : d.keyFacts;
        return section(
          d.keyLabel,
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              factsGrid(
                facts,
                onTap: (f) => showFactSheet(context, f, series: seriesFromHourChart(d.hourChart, f), source: d.sources),
              ),
              if (d.chip != null && !minimal) ...[
                const SizedBox(height: 12),
                OgChipGroup(
                  label: d.chip!['label'] as String?,
                  options: strs(d.chip!['options']),
                  selected: _chip ?? '${d.chip!['selected']}',
                  onSelect: (o) => setState(() => _chip = o),
                ),
              ],
            ],
          ),
        );
      case 'hours':
        return section(
          'Hour by hour',
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(d.takeaway, style: OgText.verdictSummary.copyWith(color: c.text)),
              if (!minimal) ...[
                const SizedBox(height: 8),
                OgCard(
                  padding: const EdgeInsets.fromLTRB(12, 12, 10, 10),
                  child: interactiveHourChart(d.hourChart, semanticLabel: d.takeaway),
                ),
              ],
            ],
          ),
        );
      case 'gear':
        if (widget.sport != 'wing') return null;
        // The best-rated hours of the day (or all of them) decide which wing to take.
        final rows = {for (final r in d.hourChart['rows'] as List) r['label']: r};
        List<double> vals(String k) => [
          for (final v in ((rows[k] as Map?)?['values'] as List? ?? const [])) (v as num).toDouble(),
        ];
        final wind = vals('Wind'), gust = vals('Gust'), rating = vals('Rating');
        if (wind.isEmpty || gust.isEmpty) return null;
        final top = rating.isEmpty ? 0.0 : rating.reduce(math.max);
        final idx = [
          for (var i = 0; i < math.min(wind.length, gust.length); i++)
            if (top == 0 || (i < rating.length && rating[i] == top)) i,
        ];
        final w = idx.map((i) => wind[i]).reduce(math.max), g = idx.map((i) => gust[i]).reduce(math.max);
        final gear = WingGear.of(AppScope.of(context).profile);
        final ch = gear.pick(w, g);
        final u = AppScope.of(context).units;
        return ValueTile(
          icon: Icons.sailing_outlined,
          label: 'Wing gear',
          value: ch.state == 'ok' ? 'Take your ${ch.text}' : ch.text,
          sub: '${top > 0 ? 'Best hours' : 'Today'}: ${u.windText(w)}, gusts ${u.windText(g, unit: false)}',
          color: ch.state == 'ok' ? null : c.sun,
          extra: minimal
              ? null
              : [for (final r in gear.wings) '${WingGear.label(r.size)}: ${u.windText(r.low, unit: false)}–${u.windText(r.high)}']
                    .join(' · '),
          onTap: () => context.go('/activities/wing/gear?wind=${w.toStringAsFixed(0)}&gust=${g.toStringAsFixed(0)}'),
        );
      case 'tuned':
        if (d.tuned.isEmpty) return null;
        return section('Tuned to you', _Tuned(minimal ? d.tuned.take(1).toList() : d.tuned));
      case 'spot':
        final vis = d.visuals.where((x) => !_isMeteocat(x)).toList();
        if (vis.isEmpty) return null;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final (i, x) in (minimal ? vis.take(1) : vis).indexed) ...[
              if (i > 0) const SizedBox(height: 16),
              section(x.label, OgCard(child: blockGroup(x.blocks, label: x.label))),
            ],
          ],
        );
      case 'meteocat':
        final vis = d.visuals.where(_isMeteocat).toList();
        if (vis.isEmpty) return null;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final (i, x) in (minimal ? vis.take(1) : vis).indexed) ...[
              if (i > 0) const SizedBox(height: 16),
              section(x.label, OgCard(child: blockGroup(x.blocks, label: x.label))),
            ],
          ],
        );
      case 'plan':
        if (d.planFacts.isEmpty) return null;
        return section(
          d.planLabel ?? 'Plan',
          factsGrid(
            minimal ? d.planFacts.take(2).toList() : d.planFacts,
            onTap: (f) => showFactSheet(context, f, series: seriesFromHourChart(d.hourChart, f), source: d.sources),
          ),
        );
      case 'outlook':
        if (d.outlook == null) return null;
        return section(d.outlookLabel ?? 'Next 3 days', OgCard(child: renderBlock(d.outlook!, semanticLabel: d.outlookLabel)));
      case 'analysis':
        if (d.analysis == null) return null;
        return _AnalysisSection(d.analysis!);
    }
    return null;
  }
}

/// Planner modules in their default order.
const plannerModules = <ModuleDef>[
  ModuleDef('verdict', 'Verdict', Icons.emoji_events_outlined, wide: true),
  ModuleDef('facts', 'Key numbers', Icons.grid_view, wide: true),
  ModuleDef('hours', 'Hour by hour', Icons.schedule, wide: true),
  ModuleDef('gear', 'Wing gear', Icons.sailing_outlined, wide: true, hint: 'Wing foil: which wing to take, from your quiver'),
  ModuleDef('tuned', 'Tuned to you', Icons.tune, wide: true),
  ModuleDef('spot', 'At the spot', Icons.place_outlined, wide: true, hint: 'Live wind, route, swell window, altitude'),
  ModuleDef(
    'meteocat',
    'Meteocat forecast',
    Icons.analytics_outlined,
    wide: true,
    hint: 'Beach or summit forecast and lightning',
  ),
  ModuleDef('plan', 'Plan', Icons.checklist, wide: true),
  ModuleDef('outlook', 'Next 3 days', Icons.date_range, wide: true, sizes: {ModuleSize.detailed}),
  ModuleDef('analysis', 'How this forecast was made', Icons.science_outlined, wide: true, sizes: {ModuleSize.detailed}),
];

class _Tuned extends StatelessWidget {
  const _Tuned(this.items);
  final List<({String from, String effect})> items;

  @override
  Widget build(BuildContext context) {
    final c = context.og;
    return OgCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (i, t) in items.indexed)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                border: i == items.length - 1 ? null : Border(bottom: BorderSide(color: c.line)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.from, style: OgText.chip.copyWith(color: c.text2)),
                  const SizedBox(height: 2),
                  Text(t.effect, style: OgText.actName.copyWith(color: c.text)),
                ],
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(44, 44)),
              onPressed: () => context.go('/profile'),
              child: Text(
                'Edit your setup ›',
                style: OgText.day.copyWith(color: c.text, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "How this forecast was made" — collapsed by default (method last).
class _AnalysisSection extends StatelessWidget {
  const _AnalysisSection(this.a);
  final Analysis a;

  @override
  Widget build(BuildContext context) {
    final c = context.og;
    return Padding(
      padding: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: Material(
          color: c.surface,
          borderRadius: BorderRadius.circular(OgRadius.card),
          clipBehavior: Clip.antiAlias,
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            iconColor: c.text2,
            collapsedIconColor: c.text2,
            title: Text('How this forecast was made', style: OgText.actWindow.copyWith(color: c.text)),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Wrap(spacing: 6, runSpacing: 6, children: [for (final s in a.summary) OgPill(s)]),
            ),
            children: [
              _ModelAgreement(a),
              OgSectionLabel('Why ${a.rating} of 5'),
              _Factors(a),
              if (a.ensembleChart != null) ...[
                OgSectionLabel(a.ensembleLabel ?? 'Ensemble'),
                OgCard(
                  raised: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(a.ensembleIntro ?? '', style: OgText.src.copyWith(color: c.text2)),
                      const SizedBox(height: 10),
                      interactiveHourChart(a.ensembleChart!, semanticLabel: a.ensembleLabel),
                    ],
                  ),
                ),
              ],
              if (a.stationTrend != null) ...[
                OgSectionLabel(a.stationTitle ?? 'Station check'),
                OgCard(
                  raised: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      interactiveTrend(a.stationTrend!, semanticLabel: a.stationNote),
                      const SizedBox(height: 6),
                      Text(a.stationLegend ?? '', style: OgText.src.copyWith(color: c.text2)),
                      const SizedBox(height: 6),
                      Text(a.stationNote ?? '', style: OgText.chip.copyWith(color: c.text, fontSize: 13)),
                      const SizedBox(height: 10),
                      factsGrid(a.stationTiles, columns: 3, onTap: (f) => showFactSheet(context, f)),
                    ],
                  ),
                ),
              ] else ...[
                const OgSectionLabel('Station check'),
                Text(
                  'Starts once Oratge has archived 7 days of forecasts and station readings for this spot.',
                  style: OgText.chip.copyWith(color: c.text2, fontSize: 13),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ModelAgreement extends StatelessWidget {
  const _ModelAgreement(this.a);
  final Analysis a;

  @override
  Widget build(BuildContext context) {
    final c = context.og;
    final lo = a.scale[0], hi = a.scale[1];
    double pos(num v) => ((v - lo) / (hi - lo)).clamp(0.0, 1.0).toDouble();
    final accent = a.unit == 'm' ? c.water : (a.unit == 'mm' ? c.water : (a.unit == '°' ? c.heat : c.wind));
    String fmt(num v) => v is int || v == v.roundToDouble() ? '${v.round()}' : '$v';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OgSectionLabel(a.modelTitle, top: 4),
        OgCard(
          raised: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('model', style: OgText.src.copyWith(color: c.text2)),
                  const Spacer(),
                  Text('blend', style: OgText.src.copyWith(color: c.text2)),
                  const Spacer(),
                  Text('scale ${fmt(lo)}–${fmt(hi)} ${a.unit}', style: OgText.src.copyWith(color: c.text2)),
                ],
              ),
              for (final m in a.models)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: c.line)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 13,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              m.name,
                              style: OgText.day.copyWith(fontWeight: FontWeight.w500, color: c.text),
                            ),
                            Text('${m.detail} · weight ${m.weight} %', style: OgText.chip.copyWith(color: c.text2)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 20,
                        child: LayoutBuilder(
                          builder: (context, b) {
                            final w = b.maxWidth;
                            return SizedBox(
                              height: 16,
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Positioned(
                                    left: 0,
                                    right: 0,
                                    top: 4,
                                    height: 8,
                                    child: Container(
                                      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(4)),
                                    ),
                                  ),
                                  Positioned(
                                    left: pos(a.blend) * w - 1,
                                    top: 0,
                                    width: 2,
                                    height: 16,
                                    child: Container(color: c.text2),
                                  ),
                                  Positioned(
                                    left: pos(m.value) * w - 6,
                                    top: 2,
                                    width: 12,
                                    height: 12,
                                    child: Container(
                                      decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      SizedBox(
                        width: 52,
                        child: Text(
                          fmt(m.value),
                          textAlign: TextAlign.right,
                          style: OgText.actWindow.copyWith(fontSize: 14, color: c.text),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text('Oratge blend ${fmt(a.blend)} ${a.unit}', style: OgText.actWindow.copyWith(color: c.text)),
                  ),
                  Text('Model spread ${a.spread}', style: OgText.chip.copyWith(color: c.text2)),
                ],
              ),
              const SizedBox(height: 4),
              Text(a.verdict, style: OgText.chip.copyWith(color: c.text2, fontSize: 13)),
            ],
          ),
        ),
      ],
    );
  }
}

class _Factors extends StatelessWidget {
  const _Factors(this.a);
  final Analysis a;

  @override
  Widget build(BuildContext context) {
    final c = context.og;
    return OgCard(
      raised: true,
      child: Column(
        children: [
          for (final f in a.factors)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          f.factor,
                          style: OgText.day.copyWith(fontWeight: FontWeight.w500, color: c.text),
                        ),
                        Text('${f.observed} · weight ${f.weight} %', style: OgText.chip.copyWith(color: c.text2)),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 80,
                    height: 6,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: f.score.toDouble(),
                        backgroundColor: c.surface,
                        color: c.accent(accentFromString(f.accent) ?? OgAccent.neutral),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 40,
                    child: Text(
                      f.score.toStringAsFixed(1),
                      textAlign: TextAlign.right,
                      style: OgText.day.copyWith(color: c.text),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text('${a.total} / 5', style: OgText.factValue.copyWith(color: c.text)),
              const SizedBox(width: 12),
              OgRatingDots(value: a.rating, large: true),
            ],
          ),
        ],
      ),
    );
  }
}
