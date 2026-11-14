import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart' hide Block;

import '../../data/activities.dart';
import '../../data/models.dart';
import '../../data/profile.dart';
import '../../theme/oratge_tokens.dart';
import '../components/basics.dart';
import '../components/blocks.dart';
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
                Row(children: [
                  const Expanded(child: OgSectionLabel('Your activities', top: 4)),
                  TextButton.icon(
                    onPressed: () => context.push('/activities/new'),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add'),
                  ),
                ]),
                _YourActivities(app.activities),
                const OgSectionLabel('All sports at the built-in spots'),
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
                          onTap: () => context.push('/activities/${a.sport}'),
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
                onTap: () => context.push('/spots/${s.id}'),
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


/// The user's activities: tap to open (planner for a place, route analysis for a GPX), pencil to edit.
class _YourActivities extends StatelessWidget {
  const _YourActivities(this.items);
  final List<Activity> items;

  @override
  Widget build(BuildContext context) {
    final c = context.og;
    if (items.isEmpty) {
      return Text('Add a spot (for example a wing foil beach) or a GPX route to have it checked on Today and in notifications.',
          style: OgText.chip.copyWith(color: c.text2, fontSize: 13));
    }
    return OgCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Column(children: [
        for (final (i, a) in items.indexed)
          InkWell(
            onTap: () => context.push(a.isRoute
                ? '/activities/route/${a.id}'
                : (a.builtin != null ? '/activities/${a.sport}' : '/activities/place/${a.id}')),
            child: Container(
              constraints: const BoxConstraints(minHeight: 56),
              decoration: BoxDecoration(border: i == 0 ? null : Border(top: BorderSide(color: c.line))),
              child: Row(children: [
                Icon(a.isRoute ? Icons.route : Icons.place_outlined, color: c.text2, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                    Text('${sportNames[a.sport]} · ${a.name}', style: OgText.actName.copyWith(color: c.text)),
                    Text(
                        a.isRoute
                            ? '${a.distanceKm.toStringAsFixed(0)} km · ${a.date ?? 'today'} ${a.start}'
                            : '${a.notify ? 'Notifies' : 'Shows'} from ${a.minRating}/5${a.onlyWhenGood ? ' · on Today only when good' : ''}',
                        style: OgText.chip.copyWith(color: c.text2)),
                  ]),
                ),
                IconButton(
                  tooltip: 'Edit',
                  onPressed: () => context.push('/activities/edit/${a.id}'),
                  icon: Icon(Icons.edit_outlined, color: c.text3, size: 20),
                ),
              ]),
            ),
          ),
      ]),
    );
  }
}
