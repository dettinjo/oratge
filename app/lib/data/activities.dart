import 'dart:math' as math;

import 'package:xml/xml.dart';

/// Something the user wants checked: a sport at a place ("spot") or a GPX route.
/// Stored in the profile under `activities` (synced across devices).
class Activity {
  Activity({
    required this.id,
    required this.sport,
    required this.kind,
    required this.name,
    this.lat,
    this.lon,
    this.facing,
    this.builtin,
    this.track = const [],
    this.date,
    this.start = '09:00',
    this.speed,
    this.notify = true,
    this.minRating = 4,
    this.daysAhead = 1,
    this.onlyWhenGood = true,
  });

  final String id, sport, name;

  /// 'spot' or 'route'.
  final String kind;
  double? lat, lon;

  /// Wing/surf: which way the beach faces (degrees towards the sea).
  double? facing;

  /// Built-in spot id (castelldefels…): opens its full planner with beach forecasts and live wind.
  final String? builtin;

  /// Route: simplified track [[lat, lon, ele?], …].
  final List<List<double?>> track;

  /// Route: planned day (yyyy-mm-dd; null = today) and start time.
  String? date;
  String start;

  /// Route: average speed on the flat (km/h); null = from the profile.
  double? speed;

  bool notify;
  int minRating, daysAhead;

  /// Spots: on the home screen only when conditions reach [minRating].
  bool onlyWhenGood;

  bool get isRoute => kind == 'route';

  factory Activity.fromJson(Map<String, dynamic> j) => Activity(
        id: '${j['id']}',
        sport: '${j['sport']}',
        kind: '${j['kind'] ?? 'spot'}',
        name: '${j['name'] ?? j['sport']}',
        lat: (j['lat'] as num?)?.toDouble(),
        lon: (j['lon'] as num?)?.toDouble(),
        facing: (j['facing'] as num?)?.toDouble(),
        builtin: j['builtin'] as String?,
        track: [
          for (final p in j['track'] as List? ?? const []) [for (final v in p as List) (v as num?)?.toDouble()],
        ],
        date: j['date'] as String?,
        start: '${j['start'] ?? '09:00'}',
        speed: (j['speed'] as num?)?.toDouble(),
        notify: j['notify'] != false,
        minRating: (j['minRating'] as num?)?.toInt() ?? 4,
        daysAhead: (j['days'] as num?)?.toInt() ?? 1,
        onlyWhenGood: j['onlyWhenGood'] != false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'sport': sport,
        'kind': kind,
        'name': name,
        if (lat != null) 'lat': lat,
        if (lon != null) 'lon': lon,
        if (facing != null) 'facing': facing,
        if (builtin != null) 'builtin': builtin,
        if (track.isNotEmpty) 'track': track,
        if (date != null) 'date': date,
        'start': start,
        if (speed != null) 'speed': speed,
        'notify': notify,
        'minRating': minRating,
        'days': daysAhead,
        'onlyWhenGood': onlyWhenGood,
      };

  /// Start of a route as a local date-time (planned day, or today).
  DateTime startAt(DateTime now) {
    final d = date == null ? now : DateTime.parse(date!);
    final hm = start.split(':');
    return DateTime(d.year, d.month, d.day, int.tryParse(hm[0]) ?? 9, int.tryParse(hm.length > 1 ? hm[1] : '0') ?? 0);
  }

  double get distanceKm {
    var t = 0.0;
    for (var i = 1; i < track.length; i++) {
      t += haversineKm(track[i - 1][0]!, track[i - 1][1]!, track[i][0]!, track[i][1]!);
    }
    return t;
  }

  /// The default activity: wing foil at the built-in Castelldefels spot.
  static Activity castelldefels() => Activity(
      id: 'castelldefels', sport: 'wing', kind: 'spot', name: 'Castelldefels', lat: 41.265, lon: 1.975, facing: 170, builtin: 'castelldefels');
}

double haversineKm(double la1, double lo1, double la2, double lo2) {
  const r = 6371.0;
  final p = math.pi / 180;
  final a = math.pow(math.sin((la2 - la1) * p / 2), 2) +
      math.cos(la1 * p) * math.cos(la2 * p) * math.pow(math.sin((lo2 - lo1) * p / 2), 2);
  return 2 * r * math.asin(math.sqrt(a));
}

/// Reads a GPX file (tracks, else routes): name and points [lat, lon, ele?].
({String? name, List<List<double?>> points}) parseGpx(String xml) {
  final doc = XmlDocument.parse(xml);
  final name = doc.findAllElements('name').firstOrNull?.innerText.trim();
  var pts = doc.findAllElements('trkpt').toList();
  if (pts.isEmpty) pts = doc.findAllElements('rtept').toList();
  return (
    name: (name == null || name.isEmpty) ? null : name,
    points: [
      for (final e in pts)
        if (double.tryParse(e.getAttribute('lat') ?? '') case final la?)
          if (double.tryParse(e.getAttribute('lon') ?? '') case final lo?)
            [la, lo, double.tryParse(e.getElement('ele')?.innerText ?? '')],
    ],
  );
}

/// Keeps the shape with at most [max] points (Douglas–Peucker, tolerance raised until it fits).
List<List<double?>> simplify(List<List<double?>> pts, {int max = 400}) {
  if (pts.length <= max) return pts;
  var tol = 0.00002;
  var out = pts;
  while (out.length > max) {
    out = _dp(pts, tol);
    tol *= 1.6;
  }
  return out;
}

List<List<double?>> _dp(List<List<double?>> pts, double tol) {
  final keep = List<bool>.filled(pts.length, false)
    ..[0] = true
    ..[pts.length - 1] = true;
  final stack = <(int, int)>[(0, pts.length - 1)];
  while (stack.isNotEmpty) {
    final (a, b) = stack.removeLast();
    var maxD = 0.0, idx = -1;
    for (var i = a + 1; i < b; i++) {
      final d = _segDist(pts[i], pts[a], pts[b]);
      if (d > maxD) {
        maxD = d;
        idx = i;
      }
    }
    if (idx > 0 && maxD > tol) {
      keep[idx] = true;
      stack
        ..add((a, idx))
        ..add((idx, b));
    }
  }
  return [for (var i = 0; i < pts.length; i++) if (keep[i]) pts[i]];
}

double _segDist(List<double?> p, List<double?> a, List<double?> b) {
  final x = p[1]!, y = p[0]!, x1 = a[1]!, y1 = a[0]!, x2 = b[1]!, y2 = b[0]!;
  final dx = x2 - x1, dy = y2 - y1;
  final len = dx * dx + dy * dy;
  final t = len == 0 ? 0.0 : (((x - x1) * dx + (y - y1) * dy) / len).clamp(0.0, 1.0);
  final px = x1 + t * dx, py = y1 + t * dy;
  return math.sqrt((x - px) * (x - px) + (y - py) * (y - py));
}
