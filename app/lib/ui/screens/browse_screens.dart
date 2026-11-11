import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart' hide Block;

import '../../data/models.dart';
import '../../data/profile.dart';
import '../../theme/og_helpers.dart';
import '../../theme/oratge_tokens.dart';
import '../charts/chart_utils.dart';
import '../components/basics.dart';
import '../components/blocks.dart';
import '../components/og_map.dart';
import '../components/sheets.dart';
import '../components/rows_cards.dart';
import 'common.dart';
import '../components/location_sheet.dart';
import '../components/modules.dart';

// ───────────────────────────── Activities ─────────────────────────────
class ActivitiesScreen extends StatefulWidget {
  const ActivitiesScreen({super.key});
  @override
  State<ActivitiesScreen> createState() => _ActivitiesScreenState();
}

class _ActivitiesScreenState extends State<ActivitiesScreen> {
  String? _chip;
  int _day = 0;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return AsyncView<ActivitiesData>(
      load: app.repository.activities,
      builder: (context, d) {
        final mine = d.sports.where((a) => app.mySports.contains(a.sport)).toList();
        return OgPage(
          title: d.title,
          subtitle: d.date,
          children: [
            Columns(
              left: [
                const OgSectionLabel('Today for you', top: 4),
                OgCard(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Column(
                    children: [
                      for (final (i, a) in mine.indexed)
                        OgActivityRow(
                          sport: a.sport,
                          rating: a.rating,
                          window: a.window,
                          reason: a.reason,
                          last: i == mine.length - 1,
                          onTap: () => context.go('/activities/${a.sport}'),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                OgChipGroup(
                  label: d.chip['label'] as String?,
                  options: strs(d.chip['options']),
                  selected: _chip ?? '${d.chip['selected']}',
                  onSelect: (o) => setState(() => _chip = o),
                ),
                const SizedBox(height: 8),
                OgDayTabs(
                  days: [for (final t in d.days) (weekday: t.weekday, date: t.date, rating: t.rating, outlook: t.outlook)],
                  selected: _day,
                  onSelect: (i) => setState(() => _day = i),
                ),
              ],
              right: [
                const OgSectionLabel('Rideable hours · last 6 months'),
                OgCard(
                  child: renderBlock(Block('CalendarHeatmap', d.heatmap), semanticLabel: 'Rideable hours per day, last 6 months'),
                ),
                const OgSectionLabel('Rideable days per month'),
                OgCard(child: renderBlock(Block('MonthBars', d.months), semanticLabel: 'Rideable days per month')),
                OgDataSources(d.sources),
              ],
            ),
          ],
        );
      },
    );
  }
}

// ───────────────────────────── Map ─────────────────────────────
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});
  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  String? _layer;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return AsyncView<MapData>(
      load: app.repository.map,
      builder: (context, d) {
        final c = context.og;
        final layer = _layer ?? '${d.layers['selected']}';
        return OgPage(
          title: d.title,
          subtitle: d.date,
          children: [
            OgChipGroup(options: strs(d.layers['options']), selected: layer, onSelect: (o) => setState(() => _layer = o)),
            const SizedBox(height: 10),
            Columns(
              left: [
                OgCard(
                  padding: const EdgeInsets.all(8),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: Semantics(
                      label: 'Map of Catalonia with ${d.pins.length} spots; pins show today’s rating',
                      child: OgSpotMap(
                        pins: d.pins,
                        layer: layer,
                        onTap: () => context.push('/map/full'),
                        fallback: LayoutBuilder(
                          builder: (context, box) {
                            final s = box.biggest;
                            return Stack(
                              children: [
                                Positioned.fill(child: CustomPaint(painter: _CataloniaPainter(c, layer, d.warnings))),
                                for (final p in d.pins)
                                  Positioned(
                                    left: p.x * s.width - 60,
                                    top: p.y * s.height - 14,
                                    width: 120,
                                    child: Column(
                                      children: [
                                        if (layer == 'Wind')
                                          CustomPaint(size: const Size(28, 28), painter: _PinArrow(c, p))
                                        else
                                          Container(
                                            width: 22,
                                            height: 22,
                                            decoration: BoxDecoration(
                                              color: c.ratingColor(p.rating),
                                              shape: BoxShape.circle,
                                              border: Border.all(color: c.bg, width: 2),
                                            ),
                                            child: Center(
                                              child: Text(
                                                '${p.rating}',
                                                style: OgText.chip.copyWith(color: c.bg, fontWeight: FontWeight.w700),
                                              ),
                                            ),
                                          ),
                                        Text(
                                          p.name.split(' · ').first,
                                          textAlign: TextAlign.center,
                                          style: OgText.src.copyWith(color: c.text, height: 1.2),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    side: BorderSide(color: c.line),
                    foregroundColor: c.text,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                  ),
                  onPressed: () => context.push('/map/full'),
                  icon: const Icon(Icons.open_in_full, size: 18),
                  label: const Text('Open detailed map'),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      layer == 'Wind' ? 'Arrows show live wind, coloured by speed' : 'Pins show today’s rating',
                      style: OgText.src.copyWith(color: c.text2),
                    ),
                    const Spacer(),
                    if (layer != 'Wind') const OgRatingDots(value: 4),
                  ],
                ),
              ],
              right: [
                const OgSectionLabel('Official warnings'),
                if (d.warnings.isEmpty)
                  Text('No active Meteocat warnings for your spots.', style: OgText.day.copyWith(color: c.text2)),
                for (final w in d.warnings) ...[
                  InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => showWarningSheet(context, w),
                    child: OgWarningBanner(level: w.level, title: w.title, detail: w.detail, pre: w.pre),
                  ),
                  const SizedBox(height: 10),
                ],
                OgDataSources(d.sources),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _PinArrow extends CustomPainter {
  _PinArrow(this.c, this.p);
  final OratgeColors c;
  final MapPin p;
  @override
  void paint(Canvas canvas, Size size) {
    windArrow(canvas, Offset(size.width / 2, size.height / 2), p.windFrom.toDouble(), c.windColor(p.wind), len: 10, width: 2.6);
  }

  @override
  bool shouldRepaint(_PinArrow o) => o.p != p || o.c != c;
}

/// Schematic Catalonia outline (placeholder base map until a vector map is wired in).
class _CataloniaPainter extends CustomPainter {
  _CataloniaPainter(this.c, this.layer, this.warnings);
  final OratgeColors c;
  final String layer;
  final List<Warning> warnings;

  static const _outline = [
    Offset(0.10, 0.18),
    Offset(0.30, 0.12),
    Offset(0.52, 0.10),
    Offset(0.72, 0.13),
    Offset(0.92, 0.16),
    Offset(0.95, 0.30),
    Offset(0.88, 0.45),
    Offset(0.78, 0.58),
    Offset(0.66, 0.68),
    Offset(0.55, 0.78),
    Offset(0.42, 0.86),
    Offset(0.30, 0.95),
    Offset(0.16, 0.92),
    Offset(0.12, 0.70),
    Offset(0.06, 0.50),
    Offset(0.08, 0.30),
  ];

  @override
  void paint(Canvas canvas, Size s) {
    canvas.drawRect(Offset.zero & s, fillPaint(c.water.withValues(alpha: 0.06)));
    final land = Path()..addPolygon([for (final p in _outline) Offset(p.dx * s.width, p.dy * s.height)], true);
    canvas.drawPath(land, fillPaint(c.surface2));
    canvas.drawPath(land, strokePaint(c.line, 1));
    if (layer == 'Warnings' || warnings.isNotEmpty) {
      // Coastal county hatched for the first active warning (schematic).
      final area = Path()
        ..addPolygon([
          Offset(0.62 * s.width, 0.60 * s.height),
          Offset(0.80 * s.width, 0.56 * s.height),
          Offset(0.66 * s.width, 0.70 * s.height),
          Offset(0.54 * s.width, 0.78 * s.height),
        ], true);
      canvas.save();
      canvas.clipPath(area);
      hatchRect(
        canvas,
        area.getBounds(),
        c.warningColor(warnings.isEmpty ? 'yellow' : warnings.first.level).withValues(alpha: 0.6),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_CataloniaPainter o) => o.c != c || o.layer != layer;
}

// ───────────────────────────── Spots ─────────────────────────────
class SpotsScreen extends StatelessWidget {
  const SpotsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return AsyncView<List<SpotSummary>>(
      load: app.repository.spots,
      builder: (context, spots) {
        final c = context.og;
        return OgPage(
          title: 'Spots',
          subtitle: 'Saved spots',
          children: [
            for (final s in spots) ...[
              OgSpotCard(
                name: s.name,
                kind: s.kind,
                wind: s.wind,
                gust: s.gust,
                windFrom: s.windFrom,
                today: s.today,
                window: s.window,
                rating: s.rating,
                onTap: () => context.go('/spots/${s.id}'),
              ),
              const SizedBox(height: 10),
            ],
            const OgSectionLabel('Your places'),
            if (app.favorites.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  'Star a place in the location picker (search or your current location) to keep it here.',
                  style: OgText.chip.copyWith(color: c.text2, fontSize: 13),
                ),
              )
            else
              OgCard(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Column(
                  children: [
                    for (final p in app.favorites)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        minTileHeight: 56,
                        leading: CircleAvatar(
                          backgroundColor: c.surface2,
                          child: Icon(Icons.star, color: c.sun, size: 20),
                        ),
                        title: Text(p.name, style: OgText.actName.copyWith(color: c.text)),
                        subtitle: Text(
                          p.region.isEmpty ? 'Weather, live readings and warnings here' : p.region,
                          style: OgText.chip.copyWith(color: c.text2),
                        ),
                        trailing: IconButton(
                          tooltip: 'Remove from favourites',
                          icon: Icon(Icons.close, color: c.text3),
                          onPressed: () => app.toggleFavorite(p),
                        ),
                        onTap: () {
                          app.setPlace(p);
                          context.go('/today');
                        },
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                side: BorderSide(color: c.line),
                foregroundColor: c.text,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
              ),
              onPressed: () => showLocationSheet(context),
              icon: const Icon(Icons.add),
              label: Text('Add a place', style: OgText.actWindow.copyWith(color: c.text)),
            ),
          ],
        );
      },
    );
  }
}

class SpotScreen extends StatelessWidget {
  const SpotScreen({super.key, required this.id});
  final String id;

  static const modules = <ModuleDef>[
    ModuleDef('live', 'Now at the spot', Icons.sensors, wide: true),
    ModuleDef('conditions', 'Wind and trend', Icons.air, wide: true),
    ModuleDef('history', 'History', Icons.bar_chart, wide: true, hint: 'Rideable days and hours'),
  ];

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final layout = ScreenLayout('spot', modules, app);
    return AsyncView<SpotDetail>(
      load: () => app.repository.spot(id),
      builder: (context, d) {
        final c = context.og;
        Widget sec(LabeledBlocks x) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text((x.label ?? '').toUpperCase(), style: OgText.label.copyWith(color: c.text2)),
            const SizedBox(height: 8),
            OgCard(child: blockGroup(x.blocks, label: x.label)),
          ],
        );
        return OgPage(
          title: d.title,
          subtitle: d.date,
          back: (label: 'Back to Spots', route: '/spots'),
          headerExtra: Align(
            alignment: Alignment.centerLeft,
            child: CustomiseButton(layout: layout),
          ),
          children: [
            ModuleGrid(
              layout: layout,
              builder: (context, def, size) {
                final minimal = size == ModuleSize.minimal;
                switch (def.id) {
                  case 'live':
                    return factsGrid(
                      minimal ? d.live.take(2).toList() : d.live,
                      onTap: (f) => showFactSheet(context, f, source: d.sources),
                    );
                  case 'conditions':
                    return d.sections.isEmpty ? null : sec(d.sections.first);
                  case 'history':
                    final rest = d.sections.skip(1).toList();
                    if (rest.isEmpty) return null;
                    return Column(
                      children: [
                        for (final (i, x) in (minimal ? rest.take(1) : rest).indexed) ...[
                          if (i > 0) const SizedBox(height: 16),
                          sec(x),
                        ],
                      ],
                    );
                }
                return null;
              },
            ),
            OgDataSources(d.sources),
          ],
        );
      },
    );
  }
}
