// App <-> backend data contract. Sample data in assets/sample is generated with the same shapes
// (tool/gen_sample.py); the backend's /v1 endpoints return them too.

typedef Json = Map<String, dynamic>;

List<T> _list<T>(dynamic v, T Function(Json) f) => [for (final e in (v as List? ?? const [])) f(e as Json)];
List<num> nums(dynamic v) => [for (final e in (v as List? ?? const [])) e as num];
List<String> strs(dynamic v) => [for (final e in (v as List? ?? const [])) e as String];

class Fact {
  Fact({required this.label, required this.value, this.sub, this.accent, this.large = false});
  final String label, value;
  final String? sub, accent;
  final bool large;
  factory Fact.fromJson(Json j) => Fact(
      label: j['label'] as String,
      value: '${j['value']}',
      sub: j['sub'] as String?,
      accent: j['accent'] as String?,
      large: j['size'] == 'lg');
}

class Warning {
  Warning({required this.level, required this.title, this.detail, this.pre = false});
  final String level, title;
  final String? detail;
  final bool pre;
  factory Warning.fromJson(Json j) => Warning(
      level: j['level'] as String,
      title: j['title'] as String,
      detail: j['detail'] as String?,
      pre: j['pre'] == true || j['kind'] == 'pre');
}

class ActivitySummary {
  ActivitySummary({required this.sport, required this.rating, required this.window, required this.reason});
  final String sport, window, reason;
  final int rating;
  factory ActivitySummary.fromJson(Json j) => ActivitySummary(
      sport: j['sport'] as String,
      rating: (j['rating'] as num).toInt(),
      window: j['window'] as String,
      reason: j['reason'] as String);
}

class DayTabData {
  DayTabData({required this.weekday, required this.date, required this.rating, required this.outlook});
  final String weekday, date;
  final int rating;
  final bool outlook;
  factory DayTabData.fromJson(Json j) => DayTabData(
      weekday: j['weekday'] as String,
      date: '${j['date']}',
      rating: (j['rating'] as num).toInt(),
      outlook: j['outlook'] == true);
}

/// A chart or visual block: component name + props (same props as the design-system .d.ts).
class Block {
  Block(this.type, this.props);
  final String type;
  final Json props;
  factory Block.fromJson(Json j) => Block(j['type'] as String, (j['props'] as Json?) ?? {});
}

class LabeledBlocks {
  LabeledBlocks(this.label, this.blocks);
  final String? label;
  final List<Block> blocks;
  factory LabeledBlocks.fromJson(Json j) => LabeledBlocks(j['label'] as String?, _list(j['blocks'], Block.fromJson));
}

class TodayData {
  TodayData.fromJson(Json j)
      : title = j['title'] as String,
        date = j['date'] as String,
        best = j['best'] as Json,
        warnings = _list(j['warnings'], Warning.fromJson),
        current = j['current'] as Json,
        rightNow = _list(j['rightNow'], Fact.fromJson),
        next24 = j['next24'] as Json,
        sports = _list(j['sports'], ActivitySummary.fromJson),
        days = List<Json>.from(j['days'] as List),
        scale = nums(j['scale']),
        confidence = j['confidence'] as Json?,
        daylight = _list(j['daylight'], Fact.fromJson),
        sources = j['sources'] as String;
  final String title, date, sources;
  final Json best, current, next24;
  final Json? confidence;
  final List<Warning> warnings;
  final List<Fact> rightNow, daylight;
  final List<ActivitySummary> sports;
  final List<Json> days;
  final List<num> scale;
}

class ModelRow {
  ModelRow.fromJson(Json j)
      : name = j['name'] as String,
        detail = j['detail'] as String,
        value = j['value'] as num,
        weight = j['weight'] as num;
  final String name, detail;
  final num value, weight;
}

class RatingFactor {
  RatingFactor.fromJson(Json j)
      : factor = j['factor'] as String,
        observed = j['observed'] as String,
        weight = j['weight'] as num,
        score = j['score'] as num,
        accent = j['accent'] as String?;
  final String factor, observed;
  final num weight, score;
  final String? accent;
}

class Analysis {
  Analysis.fromJson(Json j)
      : summary = strs(j['summary']),
        modelTitle = (j['model'] as Json)['title'] as String,
        unit = (j['model'] as Json)['unit'] as String,
        scale = nums((j['model'] as Json)['scale']),
        blend = (j['model'] as Json)['blend'] as num,
        spread = (j['model'] as Json)['spread'] as String,
        verdict = (j['model'] as Json)['verdict'] as String,
        models = _list((j['model'] as Json)['rows'], ModelRow.fromJson),
        factors = _list(j['factors'], RatingFactor.fromJson),
        total = '${j['total']}',
        rating = (j['rating'] as num).toInt(),
        ensembleLabel = (j['ensemble'] as Json?)?['label'] as String?,
        ensembleIntro = (j['ensemble'] as Json?)?['intro'] as String?,
        ensembleChart = (j['ensemble'] as Json?)?['chart'] as Json?,
        stationTitle = (j['station'] as Json?)?['title'] as String?,
        stationTrend = (j['station'] as Json?)?['trend'] as Json?,
        stationLegend = (j['station'] as Json?)?['legend'] as String?,
        stationNote = (j['station'] as Json?)?['note'] as String?,
        stationTiles = _list((j['station'] as Json?)?['tiles'], Fact.fromJson);
  final List<String> summary;
  final String modelTitle, unit, spread, verdict, total;
  final String? ensembleLabel, ensembleIntro, stationTitle, stationLegend, stationNote;
  final List<num> scale;
  final num blend;
  final List<ModelRow> models;
  final List<RatingFactor> factors;
  final int rating;
  final Json? ensembleChart, stationTrend;
  final List<Fact> stationTiles;
}

class PlannerData {
  PlannerData.fromJson(Json j)
      : sport = j['sport'] as String,
        title = j['title'] as String,
        date = j['date'] as String,
        days = _list(j['days'], DayTabData.fromJson),
        selected = (j['selected'] as num?)?.toInt() ?? 0,
        verdict = j['verdict'] as Json,
        keyLabel = j['keyLabel'] as String,
        keyFacts = _list(j['keyFacts'], Fact.fromJson),
        chip = j['chip'] as Json?,
        takeaway = j['takeaway'] as String,
        hourChart = j['hourChart'] as Json,
        tuned = [for (final t in (j['tuned'] as List? ?? const [])) (from: t['from'] as String, effect: t['effect'] as String)],
        visuals = _list(j['visuals'], LabeledBlocks.fromJson),
        planLabel = (j['plan'] as Json?)?['label'] as String?,
        planFacts = _list((j['plan'] as Json?)?['facts'], Fact.fromJson),
        outlookLabel = (j['outlook'] as Json?)?['label'] as String?,
        outlook = j['outlook'] == null ? null : Block.fromJson((j['outlook'] as Json)['block'] as Json),
        analysis = j['analysis'] == null ? null : Analysis.fromJson(j['analysis'] as Json),
        sources = j['sources'] as String;
  final String sport, title, date, keyLabel, takeaway, sources;
  final List<DayTabData> days;
  final int selected;
  final Json verdict, hourChart;
  final Json? chip;
  final List<Fact> keyFacts, planFacts;
  final List<({String from, String effect})> tuned;
  final List<LabeledBlocks> visuals;
  final String? planLabel, outlookLabel;
  final Block? outlook;
  final Analysis? analysis;
}

class ActivitiesData {
  ActivitiesData.fromJson(Json j)
      : title = j['title'] as String,
        date = j['date'] as String,
        sports = _list(j['sports'], ActivitySummary.fromJson),
        chip = j['chip'] as Json,
        days = _list(j['days'], DayTabData.fromJson),
        heatmap = j['heatmap'] as Json,
        months = j['months'] as Json,
        sources = j['sources'] as String;
  final String title, date, sources;
  final List<ActivitySummary> sports;
  final Json chip, heatmap, months;
  final List<DayTabData> days;
}

class MapPin {
  MapPin.fromJson(Json j)
      : name = j['name'] as String,
        rating = (j['rating'] as num).toInt(),
        x = (j['x'] as num).toDouble(),
        y = (j['y'] as num).toDouble(),
        wind = j['wind'] as num,
        windFrom = j['windFrom'] as num,
        lat = (j['lat'] as num?)?.toDouble(),
        lon = (j['lon'] as num?)?.toDouble();
  final String name;
  final int rating;
  final double x, y;
  final double? lat, lon;
  final num wind, windFrom;
}

class MapData {
  MapData.fromJson(Json j)
      : title = j['title'] as String,
        date = j['date'] as String,
        layers = j['layers'] as Json,
        pins = _list(j['pins'], MapPin.fromJson),
        warnings = _list(j['warnings'], Warning.fromJson),
        sources = j['sources'] as String;
  final String title, date, sources;
  final Json layers;
  final List<MapPin> pins;
  final List<Warning> warnings;
}

class SpotSummary {
  SpotSummary.fromJson(Json j)
      : id = j['id'] as String,
        sport = j['sport'] as String,
        name = j['name'] as String,
        kind = j['kind'] as String,
        wind = j['wind'] as num,
        gust = j['gust'] as num,
        windFrom = j['windFrom'] as num,
        today = nums(j['today']),
        window = j['window'] as String,
        rating = (j['rating'] as num).toInt();
  final String id, sport, name, kind, window;
  final num wind, gust, windFrom;
  final List<num> today;
  final int rating;
}

class SpotDetail {
  SpotDetail.fromJson(Json j)
      : id = j['id'] as String,
        title = j['title'] as String,
        date = j['date'] as String,
        live = _list(j['live'], Fact.fromJson),
        sections = _list(j['sections'], LabeledBlocks.fromJson),
        sources = j['sources'] as String;
  final String id, title, date, sources;
  final List<Fact> live;
  final List<LabeledBlocks> sections;
}
