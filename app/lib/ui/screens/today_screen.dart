import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/models.dart';
import '../../data/profile.dart';
import '../../theme/oratge_tokens.dart';
import '../components/basics.dart';
import '../components/blocks.dart';
import '../components/location_sheet.dart';
import '../components/rows_cards.dart';
import '../components/sheets.dart';
import 'common.dart';
import 'metric_detail.dart';
import 'activities_module.dart';
import '../components/weather_icon.dart';
import '../components/modules.dart';
import '../../data/units.dart';

/// Modules on Today, in their default order (the user can reorder, hide and resize them).
const todayModules = <ModuleDef>[
  ModuleDef('activities', 'Your activities', Icons.event_available, wide: true, hint: 'Spots when they’re good, planned routes'),
  ModuleDef(
    'best',
    'Best today',
    Icons.emoji_events_outlined,
    wide: true,
    defaultOn: false,
    hint: 'The best sport and window today',
  ),
  ModuleDef('warnings', 'Warnings', Icons.warning_amber_outlined, wide: true, hint: 'Official Meteocat warnings for your places'),
  ModuleDef('current', 'Now', Icons.thermostat_outlined, wide: true),
  ModuleDef('hourly', 'Next 24 hours', Icons.schedule, wide: true),
  ModuleDef('sports', 'Today for you', Icons.show_chart, wide: true, defaultOn: false, hint: 'Every sport’s rating today'),
  ModuleDef('wind', 'Wind', Icons.air, defaultSize: ModuleSize.minimal),
  ModuleDef('rain', 'Rain', Icons.water_drop_outlined, defaultSize: ModuleSize.minimal),
  ModuleDef('uv', 'UV index', Icons.wb_sunny_outlined, defaultSize: ModuleSize.minimal),
  ModuleDef('feels', 'Feels like', Icons.accessibility_new, defaultSize: ModuleSize.minimal),
  ModuleDef('days', '7 days', Icons.calendar_view_week, wide: true),
  ModuleDef('humidity', 'Humidity', Icons.opacity, defaultSize: ModuleSize.minimal),
  ModuleDef('pressure', 'Pressure', Icons.speed, defaultSize: ModuleSize.minimal),
  ModuleDef('water', 'Sea water', Icons.waves, defaultSize: ModuleSize.minimal),
  ModuleDef('sun', 'Sunrise and sunset', Icons.wb_twilight, defaultSize: ModuleSize.minimal),
  ModuleDef(
    'station',
    'Station now',
    Icons.sensors,
    defaultSize: ModuleSize.minimal,
    hint: 'Measured by the nearest Meteocat station',
  ),
  ModuleDef('lightning', 'Lightning', Icons.bolt, defaultSize: ModuleSize.minimal, hint: 'Strikes within 30 km, last 2 hours'),
  ModuleDef('visibility', 'Visibility', Icons.visibility_outlined, defaultSize: ModuleSize.minimal, defaultOn: false),
  ModuleDef('cloud', 'Cloud cover', Icons.cloud_outlined, defaultSize: ModuleSize.minimal, defaultOn: false),
  ModuleDef('confidence', 'Forecast confidence', Icons.verified_outlined, wide: true),
];

class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final place = app.place;
    final layout = ScreenLayout('today', todayModules, app);
    _migrate(app);
    return AsyncView<(TodayData, HourlyData?)>(
      key: ValueKey('today-${place?.name}-${place?.lat}'),
      load: () async {
        final r = await Future.wait<Object?>([
          app.repository.today(place),
          app.repository.hourly(place).then<HourlyData?>((h) => h).catchError((Object _) => null),
        ]);
        return (r[0] as TodayData, r[1] as HourlyData?);
      },
      builder: (context, data) {
        final (d, h) = data;
        final cur = d.current;
        return OgPage(
          title: d.title,
          subtitle: d.date,
          headerExtra: Row(
            children: [
              Flexible(
                child: _PlaceChip(name: place?.name ?? '${cur['place']}', current: place?.current ?? false),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: CustomiseButton(layout: layout, compact: true),
              ),
            ],
          ),
          children: [
            ModuleGrid(layout: layout, builder: (context, def, size) => _module(context, app, def.id, size, d, h)),
            OgDataSources(d.sources),
          ],
        );
      },
    );
  }

  /// Layouts saved before activities existed: add them on top and drop the daily rating list once.
  static void _migrate(AppState app) {
    final raw = app.profile['layout.today'];
    if (raw is! List || raw.any((e) => (e as Map)['id'] == 'activities')) return;
    final list = [
      {'id': 'activities', 'size': 'detailed', 'on': true},
      for (final e in raw) {...Map<String, dynamic>.from(e as Map), if (e['id'] == 'best' || e['id'] == 'sports') 'on': false},
    ];
    WidgetsBinding.instance.addPostFrameCallback((_) => app.setField('layout.today', list));
  }

  /// One module. Null = nothing to show right now (no warnings, no station nearby…).
  Widget? _module(BuildContext context, AppState app, String id, ModuleSize size, TodayData d, HourlyData? h) {
    final c = context.og;
    final u = app.units;
    final minimal = size == ModuleSize.minimal;
    final cur = d.current;
    final obs = d.observed;
    final n24 = d.next24;
    final place = app.place;
    List<double?> next(String k) => [for (final v in (n24[k] as List? ?? const [])) (v as num?)?.toDouble()];
    // Index of "now" in the hourly series, and the next 24 hours from there.
    final now = DateTime.now();
    final hi = h == null
        ? -1
        : h.times.indexWhere((t) => t.year == now.year && t.month == now.month && t.day == now.day && t.hour == now.hour);
    List<double?> hourly24(String k) => (h == null || hi < 0) ? const [] : (h.series[k] ?? const []).skip(hi).take(24).toList();
    double? hourlyNow(String k) => (h == null || hi < 0) ? null : h.series[k]?[hi];
    Fact? fact(String label) => d.rightNow.where((f) => f.label == label).firstOrNull;
    void open(Metric m) => openMetric(context, m, place: place);

    Widget metricTile(
      Metric m, {
      required String value,
      String? sub,
      String? extra,
      List<double?>? spark,
      bool bars = false,
      double? lo,
      double? hiV,
    }) => ValueTile(
      icon: m.icon,
      label: m.title,
      value: value,
      sub: sub,
      color: m.color(c),
      extra: minimal ? null : extra,
      chart: minimal || spark == null || spark.isEmpty
          ? null
          : Sparkline(spark, color: m.color(c), bars: bars, min: lo, max: hiV),
      onTap: () => open(m),
    );

    switch (id) {
      case 'activities':
        return ActivitiesModule(minimal: minimal);
      case 'best':
        final best = d.best;
        if (minimal) {
          return ValueTile(
            icon: Icons.emoji_events_outlined,
            label: 'Best today',
            value: '${sportShort[best['sport']]} · ${best['window']}',
            sub: '${best['reason']}',
            minHeight: 0,
            onTap: () => context.push('/activities/${best['sport']}'),
          );
        }
        return InkWell(
          borderRadius: BorderRadius.circular(OgRadius.card),
          onTap: () => context.push('/activities/${best['sport']}'),
          child: OgCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('BEST TODAY', style: OgText.label.copyWith(color: c.text2)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${sportShort[best['sport']]} · ${best['window']}',
                        style: OgText.verdictBest.copyWith(color: c.text),
                      ),
                    ),
                    OgRatingDots(value: best['rating'] as num, large: true),
                  ],
                ),
                const SizedBox(height: 4),
                Text('${best['reason']}', style: OgText.verdictSummary.copyWith(color: c.text2)),
                if (best['note'] != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(color: c.water, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text('${best['note']}', style: OgText.day.copyWith(color: c.text)),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      case 'warnings':
        if (d.warnings.isEmpty) return null;
        if (minimal) {
          final w = d.warnings.first;
          return InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => showWarningSheet(context, w),
            child: OgWarningBanner(
              level: w.level,
              title: d.warnings.length == 1
                  ? w.title
                  : '${d.warnings.length} warnings: ${d.warnings.map((x) => x.title.split(' · ').last).join(', ')}',
              pre: w.pre,
            ),
          );
        }
        return Column(
          children: [
            for (final (i, w) in d.warnings.indexed) ...[
              if (i > 0) const SizedBox(height: 10),
              InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => showWarningSheet(context, w),
                child: OgWarningBanner(level: w.level, title: w.title, detail: w.detail, pre: w.pre),
              ),
            ],
          ],
        );
      case 'current':
        if (minimal) {
          return ValueTile(
            icon: Icons.thermostat_outlined,
            label: '${cur['place']} now',
            value: '${u.tempText(cur['temp'] as num)} · ${cur['summary']}',
            sub: '${cur['wind']} · ${cur['source']}',
            minHeight: 0,
            onTap: () => open(Metric.temp),
          );
        }
        return InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => open(Metric.temp),
          child: OgCurrentConditions(
            place: '${cur['place']}',
            source: '${cur['source']}',
            sky: skyOf(cur),
            temp: u.tempValue(cur['temp'] as num).round(),
            summary: '${cur['summary']}',
            feels: u.tempValue(cur['feels'] as num).round(),
            min: u.tempValue(cur['min'] as num).round(),
            max: u.tempValue(cur['max'] as num).round(),
            wind: '${cur['wind']}',
          ),
        );
      case 'hourly':
        if (minimal) return _HourStrip(n24: n24, units: u, onTap: () => open(Metric.temp));
        return OgCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('NEXT 24 HOURS', style: OgText.label.copyWith(color: c.text2)),
                  const Spacer(),
                  TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: c.text2,
                      minimumSize: const Size(44, 32),
                      padding: EdgeInsets.zero,
                    ),
                    onPressed: () => open(Metric.temp),
                    child: const Text('7 days ›'),
                  ),
                ],
              ),
              interactiveNextHours(n24, semanticLabel: 'Next 24 hours'),
            ],
          ),
        );
      case 'sports':
        final mine = app.mySports;
        final sports = d.sports.where((a) => mine.contains(a.sport)).toList();
        if (sports.isEmpty) return null;
        if (minimal) {
          return OgCard(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final a in sports)
                  ActionChip(
                    backgroundColor: c.surface2,
                    side: BorderSide.none,
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('${sportShort[a.sport]} ', style: OgText.chip.copyWith(color: c.text)),
                        OgRatingDots(value: a.rating),
                      ],
                    ),
                    onPressed: () => context.push('/activities/${a.sport}'),
                  ),
              ],
            ),
          );
        }
        return OgCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Column(
            children: [
              for (final (i, a) in sports.indexed)
                OgActivityRow(
                  sport: a.sport,
                  rating: a.rating,
                  window: a.window,
                  reason: a.reason,
                  last: i == sports.length - 1,
                  onTap: () => context.push('/activities/${a.sport}'),
                ),
            ],
          ),
        );
      case 'days':
        final days = minimal ? d.days.take(3).toList() : d.days;
        return OgCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Column(
            children: [
              for (final (i, day) in days.indexed)
                InkWell(
                  onTap: () => showDaySheet(
                    context,
                    day,
                    onPlan: i <= 2
                        ? () {
                            Navigator.of(context).pop();
                            context.push('/activities');
                          }
                        : null,
                  ),
                  child: OgForecastDayRow(
                    day: '${day['day']}',
                    sky: skyOf(day),
                    rainChance: (day['rainChance'] as num).toInt(),
                    min: u.tempValue(day['min'] as num).round(),
                    max: u.tempValue(day['max'] as num).round(),
                    scale: [for (final x in d.scale) u.tempValue(x).round()],
                  ),
                ),
            ],
          ),
        );
      case 'wind':
        final f = fact('Wind');
        final w = next('wind');
        return metricTile(
          Metric.wind,
          value: f?.value ?? '—',
          sub: f?.sub,
          spark: w,
          lo: 0,
          extra: w.isEmpty
              ? null
              : 'Up to ${u.windText(w.whereType<double>().fold<double>(0, (a, b) => a > b ? a : b))} in the next 24 h',
        );
      case 'rain':
        final f = fact('Rain');
        final mm = obs?['rain3h'] as num?;
        return metricTile(
          Metric.rain,
          value: f?.value ?? '—',
          sub: f?.sub,
          spark: next('rain'),
          bars: true,
          lo: 0,
          hiV: 100,
          extra: mm == null ? null : '${mm.toStringAsFixed(1)} mm measured in the last 3 h',
        );
      case 'uv':
        final f = fact('UV');
        return metricTile(Metric.uv, value: f?.value ?? '—', sub: f?.sub, spark: next('uv'), lo: 0, hiV: 8);
      case 'feels':
        final feels = cur['feels'] as num?;
        final diff = feels == null ? 0 : feels - (cur['temp'] as num);
        return metricTile(
          Metric.feels,
          value: u.tempText(feels),
          sub: diff.abs() < 1.5
              ? 'Close to the actual temperature'
              : (diff < 0 ? 'Wind makes it feel colder' : 'Humidity makes it feel warmer'),
          spark: next('feels'),
        );
      case 'humidity':
        final rh = (obs?['humidity'] as num?)?.toDouble() ?? hourlyNow('humidity');
        if (rh == null) return null;
        final dew = hourlyNow('dew');
        return metricTile(
          Metric.humidity,
          value: '${rh.round()} %',
          sub: dew == null ? null : 'Dew point ${u.tempText(dew)}',
          spark: next('humidity'),
          lo: 0,
          hiV: 100,
          extra: obs?['humidity'] == null ? null : 'Measured at ${obs!['station']}',
        );
      case 'pressure':
        final p = (obs?['pressure'] as num?)?.toDouble() ?? hourlyNow('pressure');
        if (p == null) return null;
        final word = obs?['pressureWord'] as String?;
        return metricTile(
          Metric.pressure,
          value: '${p.round()} hPa',
          sub: word == null ? null : '${word[0].toUpperCase()}${word.substring(1)} (${obs!['pressureTrend']} hPa in 3 h)',
          spark: hourly24('pressure'),
        );
      case 'visibility':
        final v = hourlyNow('visibility');
        if (v == null) return null;
        return metricTile(
          Metric.visibility,
          value: '${v.toStringAsFixed(v < 10 ? 1 : 0)} km',
          sub: v < 1 ? 'Fog' : (v < 5 ? 'Haze or mist' : 'Clear'),
          spark: hourly24('visibility'),
          lo: 0,
        );
      case 'cloud':
        final v = hourlyNow('cloud');
        if (v == null) return null;
        return metricTile(Metric.cloud, value: '${v.round()} %', spark: hourly24('cloud'), lo: 0, hiV: 100);
      case 'water':
        final f = fact('Water');
        if (f == null || f.value == '—') return null;
        return ValueTile(
          icon: Icons.waves,
          label: 'Sea water',
          value: f.value,
          sub: f.sub,
          color: c.water,
          onTap: () => showFactSheet(context, f, source: d.sources),
        );
      case 'sun':
        if (d.daylight.length < 2) return null;
        final rise = d.daylight[0].value, set = d.daylight[1].value;
        final hm = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
        final beforeRise = hm.compareTo(rise) < 0, afterSet = hm.compareTo(set) >= 0;
        return ValueTile(
          icon: Icons.wb_twilight,
          label: beforeRise || afterSet ? 'Sunrise' : 'Sunset',
          value: beforeRise || afterSet ? (afterSet && h != null && h.days.length > 1 ? '${h.days[1]['sunrise']}' : rise) : set,
          sub: beforeRise || afterSet ? 'Sunset $set' : 'Sunrise $rise · ${d.daylight[1].sub ?? ''}',
          color: c.sun,
          onTap: () => showFactSheet(context, d.daylight[1]),
        );
      case 'station':
        if (obs == null) return null;
        final parts = [
          if (obs['rain3h'] != null) 'rain ${(obs['rain3h'] as num).toStringAsFixed(1)} mm / 3 h',
          if (obs['humidity'] != null) 'humidity ${(obs['humidity'] as num).round()} %',
          if (obs['pressure'] != null) '${(obs['pressure'] as num).round()} hPa ${obs['pressureWord'] ?? ''}',
          if (obs['uv'] != null) 'UV ${obs['uv']}',
          if (obs['snow'] != null) 'snow ${obs['snow']} cm',
        ];
        return ValueTile(
          icon: Icons.sensors,
          label: 'Station now',
          value: '${obs['station']}',
          sub: '${obs['km'] == null ? '' : '${obs['km']} km away · '}${obs['at']}',
          extra: parts.isEmpty ? null : parts.join(' · '),
          onTap: () => open(Metric.temp),
        );
      case 'lightning':
        final lt = obs?['lightning'] as Json?;
        if (lt == null) return null;
        final count = (lt['count'] as num?)?.toInt() ?? 0;
        return ValueTile(
          icon: Icons.bolt,
          label: 'Lightning',
          value: count == 0 ? 'None' : '$count strikes',
          sub: count == 0 ? 'Within 30 km, last 2 h' : 'Nearest ${lt['nearest_km']} km · last ${lt['last']}',
          color: count == 0 ? null : c.storm,
        );
      case 'confidence':
        if (d.confidence == null) return null;
        if (minimal) {
          final r = (d.confidence!['rows'] as List).first as Json;
          return ValueTile(
            icon: Icons.verified_outlined,
            label: 'Forecast confidence',
            value: '${r['pct']} %',
            sub: '${r['label']}',
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('FORECAST CONFIDENCE', style: OgText.label.copyWith(color: c.text2)),
            const SizedBox(height: 8),
            _Confidence(d.confidence!),
          ],
        );
    }
    return null;
  }
}

/// Apple-style hour strip: time, icon, temperature (the minimal form of "Next 24 hours").
class _HourStrip extends StatelessWidget {
  const _HourStrip({required this.n24, required this.units, required this.onTap});
  final Json n24;
  final Units units;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.og;
    final temps = nums(n24['temps']);
    final sky = [for (final s in n24['sky'] as List) weatherKindFrom(s as String)];
    final rain = nums(n24['rain']);
    final start = (n24['startHour'] as num).toInt();
    return Material(
      color: c.surface,
      borderRadius: BorderRadius.circular(OgRadius.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(OgRadius.card),
        onTap: onTap,
        child: SizedBox(
          height: 108,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            itemCount: temps.length,
            itemBuilder: (context, i) => SizedBox(
              width: 52,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    i == 0 ? 'Now' : ((start + i) % 24).toString().padLeft(2, '0'),
                    style: OgText.chip.copyWith(color: c.text2, fontWeight: i == 0 ? FontWeight.w700 : FontWeight.w400),
                  ),
                  OgWeatherIcon(sky[i], size: 24),
                  Text(rain[i] >= 30 ? '${rain[i].round()}%' : '', style: OgText.chip.copyWith(color: c.water, fontSize: 11)),
                  Text(units.tempText(temps[i]), style: OgText.actName.copyWith(color: c.text)),
                ],
              ),
            ),
          ),
        ),
      ),
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
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(current ? Icons.my_location : Icons.place_outlined, size: 18, color: c.text),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        name,
                        overflow: TextOverflow.ellipsis,
                        style: OgText.actName.copyWith(color: c.text),
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(Icons.expand_more, size: 20, color: c.text2),
                  ],
                ),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${data['intro']}', style: OgText.src.copyWith(color: c.text2)),
          const SizedBox(height: 8),
          for (final r in data['rows'] as List)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  SizedBox(
                    width: 50,
                    child: Text('${r['day']}', style: OgText.day.copyWith(color: c.text)),
                  ),
                  Expanded(
                    child: Text('${r['label']}', style: OgText.chip.copyWith(color: c.text2)),
                  ),
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
                    child: Text(
                      '${r['pct']} %',
                      textAlign: TextAlign.right,
                      style: OgText.day.copyWith(color: c.text),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
