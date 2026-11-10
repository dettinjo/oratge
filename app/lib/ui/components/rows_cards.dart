import 'package:flutter/material.dart';

import '../../theme/og_helpers.dart';
import '../../theme/oratge_tokens.dart';
import '../motion.dart';
import 'basics.dart';
import 'weather_icon.dart';

const sportNames = {'wing': 'Wing foil', 'surf': 'Surf', 'bike': 'Bike', 'run': 'Run', 'hike': 'Hike'};
const sportShort = {'wing': 'Wing', 'surf': 'Surf', 'bike': 'Bike', 'run': 'Run', 'hike': 'Hike'};
const sportIcon = {
  'wing': WeatherKind.wind,
  'surf': WeatherKind.wave,
  'bike': WeatherKind.sun,
  'run': WeatherKind.uv,
  'hike': WeatherKind.storm,
};

/// One row of "Today for you".
class OgActivityRow extends StatelessWidget {
  const OgActivityRow(
      {super.key,
      required this.sport,
      required this.rating,
      required this.window,
      required this.reason,
      this.last = false,
      this.onTap});
  final String sport;
  final int rating;
  final String window;
  final String reason;
  final bool last;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.og;
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 52),
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(border: last ? null : Border(bottom: BorderSide(color: c.line))),
        child: Row(children: [
          OgWeatherIcon(sportIcon[sport] ?? WeatherKind.sun, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(sportShort[sport] ?? sport, style: OgText.actName.copyWith(color: c.text)),
              Text(reason, style: OgText.actWhy.copyWith(color: c.text2)),
            ]),
          ),
          OgRatingDots(value: rating),
          SizedBox(
            width: 92,
            child: Text(window,
                textAlign: TextAlign.right,
                style: OgText.actWindow.copyWith(color: c.text)),
          ),
        ]),
      ),
    );
  }
}

/// One line of the 7-day list.
class OgForecastDayRow extends StatelessWidget {
  const OgForecastDayRow(
      {super.key,
      required this.day,
      required this.sky,
      required this.rainChance,
      required this.min,
      required this.max,
      required this.scale});
  final String day;
  final WeatherKind sky;
  final int rainChance;
  final num min;
  final num max;
  final List<num> scale;

  @override
  Widget build(BuildContext context) {
    final c = context.og;
    final lo = scale[0], hi = scale[1];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(children: [
        SizedBox(width: 52, child: Text(day, style: OgText.day.copyWith(color: c.text))),
        OgWeatherIcon(sky, size: 20),
        SizedBox(
          width: 44,
          child: Text(rainChance > 0 ? '$rainChance%' : '',
              textAlign: TextAlign.right, style: OgText.chip.copyWith(color: c.text2)),
        ),
        const Spacer(),
        SizedBox(width: 30, child: Text('${min.round()}°', textAlign: TextAlign.right, style: OgText.day.copyWith(color: c.text2))),
        const SizedBox(width: 10),
        SizedBox(
          width: 110,
          height: 4,
          child: LayoutBuilder(builder: (context, b) {
            final w = b.maxWidth;
            return Stack(children: [
              Container(decoration: BoxDecoration(color: c.surface2, borderRadius: BorderRadius.circular(2))),
              Positioned(
                left: (min - lo) / (hi - lo) * w,
                width: ((max - min) / (hi - lo) * w).clamp(4, w),
                top: 0,
                bottom: 0,
                child: Container(
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      gradient: LinearGradient(colors: [c.sun, c.heat])),
                ),
              ),
            ]);
          }),
        ),
        const SizedBox(width: 10),
        SizedBox(width: 28, child: Text('${max.round()}°', style: OgText.day.copyWith(color: c.text))),
      ]),
    );
  }
}

/// Planner verdict: rating, best window, reasoning.
class OgVerdictCard extends StatelessWidget {
  const OgVerdictCard({super.key, required this.rating, required this.best, required this.summary, this.confidence});
  final int rating;
  final String best;
  final String summary;
  final String? confidence;

  @override
  Widget build(BuildContext context) {
    final c = context.og;
    return OgCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          OgRatingDots(value: rating, large: true, showWord: true),
          const SizedBox(width: 8),
          const Spacer(),
          if (confidence != null) Flexible(child: OgPill(confidence!)),
        ]),
        const SizedBox(height: 10),
        Text(best, style: OgText.verdictBest.copyWith(color: c.text)),
        const SizedBox(height: 3),
        Text(summary, style: OgText.verdictSummary.copyWith(color: c.text2)),
      ]),
    );
  }
}

/// Official Meteocat warning (or a lighter pre-warning). Always icon + level word.
class OgWarningBanner extends StatelessWidget {
  const OgWarningBanner({super.key, required this.level, required this.title, this.detail, this.pre = false});
  final String level;
  final String title;
  final String? detail;
  final bool pre;

  @override
  Widget build(BuildContext context) {
    final c = context.og;
    final col = c.warningColor(level);
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: pre ? c.surface : Color.alphaBlend(col.withValues(alpha: 0.12), c.surface),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: pre ? c.line : col.withValues(alpha: 0.45)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: CustomPaint(size: const Size.square(18), painter: _TrianglePainter(col, pre, c.bg)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: OgText.actWindow.copyWith(fontSize: 14, color: c.text)),
              if (detail != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(detail!, style: OgText.chip.copyWith(color: c.text2)),
                ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _TrianglePainter extends CustomPainter {
  _TrianglePainter(this.col, this.pre, this.bg);
  final Color col;
  final bool pre;
  final Color bg;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24);
    final tri = Path()
      ..moveTo(12, 3)
      ..lineTo(22, 21)
      ..lineTo(2, 21)
      ..close();
    if (pre) {
      canvas.drawPath(
          tri,
          Paint()
            ..color = col
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.8
            ..strokeJoin = StrokeJoin.round);
    } else {
      canvas.drawPath(tri, Paint()..color = col);
    }
    final mark = Paint()
      ..color = pre ? col : bg
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(12, 10), const Offset(12, 15), mark);
    canvas.drawLine(const Offset(12, 17.5), const Offset(12, 18), mark);
  }

  @override
  bool shouldRepaint(_TrianglePainter old) => old.col != col || old.pre != pre;
}

/// Day picker with a rating tick per day.
class OgDayTabs extends StatelessWidget {
  const OgDayTabs({super.key, required this.days, required this.selected, this.onSelect});
  final List<({String weekday, String date, int rating, bool outlook})> days;
  final int selected;
  final ValueChanged<int>? onSelect;

  @override
  Widget build(BuildContext context) {
    final c = context.og;
    return Row(children: [
      for (var i = 0; i < days.length; i++)
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i == days.length - 1 ? 0 : 6),
            child: Semantics(
              button: true,
              selected: i == selected,
              label: '${days[i].weekday} ${days[i].date}, rating ${days[i].rating}',
              excludeSemantics: true,
              child: Opacity(
                opacity: days[i].outlook && i != selected ? 0.55 : 1,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: onSelect == null ? null : () => onSelect!(i),
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 52),
                    padding: const EdgeInsets.only(top: 6, bottom: 7),
                    decoration: BoxDecoration(
                        color: i == selected ? c.text : c.surface, borderRadius: BorderRadius.circular(12)),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(days[i].weekday, style: OgText.tab.copyWith(color: i == selected ? c.bg : c.text2)),
                      Text(days[i].date,
                          style: OgText.actName
                              .copyWith(fontWeight: FontWeight.w600, color: i == selected ? c.bg : c.text)),
                      const SizedBox(height: 3),
                      Container(
                        width: 14,
                        height: 4,
                        decoration: BoxDecoration(
                            color: c.ratingColor(days[i].rating), borderRadius: BorderRadius.circular(2)),
                      ),
                    ]),
                  ),
                ),
              ),
            ),
          ),
        ),
    ]);
  }
}

/// Today hero: place, source + age, big temperature, sky, feels, range, wind.
class OgCurrentConditions extends StatelessWidget {
  const OgCurrentConditions(
      {super.key,
      required this.place,
      required this.source,
      required this.sky,
      required this.temp,
      required this.summary,
      required this.feels,
      required this.min,
      required this.max,
      required this.wind});
  final String place;
  final String source;
  final WeatherKind sky;
  final num temp;
  final String summary;
  final num feels;
  final num min;
  final num max;
  final String wind;

  @override
  Widget build(BuildContext context) {
    final c = context.og;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(place, style: OgText.body.copyWith(fontSize: 17, fontWeight: FontWeight.w600, color: c.text)),
      const SizedBox(height: 2),
      Text(source, style: OgText.src.copyWith(color: c.text2)),
      const SizedBox(height: 16),
      Row(children: [
        OgWeatherIcon(sky, size: 62),
        const SizedBox(width: 14),
        CountUp(value: temp.round(), suffix: '°', style: OgText.heroTemp.copyWith(color: c.text)),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(summary, style: OgText.body.copyWith(fontSize: 15, fontWeight: FontWeight.w500, color: c.text)),
            const SizedBox(height: 4),
            Text('Feels ${feels.round()}° · ↓${min.round()}° ↑${max.round()}°', style: OgText.day.copyWith(color: c.text2)),
            const SizedBox(height: 2),
            Text(wind, style: OgText.day.copyWith(color: c.text2)),
          ]),
        ),
      ]),
    ]);
  }
}

/// Saved place with live wind and today's rating strip.
class OgSpotCard extends StatelessWidget {
  const OgSpotCard(
      {super.key,
      required this.name,
      required this.kind,
      required this.wind,
      required this.gust,
      required this.windFrom,
      required this.today,
      required this.window,
      required this.rating,
      this.onTap});
  final String name;
  final String kind;
  final num wind;
  final num gust;
  final num windFrom;
  final List<num> today;
  final String window;
  final int rating;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.og;
    return InkWell(
      borderRadius: BorderRadius.circular(OgRadius.card),
      onTap: onTap,
      child: OgCard(
        padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
        child: Column(children: [
          Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name, style: OgText.body.copyWith(fontSize: 15, fontWeight: FontWeight.w600, color: c.text)),
                Text(kind, style: OgText.src.copyWith(color: c.text2)),
              ]),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Row(children: [
                Transform.rotate(
                  angle: (windFrom + 180) * 3.141592653589793 / 180,
                  child: Icon(Icons.arrow_upward_rounded, size: 16, color: c.windColor(wind)),
                ),
                const SizedBox(width: 4),
                Text('${wind.round()}', style: OgText.factValue.copyWith(fontSize: 20, color: c.text)),
                Text(' kn', style: OgText.src.copyWith(color: c.text2)),
              ]),
              Text('gusts ${gust.round()}', style: OgText.src.copyWith(color: c.text2)),
            ]),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: OgRatingStrip(values: today)),
            const SizedBox(width: 10),
            Text(window, style: OgText.chip.copyWith(fontWeight: FontWeight.w600, color: c.text)),
          ]),
        ]),
      ),
    );
  }
}
