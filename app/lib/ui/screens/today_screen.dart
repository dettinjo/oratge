import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/models.dart';
import '../../data/profile.dart';
import '../../theme/og_helpers.dart';
import '../../theme/oratge_tokens.dart';
import '../components/basics.dart';
import '../components/blocks.dart';
import '../components/location_sheet.dart';
import '../components/rows_cards.dart';
import '../components/sheets.dart';
import 'common.dart';

class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final place = app.place;
    return AsyncView<TodayData>(
      key: ValueKey('today-${place?.name}-${place?.lat}'),
      load: () => app.repository.today(place),
      builder: (context, d) {
        final c = context.og;
        final mine = app.mySports;
        final cur = d.current;
        final best = d.best;
        final sports = d.sports.where((a) => mine.contains(a.sport)).toList();
        return OgPage(
          title: d.title,
          subtitle: d.date,
          headerExtra: _PlaceChip(name: place?.name ?? '${cur['place']}', current: place?.current ?? false),
          children: [
            Columns(left: [
              // Best today — the answer first.
              InkWell(
                borderRadius: BorderRadius.circular(OgRadius.card),
                onTap: () => context.go('/activities/${best['sport']}'),
                child: OgCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('BEST TODAY', style: OgText.label.copyWith(color: c.text2)),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(
                        child: Text('${sportShort[best['sport']]} · ${best['window']}',
                            style: OgText.verdictBest.copyWith(color: c.text)),
                      ),
                      OgRatingDots(value: best['rating'] as num, large: true),
                    ]),
                    const SizedBox(height: 4),
                    Text('${best['reason']}', style: OgText.verdictSummary.copyWith(color: c.text2)),
                    if (best['note'] != null) ...[
                      const SizedBox(height: 8),
                      Row(children: [
                        Container(width: 10, height: 10, decoration: BoxDecoration(color: c.water, shape: BoxShape.circle)),
                        const SizedBox(width: 8),
                        Expanded(child: Text('${best['note']}', style: OgText.day.copyWith(color: c.text))),
                      ]),
                    ],
                  ]),
                ),
              ),
              for (final w in d.warnings) ...[
                const SizedBox(height: 12),
                InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => showWarningSheet(context, w),
                  child: OgWarningBanner(level: w.level, title: w.title, detail: w.detail, pre: w.pre),
                ),
              ],
              const SizedBox(height: 20),
              InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => showFactSheet(
                  context,
                  Fact(label: 'Temp', value: '${(cur['temp'] as num).round()}°', sub: '${cur['summary']} · feels ${cur['feels']}°', accent: 'heat'),
                  series: d.next24['temps'] == null
                      ? null
                      : Series(
                          values: nums(d.next24['temps']),
                          startHour: (d.next24['startHour'] as num).toInt(),
                          unit: '°',
                          accent: OgAccent.heat,
                          title: 'Next 24 hours'),
                  source: '${cur['source']}',
                ),
                child: OgCurrentConditions(
                  place: '${cur['place']}',
                  source: '${cur['source']}',
                  sky: skyOf(cur),
                  temp: cur['temp'] as num,
                  summary: '${cur['summary']}',
                  feels: cur['feels'] as num,
                  min: cur['min'] as num,
                  max: cur['max'] as num,
                  wind: '${cur['wind']}',
                ),
              ),
              const OgSectionLabel('Right now'),
              factsGrid(d.rightNow,
                  onTap: (f) => showFactSheet(context, f, series: seriesFromNext24(d.next24, f), source: d.sources)),
              const OgSectionLabel('Next 24 hours'),
              OgCard(child: interactiveNextHours(d.next24, semanticLabel: 'Next 24 hours')),
            ], right: [
              const OgSectionLabel('Today for you'),
              OgCard(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Column(children: [
                  for (final (i, a) in sports.indexed)
                    OgActivityRow(
                      sport: a.sport,
                      rating: a.rating,
                      window: a.window,
                      reason: a.reason,
                      last: i == sports.length - 1,
                      onTap: () => context.go('/activities/${a.sport}'),
                    ),
                ]),
              ),
              const OgSectionLabel('7 days'),
              OgCard(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Column(children: [
                  for (final (i, day) in d.days.indexed)
                    InkWell(
                      onTap: () => showDaySheet(context, day, onPlan: i <= 2 ? () {
                        Navigator.of(context).pop();
                        context.go('/activities');
                      } : null),
                      child: OgForecastDayRow(
                        day: '${day['day']}',
                        sky: skyOf(day),
                        rainChance: (day['rainChance'] as num).toInt(),
                        min: day['min'] as num,
                        max: day['max'] as num,
                        scale: d.scale,
                      ),
                    ),
                ]),
              ),
              if (d.confidence != null) ...[
                const OgSectionLabel('Forecast confidence'),
                _Confidence(d.confidence!),
              ],
              const OgSectionLabel('Daylight'),
              factsGrid(d.daylight, onTap: (f) => showFactSheet(context, f)),
              OgDataSources(d.sources),
            ]),
          ],
        );
      },
    );
  }
}

/// "📍 Barcelona ▾" — opens the location picker.
class _PlaceChip extends StatelessWidget {
  const _PlaceChip({required this.name, required this.current});
  final String name;
  final bool current;

  @override
  Widget build(BuildContext context) {
    final c = context.og;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Semantics(
        button: true,
        label: 'Location: $name. Change location',
        excludeSemantics: true,
        child: Material(
          color: c.surface,
          borderRadius: BorderRadius.circular(999),
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: () => showLocationSheet(context),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(current ? Icons.my_location : Icons.place_outlined, size: 18, color: c.text),
                  const SizedBox(width: 6),
                  Flexible(child: Text(name, overflow: TextOverflow.ellipsis, style: OgText.actName.copyWith(color: c.text))),
                  const SizedBox(width: 2),
                  Icon(Icons.expand_more, size: 20, color: c.text2),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Confidence extends StatelessWidget {
  const _Confidence(this.data);
  final Json data;

  @override
  Widget build(BuildContext context) {
    final c = context.og;
    return OgCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${data['intro']}', style: OgText.src.copyWith(color: c.text2)),
        const SizedBox(height: 8),
        for (final r in data['rows'] as List)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(children: [
              SizedBox(width: 50, child: Text('${r['day']}', style: OgText.day.copyWith(color: c.text))),
              Expanded(child: Text('${r['label']}', style: OgText.chip.copyWith(color: c.text2))),
              SizedBox(
                width: 64,
                height: 6,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: (r['pct'] as num) / 100),
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.easeOutCubic,
                  builder: (context, v, _) => ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(value: v, backgroundColor: c.surface2, color: c.text2),
                  ),
                ),
              ),
              SizedBox(
                width: 44,
                child: Text('${r['pct']} %', textAlign: TextAlign.right, style: OgText.day.copyWith(color: c.text)),
              ),
            ]),
          ),
      ]),
    );
  }
}
