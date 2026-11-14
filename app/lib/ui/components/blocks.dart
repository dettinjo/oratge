import 'package:flutter/material.dart';

import '../../data/models.dart';
import '../../theme/og_helpers.dart';
import '../../theme/oratge_tokens.dart';
import '../charts/chart_utils.dart' show compassName;
import '../charts/charts.dart';
import 'basics.dart';
import 'scrub.dart';
import 'weather_icon.dart';

const _months = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

String _fmt(num v, [int decimals = 0]) => decimals > 0 ? v.toStringAsFixed(decimals) : v.round().toString();

/// Builds an HourChart from its JSON props (HourChart.d.ts).
OgHourChart hourChartFromJson(Json p, {String? semanticLabel, int? selected}) => OgHourChart(
  hours: [for (final h in p['hours'] as List) (h as num).toInt()],
  rows: [for (final r in p['rows'] as List) HourRow.fromJson(r as Json)],
  best: (p['best'] as List?)?.map((e) => e as num).toList(),
  sunrise: (p['sunrise'] as num?)?.toDouble() ?? 7.6,
  sunset: (p['sunset'] as num?)?.toDouble() ?? 17.6,
  semanticLabel: semanticLabel,
  selected: selected,
);

/// Interactive hour chart: drag across it to read every row at that hour.
Widget interactiveHourChart(Json p, {String? semanticLabel}) {
  final hours = [for (final h in p['hours'] as List) (h as num).toInt()];
  final rows = [for (final r in p['rows'] as List) HourRow.fromJson(r as Json)];
  return Scrub(
    count: hours.length,
    indexAt: (dx, w) => hourChartIndex(dx, w, hours.length),
    chart: (sel) => hourChartFromJson(p, semanticLabel: semanticLabel, selected: sel),
    readout: (i, c) => ('${hours[i].toString().padLeft(2, '0')} h', [for (final r in rows) ?_rowItem(r, i, c)]),
  );
}

ReadoutItem? _rowItem(HourRow r, int i, OratgeColors c) {
  final col = r.accent == null ? null : c.accent(r.accent!);
  switch (r.type) {
    case 'icons':
      return i < r.icons.length ? ReadoutItem('', r.icons[i].name) : null;
    case 'rating':
      return i < r.values.length ? ReadoutItem('rating', '${r.values[i].round()}/5', color: c.ratingColor(r.values[i])) : null;
    case 'line':
      if (i >= r.values.length) return null;
      final band = r.band != null && i < r.band!.length ? ' (${_fmt(r.band![i], r.decimals)})' : '';
      final comp = r.companion != null && i < r.companion!.length ? ' · ${_fmt(r.companion![i], 1)}' : '';
      return ReadoutItem(r.label, '${_fmt(r.values[i], r.decimals)}$band$comp ${r.unit ?? ''}'.trim(), color: col);
    case 'bars':
    case 'numbers':
      if (i >= r.values.length) return null;
      return ReadoutItem(r.label, '${_fmt(r.values[i], r.decimals)}${r.suffix} ${r.unit ?? ''}'.trim(), color: col);
    case 'arrows':
      if (i >= r.values.length) return null;
      final tag = r.shore != null && i < r.shore!.length ? ' · ${r.shore![i]}' : '';
      final from = r.label.toLowerCase().startsWith('from') ? '' : 'from ';
      return ReadoutItem(r.label, '$from${compassName(r.values[i].toDouble())}$tag', color: col);
    case 'category':
      return i < r.labels.length ? ReadoutItem(r.label, r.labels[i]) : null;
  }
  return null;
}

OgTrendLine trendFromJson(Json p, {String? semanticLabel, int? selected}) => OgTrendLine(
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
  selected: selected,
);

Widget interactiveTrend(Json p, {String? semanticLabel, String unit = ''}) {
  final v = nums(p['values']);
  final cmp = p['compare'] == null ? null : nums(p['compare']);
  final band = p['band'] == null ? null : nums(p['band']);
  final cap = p['caption'] == null ? null : strs(p['caption']);
  final hoursBack = cap != null && cap.length == 2 && (cap[1] == 'now');
  final n = v.length > (cmp?.length ?? 0) ? v.length : cmp!.length;
  final u = unit.isNotEmpty ? unit : (p['nowLabel'] as String? ?? '').replaceAll(RegExp(r'[^a-zA-Z°%]'), '');
  return Scrub(
    count: v.length,
    indexAt: (dx, w) => indexTrend(dx, w, n),
    chart: (sel) => trendFromJson(p, semanticLabel: semanticLabel, selected: sel),
    readout: (i, c) => (
      hoursBack ? (i == v.length - 1 ? 'now' : '−${v.length - 1 - i} h') : '#${i + 1}',
      [
        ReadoutItem(
          cmp != null ? 'measured' : 'value',
          '${_fmt(v[i], 1)} $u'.trim(),
          color: c.accent(accentFromString(p['accent'] as String?) ?? OgAccent.neutral),
        ),
        if (band != null && i < band.length) ReadoutItem('gusts', '${_fmt(band[i], 1)} $u'.trim()),
        if (cmp != null && i < cmp.length) ReadoutItem('forecast', '${_fmt(cmp[i], 1)} $u'.trim(), color: c.text2),
      ],
    ),
  );
}

/// Renders a design-system block (chart or visual) from the data contract. Charts are interactive.
Widget renderBlock(Block b, {String? semanticLabel}) {
  final p = b.props;
  switch (b.type) {
    case 'HourChart':
      return interactiveHourChart(p, semanticLabel: semanticLabel);
    case 'TrendLine':
      return interactiveTrend(p, semanticLabel: semanticLabel);
    case 'WindCompass':
      return OgWindCompass(
        from: (p['from'] ?? p['direction']) as num,
        speed: p['speed'] as num,
        shoreFacing: p['shoreFacing'] as num,
        caption: p['caption'] as String?,
      );
    case 'SwellWindow':
      return OgSwellWindow(swellFrom: p['swellFrom'] as num, exposure: nums(p['exposure']));
    case 'WindBand':
      final mean = nums(p['mean']), gust = nums(p['gust']);
      final dirs = p['directions'] == null ? null : nums(p['directions']);
      final days = strs(p['days']);
      return Scrub(
        count: mean.length,
        indexAt: (dx, w) => indexWindBand(dx, w, mean.length),
        chart: (sel) => OgWindBand(
          mean: mean,
          gust: gust,
          directions: dirs,
          range: p['range'] == null ? null : nums(p['range']),
          days: days,
          night: [for (final n in (p['night'] as List? ?? const [])) nums(n)],
          best: p['best'] == null ? null : nums(p['best']),
          semanticLabel: semanticLabel,
          selected: sel,
        ),
        readout: (i, c) => (
          '${i ~/ 24 < days.length ? days[i ~/ 24] : ''} ${(i % 24).toString().padLeft(2, '0')} h'.trim(),
          [
            ReadoutItem('wind', '${_fmt(mean[i])} kn', color: c.wind),
            ReadoutItem('gusts', '${_fmt(gust[i])} kn'),
            if (dirs != null) ReadoutItem('from', compassName(dirs[i].toDouble())),
          ],
        ),
      );
    case 'WaveBars':
      final h = nums(p['heights']), per = nums(p['periods']);
      final wind = p['windFrom'] == null ? null : nums(p['windFrom']);
      final days = strs(p['days']);
      final perDay = days.isEmpty ? h.length : h.length ~/ days.length;
      return Scrub(
        count: h.length,
        indexAt: (dx, w) => indexWaveBars(dx, w, h.length),
        chart: (sel) => OgWaveBars(
          heights: h,
          periods: per,
          windFrom: wind,
          days: days,
          best: [for (final i in (p['best'] as List? ?? const [])) (i as num).toInt()],
          semanticLabel: semanticLabel,
          selected: sel,
        ),
        readout: (i, c) => (
          days.isEmpty
              ? '#${i + 1}'
              : '${days[(i ~/ perDay).clamp(0, days.length - 1)]} ${((i % perDay) * (24 ~/ perDay)).toString().padLeft(2, '0')} h',
          [
            ReadoutItem('waves', '${_fmt(h[i], 1)} m', color: c.water),
            ReadoutItem('period', '${_fmt(per[i])} s'),
            if (wind != null) ReadoutItem('wind from', compassName(wind[i].toDouble()), color: c.wind),
          ],
        ),
      );
    case 'AltitudeProfile':
      return OgAltitudeProfile(
        points: [
          for (final q in p['points'] as List)
            AltitudePoint((q as Json)['altitude'] as num, q['temp'] as num, q['label'] as String?),
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
            (Offset(((l as List)[0] as num).toDouble(), (l[1] as num).toDouble()), l[2] as String),
        ],
      );
    case 'MonthBars':
      final v = nums(p['values']);
      return Scrub(
        count: 12,
        indexAt: (dx, w) => indexMonths(dx, w),
        hint: 'Tap a month',
        chart: (sel) => OgMonthBars(
          values: v,
          accent: accentFromString(p['accent'] as String?) ?? OgAccent.wind,
          highlight: (p['highlight'] as num?)?.toInt(),
          current: (p['current'] as num?)?.toInt(),
          semanticLabel: semanticLabel,
          selected: sel,
        ),
        readout: (i, c) => (_months[i], [ReadoutItem('average', '${_fmt(v[i], 1)} days', color: c.wind)]),
      );
    case 'CalendarHeatmap':
      return OgCalendarHeatmap(
        weeks: [
          for (final w in p['weeks'] as List) [for (final v in w as List) (v as num).toInt()],
        ],
        months: strs(p['months']),
        legend: p['legend'] == null ? null : strs(p['legend']),
        semanticLabel: semanticLabel,
      );
    case 'NextHours':
      return interactiveNextHours(p, semanticLabel: semanticLabel);
    case 'Table':
      return OgTable(
        columns: strs(p['columns']),
        rows: [for (final r in p['rows'] as List) strs(r)],
        caption: p['caption'] as String?,
      );
    case 'FactTile':
      return OgFactTile(
        label: p['label'] as String,
        value: '${p['value']}',
        sub: p['sub'] as String?,
        accent: accentFromString(p['accent'] as String?),
        large: p['size'] == 'lg',
      );
  }
  return const SizedBox.shrink();
}

Widget interactiveNextHours(Json p, {String? semanticLabel}) {
  final temps = nums(p['temps']), rain = nums(p['rain']);
  final sky = [for (final s in p['sky'] as List) weatherKindFrom(s as String)];
  final start = (p['startHour'] as num).toInt();
  final wind = p['wind'] == null ? null : nums(p['wind']);
  final storm = p['storm'] == null ? null : nums(p['storm']);
  return Scrub(
    count: temps.length,
    indexAt: (dx, w) => indexNextHours(dx, w, temps.length),
    chart: (sel) =>
        OgNextHours(temps: temps, rain: rain, sky: sky, startHour: start, semanticLabel: semanticLabel, selected: sel),
    readout: (i, c) => (
      '${((start + i) % 24).toString().padLeft(2, '0')} h',
      [
        ReadoutItem('', sky[i].name),
        ReadoutItem('temp', '${_fmt(temps[i])}°', color: c.heat),
        ReadoutItem('rain', '${_fmt(rain[i])} %', color: c.water),
        if (wind != null && i < wind.length) ReadoutItem('wind', '${_fmt(wind[i])} kn', color: c.wind),
        if (storm != null && i < storm.length && storm[i] >= 30) ReadoutItem('⚡ thunder likely', '${storm[i].round()} %', color: c.storm),
      ],
    ),
  );
}

/// Places compasses/swell windows side by side with what follows them when there's room.
Widget blockGroup(List<Block> blocks, {String? label}) {
  final children = [for (final b in blocks) renderBlock(b, semanticLabel: label)];
  if (blocks.length == 2 && (blocks[0].type == 'WindCompass')) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(child: children[0]),
        const SizedBox(height: 12),
        children[1],
      ],
    );
  }
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (var i = 0; i < children.length; i++) ...[
        if (i > 0) const SizedBox(height: 12),
        blocks[i].type == 'SwellWindow' ? Center(child: children[i]) : children[i],
      ],
    ],
  );
}

Widget factsGrid(List<Fact> facts, {int columns = 2, void Function(Fact)? onTap}) => OgFactGrid(
  columns: columns,
  children: [
    for (final f in facts)
      _Tappable(
        onTap: onTap == null ? null : () => onTap(f),
        label: '${f.label}: ${f.value}. Details',
        child: OgFactTile(label: f.label, value: f.value, sub: f.sub, accent: accentFromString(f.accent), large: f.large),
      ),
  ],
);

class _Tappable extends StatelessWidget {
  const _Tappable({required this.child, this.onTap, required this.label});
  final Widget child;
  final VoidCallback? onTap;
  final String label;
  @override
  Widget build(BuildContext context) {
    if (onTap == null) return child;
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(onTap: onTap, child: child),
      ),
    );
  }
}

WeatherKind skyOf(Json j, [String key = 'sky']) => weatherKindFrom(j[key] as String? ?? 'cloud');

/// Plain table (Meteocat beach and summit forecasts): first column is the row label (hour).
class OgTable extends StatelessWidget {
  const OgTable({super.key, required this.columns, required this.rows, this.caption});
  final List<String> columns;
  final List<List<String>> rows;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final c = context.og;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 280),
            child: Table(
              defaultColumnWidth: const IntrinsicColumnWidth(),
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              children: [
                TableRow(
                  children: [
                    for (final h in columns)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(0, 0, 18, 6),
                        child: Text(h.toUpperCase(), style: OgText.label.copyWith(color: c.text2)),
                      ),
                  ],
                ),
                for (final r in rows)
                  TableRow(
                    decoration: BoxDecoration(
                      border: Border(top: BorderSide(color: c.line)),
                    ),
                    children: [
                      for (final (i, v) in r.indexed)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(0, 7, 18, 7),
                          child: Text(
                            v,
                            style: (i == 0 ? OgText.chip.copyWith(color: c.text2) : OgText.day.copyWith(color: c.text)),
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ),
        if (caption != null) ...[const SizedBox(height: 6), Text(caption!, style: OgText.src.copyWith(color: c.text3))],
      ],
    );
  }
}
