import 'dart:math' as math;

/// The user's units (Profile → Personal and units). Values arrive in kn and °C.
class Units {
  const Units({this.wind = 'kn', this.temp = '°C'});
  factory Units.of(Map<String, dynamic> profile) =>
      Units(wind: '${profile['windUnit'] ?? 'kn'}', temp: '${profile['tempUnit'] ?? '°C'}');
  final String wind, temp;

  double windValue(num kn) => switch (wind) {
    'km/h' => kn * 1.852,
    'm/s' => kn * 0.514444,
    'Bft' => beaufort(kn).toDouble(),
    _ => kn.toDouble(),
  };

  String windUnit() => wind == 'Bft' ? 'Bft' : wind;

  /// "12 kn", "22 km/h", "6 m/s", "Bft 4".
  String windText(num? kn, {bool unit = true}) {
    if (kn == null) return '—';
    final v = windValue(kn);
    final n = wind == 'm/s' ? v.toStringAsFixed(1) : v.round().toString();
    if (!unit) return n;
    return wind == 'Bft' ? 'Bft $n' : '$n $wind';
  }

  double tempValue(num c) => temp == '°F' ? c * 9 / 5 + 32 : c.toDouble();
  String tempText(num? c, {bool unit = false}) => c == null ? '—' : '${tempValue(c).round()}${unit ? temp : '°'}';

  static int beaufort(num kn) {
    const limits = [1, 4, 7, 11, 17, 22, 28, 34, 41, 48, 56, 64];
    final i = limits.indexWhere((l) => kn < l);
    return i < 0 ? 12 : i;
  }

  /// Converts a server-formatted text ("SW 12 kn · gusts 18", "14–24 kn", "17°") to these units.
  String convert(String s) {
    if (wind != 'kn') {
      s = s.replaceAllMapped(RegExp(r'(?<![\d.])(\d+(?:\.\d+)?)(?:\s?([–-])\s?(\d+(?:\.\d+)?))?\s?kn\b'), (m) {
        final a = windText(double.parse(m[1]!), unit: false);
        final b = m[3] == null ? null : windText(double.parse(m[3]!), unit: false);
        final u = wind == 'Bft' ? 'Bft' : wind;
        return b == null ? '$a $u' : '$a${m[2]}$b $u';
      });
      // "gusts 18" right after a converted wind keeps the same unit.
      s = s.replaceAllMapped(
        RegExp(r'gusts (\d+(?:\.\d+)?)(?![\d.])(?!\s?(?:kn|km/h|m/s|Bft))'),
        (m) => 'gusts ${windText(double.parse(m[1]!), unit: false)}',
      );
    }
    if (temp == '°F') {
      s = s.replaceAllMapped(
        RegExp(r'(?<![\d.])(-?\d+(?:\.\d+)?)°(?![CF\d])'),
        (m) => '${tempValue(double.parse(m[1]!)).round()}°',
      );
    }
    return s;
  }

  /// Converts every text in a server response (numbers in charts stay in kn and °C, labelled as such).
  Object? convertJson(Object? j) {
    if (wind == 'kn' && temp == '°C') return j;
    if (j is String) return convert(j);
    if (j is List) return [for (final x in j) convertJson(x)];
    if (j is Map) return {for (final e in j.entries) e.key: convertJson(e.value)};
    return j;
  }

  static double clamp01(double v) => math.max(0, math.min(1, v));
}

/// Units in force (set by the app state when the profile loads or changes).
Units currentUnits = const Units();
