import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../motion.dart';

import '../../data/models.dart';
import '../../theme/og_helpers.dart';
import '../../theme/oratge_tokens.dart';
import '../charts/charts.dart';
import 'basics.dart';
import 'rows_cards.dart';
import 'scrub.dart';
import 'weather_icon.dart';

/// What each number means and why it matters — shown in the detail sheet.
const glossary = <String, String>{
  'wind': 'Mean wind at 10 m over the hour. Wing foiling needs a steady breeze inside your range; '
      'cyclists feel it as headwind or tailwind.',
  'gusts': 'The strongest short burst in the hour. The gap between gusts and mean wind (gust factor) '
      'tells how smooth the wind is: under ×1.3 feels steady, over ×1.5 is gusty.',
  'waves': 'Significant wave height: the average of the highest third of waves. Chop under 0.5 m is '
      'flat-water riding; surf needs a long enough period too.',
  'swell': 'Height of the swell part of the sea state (waves from distant wind). With a long period it '
      'reaches the beach as clean, ridable waves.',
  'period': 'Seconds between wave crests. Under 7 s is wind swell (weak, messy); 9 s and more carries '
      'energy and breaks cleanly.',
  'air': 'Air temperature at 2 m. Feels-like adds wind chill and humidity.',
  'temp': 'Air temperature at 2 m. The dashed line in charts is the feels-like temperature.',
  'rain': 'Chance of rain in the hour (share of forecast runs with measurable rain).',
  'showers': 'When the first showers are expected and how much rain they bring.',
  'uv': 'UV index. 0–2 low, 3–5 moderate (sunscreen for long sessions), 6–7 high, 8+ very high.',
  'water': 'Sea surface temperature. It sets the wetsuit: 22°+ shorty, 18–22° 3/2, 15–18° 4/3, colder 5/4 with boots.',
  'storm': 'Thunderstorm risk, estimated from atmospheric instability (CAPE), showers and thunder codes. '
      'In the mountains, plan to be off exposed ground before it passes your limit.',
  'summit': 'Temperature on the summit, scaled from the forecast with the standard lapse rate (−6.5° per 1000 m).',
  'snow level': 'Altitude above which precipitation falls as snow (about 300 m below the freezing level).',
  'sunrise': 'First direct sun. Usable light starts about 25 minutes earlier.',
  'sunset': 'Sun below the horizon. Last light is about 28 minutes later.',
  'bias': 'Average difference between what the station measured and what was forecast here. Oratge '
      'corrects today’s plan by it.',
  'error': 'Average size of the forecast miss, ignoring the sign.',
  'hit rate': 'How often the forecast rating was within one point of the rating from the measurements.',
  'roads': 'Wet or dry from rain measured in the last hours and the drying rate.',
};

String _explain(String label) {
  final k = label.toLowerCase();
  for (final e in glossary.entries) {
    if (k.startsWith(e.key) || k.contains(e.key)) return e.value;
  }
  return '';
}

Future<void> showOgSheet(BuildContext context, {required Widget child, double maxWidth = 640, double initialSize = 0.62}) {
  final c = context.og;
  // Wide windows (Mac, desktop, tablets in landscape): a centred panel that fades in, like a macOS
  // sheet, instead of a card sliding up from the bottom edge. Esc or a click outside closes it.
  if (MediaQuery.sizeOf(context).width >= 840) {
    return showGeneralDialog(
      context: context,
      useRootNavigator: true,
      barrierDismissible: true,
      barrierLabel: 'Close',
      barrierColor: Colors.black.withValues(alpha: 0.45),
      transitionDuration: motion(context, 180),
      pageBuilder: (context, _, _) => SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: MediaQuery.sizeOf(context).height * 0.86),
            child: Material(
              color: c.bg,
              elevation: 12,
              shadowColor: Colors.black,
              borderRadius: BorderRadius.circular(22),
              clipBehavior: Clip.antiAlias,
              child: Stack(children: [
                ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(28, 26, 28, 28), children: [child]),
                Positioned(
                  top: 8,
                  right: 8,
                  child: IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close, color: c.text2),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
      transitionBuilder: (context, a, _, child) {
        final t = CurvedAnimation(parent: a, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
        return FadeTransition(
          opacity: t,
          child: ScaleTransition(scale: Tween(begin: 0.96, end: 1.0).animate(t), child: child),
        );
      },
    );
  }
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useRootNavigator: true, // cover the bottom navigation too
    backgroundColor: c.bg,
    useSafeArea: true,
    constraints: const BoxConstraints(maxWidth: 640),
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: initialSize,
      maxChildSize: 0.95,
      minChildSize: 0.3,
      builder: (context, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
        children: [child],
      ),
    ),
  );
}

/// A series to plot in a fact's detail sheet (one value per hour).
class Series {
  const Series({required this.values, required this.startHour, required this.unit, required this.accent, this.band, this.decimals = 0, this.title});
  final List<num> values;
  final List<num>? band;
  final int startHour;
  final String unit;
  final OgAccent accent;
  final int decimals;
  final String? title;
}

/// Detail for one number: big value, explanation, its curve through the day (interactive) and stats.
Future<void> showFactSheet(BuildContext context, Fact f, {Series? series, String? source}) {
  return showOgSheet(context, child: _FactDetail(f, series, source));
}

class _FactDetail extends StatelessWidget {
  const _FactDetail(this.f, this.s, this.source);
  final Fact f;
  final Series? s;
  final String? source;

  @override
  Widget build(BuildContext context) {
    final c = context.og;
    final accent = accentFromString(f.accent);
    final text = _explain(f.label);
    final ser = s;
    String fmt(num v) => ser != null && ser.decimals > 0 ? v.toStringAsFixed(ser.decimals) : v.round().toString();
    // "18°", "14 kn", "60 %": degrees attach to the number, other units get a space.
    String withUnit(num v) => ser == null || ser.unit.isEmpty
        ? fmt(v)
        : (ser.unit.startsWith('°') ? '${fmt(v)}${ser.unit}' : '${fmt(v)} ${ser.unit}');
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(f.label.toUpperCase(), style: OgText.label.copyWith(color: c.text2)),
      const SizedBox(height: 6),
      Text(f.value, style: OgText.factValueLg.copyWith(fontSize: 44, color: accent == null ? c.text : c.accent(accent))),
      if (f.sub != null) Text(f.sub!, style: OgText.verdictSummary.copyWith(color: c.text2)),
      if (text.isNotEmpty) ...[
        const SizedBox(height: 16),
        Text(text, style: OgText.verdictSummary.copyWith(color: c.text)),
      ],
      if (ser != null && ser.values.length > 1) ...[
        OgSectionLabel(ser.title ?? 'Through the day'),
        OgCard(
          child: Scrub(
            count: ser.values.length,
            indexAt: (dx, w) => indexTrend(dx, w, ser.values.length),
            chart: (sel) => OgTrendLine(
              values: ser.values,
              band: ser.band,
              accent: ser.accent,
              min: math.min(0, ser.values.reduce(math.min)),
              caption: ['${ser.startHour.toString().padLeft(2, '0')} h', '${((ser.startHour + ser.values.length - 1) % 24).toString().padLeft(2, '0')} h'],
              height: 120,
              selected: sel,
            ),
            readout: (i, c) => (
              '${((ser.startHour + i) % 24).toString().padLeft(2, '0')} h',
              [
                ReadoutItem(f.label.toLowerCase(), withUnit(ser.values[i]), color: c.accent(ser.accent)),
                if (ser.band != null && i < ser.band!.length) ReadoutItem('gusts', withUnit(ser.band![i])),
              ]
            ),
          ),
        ),
        const SizedBox(height: 10),
        OgFactGrid(columns: 3, children: [
          OgFactTile(label: 'Low', value: withUnit(ser.values.reduce(math.min))),
          OgFactTile(label: 'High', value: withUnit(ser.values.reduce(math.max))),
          OgFactTile(
              label: 'Average',
              value: withUnit(ser.values.fold<num>(0, (a, b) => a + b) / ser.values.length)),
        ]),
      ],
      if (source != null) OgDataSources(source!),
    ]);
  }
}

/// Finds the hour-chart row that matches a fact ("Gusts" → gust row or the wind line's band, …).
Series? seriesFromHourChart(Json chart, Fact f) {
  final hours = [for (final h in chart['hours'] as List) (h as num).toInt()];
  final rows = [for (final r in chart['rows'] as List) HourRow.fromJson(r as Json)];
  final k = f.label.toLowerCase();
  HourRow? find(bool Function(HourRow r) t) => rows.where(t).firstOrNull;
  final accent = accentFromString(f.accent) ?? OgAccent.neutral;
  Series mk(List<num> v, String unit, {List<num>? band, int dec = 0}) =>
      Series(values: v, band: band, startHour: hours.first, unit: unit, accent: accent, decimals: dec);
  if (k.startsWith('gust')) {
    final g = find((r) => r.label.toLowerCase().startsWith('gust'));
    if (g != null) return mk(g.values, 'kn');
    final w = find((r) => r.type == 'line' && r.label.toLowerCase().startsWith('wind') && r.band != null);
    if (w != null) return mk(w.band!, 'kn');
  }
  if (k.startsWith('wind') || k == 'tailwind') {
    final w = find((r) => r.type == 'line' && r.label.toLowerCase().startsWith('wind')) ??
        find((r) => r.type == 'numbers' && (r.label.toLowerCase().startsWith('speed') || r.label.toLowerCase().startsWith('wind')));
    if (w != null) return mk(w.values, 'kn', band: w.band);
  }
  if (k.startsWith('wave') || k.startsWith('swell')) {
    final w = find((r) => r.label.toLowerCase().startsWith('wave'));
    if (w != null) return mk(w.values, 'm', dec: 1);
  }
  if (k.startsWith('period')) {
    final w = find((r) => r.label.toLowerCase().startsWith('period'));
    if (w != null) return mk(w.values, 's');
  }
  if (k.startsWith('air') || k.startsWith('temp') || k.startsWith('summit') || k.startsWith('hottest')) {
    final w = find((r) => r.label.toLowerCase().startsWith('air') || r.label.toLowerCase().startsWith('temp'));
    if (w != null) return mk(w.values, '°');
  }
  if (k.startsWith('rain') || k.startsWith('showers')) {
    final w = find((r) => r.label.toLowerCase().startsWith('rain'));
    if (w != null) return mk(w.values, w.unit ?? '', dec: w.decimals);
  }
  if (k.startsWith('uv')) {
    final w = find((r) => r.label.toLowerCase() == 'uv');
    if (w != null) return mk(w.values, '');
  }
  if (k.startsWith('storm')) {
    final w = find((r) => r.label.toLowerCase().startsWith('storm'));
    if (w != null) return mk(w.values, '%');
  }
  if (k.startsWith('snow')) {
    final w = find((r) => r.label.toLowerCase().startsWith('snow'));
    if (w != null) return mk(w.values, 'm');
  }
  return null;
}

/// Today's "Right now" tiles → their next-24 h series.
Series? seriesFromNext24(Json n, Fact f) {
  final start = (n['startHour'] as num?)?.toInt() ?? 0;
  final k = f.label.toLowerCase();
  final accent = accentFromString(f.accent) ?? OgAccent.neutral;
  List<num>? get(String key) => n[key] == null ? null : nums(n[key]);
  if (k.startsWith('wind') && get('wind') != null) {
    return Series(values: get('wind')!, band: get('gust'), startHour: start, unit: 'kn', accent: accent, title: 'Next 24 hours');
  }
  if (k.startsWith('rain') && get('rain') != null) {
    return Series(values: get('rain')!, startHour: start, unit: '%', accent: accent, title: 'Next 24 hours');
  }
  if (k.startsWith('uv') && get('uv') != null) {
    return Series(values: get('uv')!, startHour: start, unit: '', accent: accent, title: 'Next 24 hours', decimals: 1);
  }
  return null;
}

/// Why the rating is what it is: every factor with its weight and score.
Future<void> showVerdictSheet(BuildContext context, Json verdict, Analysis? a) {
  final c = context.og;
  return showOgSheet(
    context,
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      OgRatingDots(value: verdict['rating'] as num, large: true, showWord: true),
      const SizedBox(height: 10),
      Text('${verdict['best']}', style: OgText.verdictBest.copyWith(color: c.text)),
      const SizedBox(height: 4),
      Text('${verdict['summary']}', style: OgText.verdictSummary.copyWith(color: c.text2)),
      if (a != null) ...[
        OgSectionLabel('How the ${a.total} / 5 comes together'),
        for (final f in a.factors)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(f.factor, style: OgText.actName.copyWith(color: c.text))),
                Text('${(f.score * f.weight / 100 * 5).toStringAsFixed(2)} pts',
                    style: OgText.chip.copyWith(color: c.text, fontWeight: FontWeight.w600)),
              ]),
              const SizedBox(height: 4),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: f.score.toDouble()),
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOutCubic,
                builder: (context, v, _) => ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                      value: v, minHeight: 6, backgroundColor: c.surface2, color: c.accent(accentFromString(f.accent) ?? OgAccent.neutral)),
                ),
              ),
              const SizedBox(height: 3),
              Text('${f.observed} · weight ${f.weight} %', style: OgText.chip.copyWith(color: c.text2)),
            ]),
          ),
        const SizedBox(height: 8),
        Text('Rating = 5 × the weighted sum of the factor scores, rounded. Night, offshore wind (wing) or storms above your limit (hike) cap it.',
            style: OgText.src.copyWith(color: c.text2)),
      ],
    ]),
  );
}

const _warnAdvice = {
  'yellow': 'Moderate: be aware. Conditions can be risky for exposed activities; check before you go.',
  'orange': 'High: be prepared. Avoid exposed activities in the affected area and time window.',
  'red': 'Very high: take action. Don’t go; follow Protecció Civil instructions.',
};

Future<void> showWarningSheet(BuildContext context, Warning w) {
  final c = context.og;
  return showOgSheet(
    context,
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      OgWarningBanner(level: w.level, title: w.title, detail: w.detail, pre: w.pre),
      const SizedBox(height: 16),
      Text(w.pre ? 'Pre-warning: Meteocat expects a warning to be issued.' : _warnAdvice[w.level] ?? '',
          style: OgText.verdictSummary.copyWith(color: c.text)),
      const SizedBox(height: 12),
      Text('Warning levels follow Meteocat’s scale (SMP): yellow, orange, red. Oratge shows the official text unchanged.',
          style: OgText.src.copyWith(color: c.text2)),
      const OgDataSources('Meteocat warnings (SMP)'),
    ]),
  );
}

Future<void> showDaySheet(BuildContext context, Json day, {VoidCallback? onPlan}) {
  final c = context.og;
  return showOgSheet(
    context,
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text('${day['day']}', style: OgText.verdictBest.copyWith(color: c.text)),
        const Spacer(),
        OgWeatherIconFromName('${day['sky']}', size: 44),
      ]),
      const SizedBox(height: 12),
      OgFactGrid(columns: 3, children: [
        OgFactTile(label: 'Low', value: '${day['min']}°', accent: OgAccent.heat),
        OgFactTile(label: 'High', value: '${day['max']}°', accent: OgAccent.heat),
        OgFactTile(label: 'Rain', value: '${day['rainChance']} %', accent: OgAccent.water),
      ]),
      const SizedBox(height: 14),
      Text(_explain('rain'), style: OgText.src.copyWith(color: c.text2)),
      if (onPlan != null) ...[
        const SizedBox(height: 16),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: c.text, foregroundColor: c.bg, minimumSize: const Size.fromHeight(48)),
          onPressed: onPlan,
          child: const Text('Plan sports for this day'),
        ),
      ],
    ]),
  );
}
