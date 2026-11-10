import 'package:flutter/material.dart';

import '../../data/models.dart';
import '../../theme/og_helpers.dart';
import '../charts/charts.dart';
import 'basics.dart';
import 'weather_icon.dart';

/// Builds an HourChart from its JSON props (HourChart.d.ts).
OgHourChart hourChartFromJson(Json p, {String? semanticLabel}) => OgHourChart(
      hours: [for (final h in p['hours'] as List) (h as num).toInt()],
      rows: [for (final r in p['rows'] as List) HourRow.fromJson(r as Json)],
      best: (p['best'] as List?)?.map((e) => e as num).toList(),
      sunrise: (p['sunrise'] as num?)?.toDouble() ?? 7.6,
      sunset: (p['sunset'] as num?)?.toDouble() ?? 17.6,
      semanticLabel: semanticLabel,
    );

OgTrendLine trendFromJson(Json p, {String? semanticLabel}) => OgTrendLine(
      values: nums(p['values']),
      accent: accentFromString(p['accent'] as String?) ?? OgAccent.neutral,
      band: p['band'] == null ? null : nums(p['band']),
      compare: p['compare'] == null ? null : nums(p['compare']),
      nowIndex: (p['nowIndex'] as num?)?.toInt(),
      nowLabel: p['nowLabel'] as String?,
      caption: p['caption'] == null ? null : strs(p['caption']),
      endLabels: p['endLabels'] == null ? null : strs(p['endLabels']),
      min: p['min'] as num?,
      max: p['max'] as num?,
      height: ((p['height'] as num?) ?? 70).toDouble(),
      semanticLabel: semanticLabel,
    );

/// Renders a design-system block (chart or visual) from the data contract.
Widget renderBlock(Block b, {String? semanticLabel}) {
  final p = b.props;
  switch (b.type) {
    case 'HourChart':
      return hourChartFromJson(p, semanticLabel: semanticLabel);
    case 'TrendLine':
      return trendFromJson(p, semanticLabel: semanticLabel);
    case 'WindCompass':
      return OgWindCompass(
          from: (p['from'] ?? p['direction']) as num,
          speed: p['speed'] as num,
          shoreFacing: p['shoreFacing'] as num,
          caption: p['caption'] as String?);
    case 'SwellWindow':
      return OgSwellWindow(swellFrom: p['swellFrom'] as num, exposure: nums(p['exposure']));
    case 'WindBand':
      return OgWindBand(
        mean: nums(p['mean']),
        gust: nums(p['gust']),
        directions: p['directions'] == null ? null : nums(p['directions']),
        range: p['range'] == null ? null : nums(p['range']),
        days: strs(p['days']),
        night: [for (final n in (p['night'] as List? ?? const [])) nums(n)],
        best: p['best'] == null ? null : nums(p['best']),
        semanticLabel: semanticLabel,
      );
    case 'WaveBars':
      return OgWaveBars(
        heights: nums(p['heights']),
        periods: nums(p['periods']),
        windFrom: p['windFrom'] == null ? null : nums(p['windFrom']),
        days: strs(p['days']),
        best: [for (final i in (p['best'] as List? ?? const [])) (i as num).toInt()],
        semanticLabel: semanticLabel,
      );
    case 'AltitudeProfile':
      return OgAltitudeProfile(
        points: [
          for (final q in p['points'] as List)
            AltitudePoint((q as Json)['altitude'] as num, q['temp'] as num, q['label'] as String?)
        ],
        snowLevel: p['snowLevel'] as num?,
        semanticLabel: semanticLabel,
      );
    case 'RouteWind':
      return OgRouteWind(
        points: [for (final q in p['points'] as List) Offset(((q as List)[0] as num).toDouble(), (q[1] as num).toDouble())],
        windFrom: p['windFrom'] as num,
        windLabel: p['windLabel'] as String,
        title: p['title'] as String?,
        labels: [
          for (final l in (p['labels'] as List? ?? const []))
            (Offset(((l as List)[0] as num).toDouble(), (l[1] as num).toDouble()), l[2] as String)
        ],
      );
    case 'MonthBars':
      return OgMonthBars(
          values: nums(p['values']),
          accent: accentFromString(p['accent'] as String?) ?? OgAccent.wind,
          highlight: (p['highlight'] as num?)?.toInt(),
          current: (p['current'] as num?)?.toInt(),
          semanticLabel: semanticLabel);
    case 'CalendarHeatmap':
      return OgCalendarHeatmap(
          weeks: [for (final w in p['weeks'] as List) [for (final v in w as List) (v as num).toInt()]],
          months: strs(p['months']),
          legend: p['legend'] == null ? null : strs(p['legend']),
          semanticLabel: semanticLabel);
    case 'NextHours':
      return OgNextHours(
          temps: nums(p['temps']),
          rain: nums(p['rain']),
          sky: [for (final s in p['sky'] as List) weatherKindFrom(s as String)],
          startHour: (p['startHour'] as num).toInt(),
          semanticLabel: semanticLabel);
    case 'FactTile':
      return OgFactTile(
          label: p['label'] as String,
          value: '${p['value']}',
          sub: p['sub'] as String?,
          accent: accentFromString(p['accent'] as String?),
          large: p['size'] == 'lg');
  }
  return const SizedBox.shrink();
}

/// Places compasses/swell windows side by side with what follows them when there's room.
Widget blockGroup(List<Block> blocks, {String? label}) {
  final children = [for (final b in blocks) renderBlock(b, semanticLabel: label)];
  if (blocks.length == 2 && (blocks[0].type == 'WindCompass')) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Center(child: children[0]),
      const SizedBox(height: 12),
      children[1],
    ]);
  }
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (var i = 0; i < children.length; i++) ...[
        if (i > 0) const SizedBox(height: 12),
        blocks[i].type == 'SwellWindow' ? Center(child: children[i]) : children[i],
      ]
    ],
  );
}

Widget factsGrid(List<Fact> facts, {int columns = 2}) => OgFactGrid(
      columns: columns,
      children: [
        for (final f in facts)
          OgFactTile(label: f.label, value: f.value, sub: f.sub, accent: accentFromString(f.accent), large: f.large)
      ],
    );

WeatherKind skyOf(Json j, [String key = 'sky']) => weatherKindFrom(j[key] as String? ?? 'cloud');
