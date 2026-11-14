import 'dart:math' as math;

/// Wing foil gear calculator — the same rules of thumb as backend/oratge/wingcalc.py (see its
/// docstring); app/test/wing_calc_test.dart checks the same reference cases as the backend tests.
class WingRange {
  const WingRange(this.size, this.low, this.high);

  /// m²
  final double size;

  /// Minimum wind (kn) to get up and stay on foil; gust limit (kn) still controllable.
  final double low, high;
}

class WingChoice {
  const WingChoice(this.state, this.size, this.text);

  /// ok, gap (between two wings), under, over.
  final String state;
  final double size;
  final String text;
}

class WingGear {
  WingGear._(this.wings, this.level, this.weight, this.board, this.frontWing, this.parts);

  final List<WingRange> wings;
  final String level;
  final double weight, board, frontWing;

  /// How the minimum for a 5 m² wing is built up (kn): base (weight), board, foil, level.
  final Map<String, double> parts;

  static const _low = {'Learning': 2.0, 'Riding upwind': 0.0, 'Jumping': -1.0};
  static const _high = {'Learning': -7.0, 'Riding upwind': 0.0, 'Jumping': 3.0};

  static double _num(Object? x, double d) => double.tryParse('$x'.replaceAll(',', '.').trim().split(RegExp(r'\s+')).first) ?? d;

  static List<double> quiver(Object? raw) {
    final items = raw is List ? raw : (raw is String ? raw.split(',') : const ['4 m', '5 m']);
    final s = {for (final w in items) _num(w, 0)}.where((x) => x > 0).toList()..sort();
    return s.isEmpty ? [4.0, 5.0] : s;
  }

  factory WingGear.of(Map<String, dynamic> p) {
    final kg = _num(p['weight'], 78), vol = _num(p['boardVolume'], 95), fw = _num(p['frontWing'], 1100);
    final level = _low.containsKey(p['wingLevel']) ? p['wingLevel'] as String : 'Riding upwind';
    final ratio = kg == 0 ? 1.0 : vol / kg;
    final board = ratio >= 1.2 ? -1.5 : (ratio >= 1.0 ? 0.0 : (ratio >= 0.8 ? 1.5 : 3.0));
    final foil = fw >= 1800 ? -2.5 : (fw >= 1400 ? -1.5 : (fw >= 1000 ? 0.0 : (fw >= 800 ? 2.0 : 4.0)));
    final base = 14 + (kg - 75) * 0.09;
    final core = base + board + foil + _low[level]!;
    final top4 = 31 + (kg - 75) * 0.12 + _high[level]!;
    double r1(double x) => (x * 10).roundToDouble() / 10;
    return WingGear._(
      [for (final a in quiver(p['wings'])) WingRange(a, r1(core * math.sqrt(5 / a)), r1(top4 * math.sqrt(4 / a)))],
      level,
      kg,
      vol,
      fw,
      {'base': r1(base), 'board': board, 'foil': foil, 'level': _low[level]!},
    );
  }

  double get minWind => wings.map((w) => w.low).reduce(math.min);
  double get maxGust => wings.map((w) => w.high).reduce(math.max);

  static String label(double a) => '${a == a.roundToDouble() ? a.toInt() : a} m';

  /// Biggest wing that gets you up in [wind] and stays controllable in [gust] (kn).
  WingChoice pick(double wind, double gust) {
    final fits = wings.where((w) => w.low <= wind && w.high >= gust).toList();
    if (fits.isNotEmpty) {
      final w = fits.reduce((a, b) => a.size >= b.size ? a : b);
      final margin = math.min(wind - w.low, w.high - gust);
      return WingChoice('ok', w.size, label(w.size) + (margin < 2 ? ' (at its limit)' : ''));
    }
    if (wind < minWind) {
      final big = wings.reduce((a, b) => a.size >= b.size ? a : b);
      return WingChoice('under', big.size, 'Underpowered: your ${label(big.size)} needs about ${big.low.round()} kn');
    }
    final small = wings.reduce((a, b) => a.size <= b.size ? a : b);
    if (gust > small.high) {
      return WingChoice(
        'over',
        small.size,
        'Overpowered: gusts ${gust.round()} kn, your ${label(small.size)} holds about ${small.high.round()} kn',
      );
    }
    final w = wings.where((x) => x.high >= gust).reduce((a, b) => a.size >= b.size ? a : b);
    return WingChoice('gap', w.size, '${label(w.size)}, light for the lulls (gap in your quiver)');
  }
}
