import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/models.dart';
import '../../data/profile.dart';
import '../../theme/oratge_tokens.dart';
import '../components/basics.dart';
import '../components/blocks.dart';
import '../components/rows_cards.dart';
import '../components/weather_icon.dart';
import '../charts/charts.dart';
import 'common.dart';

class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return AsyncView<TodayData>(
      load: app.repository.today,
      builder: (context, d) {
        final c = context.og;
        final mine = app.mySports;
        final cur = d.current;
        final best = d.best;
        return OgPage(title: d.title, subtitle: d.date, children: [
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
                      Container(
                          width: 10, height: 10, decoration: BoxDecoration(color: c.water, shape: BoxShape.circle)),
                      const SizedBox(width: 8),
                      Text('${best['note']}', style: OgText.day.copyWith(color: c.text)),
                    ]),
                  ],
                ]),
              ),
            ),
            for (final w in d.warnings) ...[
              const SizedBox(height: 12),
              OgWarningBanner(level: w.level, title: w.title, detail: w.detail, pre: w.pre),
            ],
            const SizedBox(height: 20),
            OgCurrentConditions(
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
            const OgSectionLabel('Right now'),
            factsGrid(d.rightNow),
            const OgSectionLabel('Next 24 hours'),
            OgCard(
              child: OgNextHours(
                temps: nums(d.next24['temps']),
                rain: nums(d.next24['rain']),
                sky: [for (final s in d.next24['sky'] as List) weatherKindFrom(s as String)],
                startHour: (d.next24['startHour'] as num).toInt(),
              ),
            ),
          ], right: [
            const OgSectionLabel('Today for you'),
            OgCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Column(children: [
                for (final (i, a) in d.sports.where((a) => mine.contains(a.sport)).indexed)
                  OgActivityRow(
                    sport: a.sport,
                    rating: a.rating,
                    window: a.window,
                    reason: a.reason,
                    last: i == mine.length - 1,
                    onTap: () => context.go('/activities/${a.sport}'),
                  ),
              ]),
            ),
            const OgSectionLabel('7 days'),
            OgCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Column(children: [
                for (final day in d.days)
                  OgForecastDayRow(
                    day: '${day['day']}',
                    sky: skyOf(day),
                    rainChance: (day['rainChance'] as num).toInt(),
                    min: day['min'] as num,
                    max: day['max'] as num,
                    scale: d.scale,
                  ),
              ]),
            ),
            if (d.confidence != null) ...[
              const OgSectionLabel('Forecast confidence'),
              _Confidence(d.confidence!),
            ],
            const OgSectionLabel('Daylight'),
            factsGrid(d.daylight),
            OgDataSources(d.sources),
          ]),
        ]);
      },
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
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                      value: (r['pct'] as num) / 100, backgroundColor: c.surface2, color: c.text2),
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
