/// What may notify, per kind and per sport. Stored in the profile under `notify` (synced across devices).
class NotifySettings {
  NotifySettings({
    this.on = true,
    Map<String, SportNotify>? sports,
    this.warnings = 'orange',
    this.changes = false,
    this.morning = false,
    this.morningHour = 7,
    this.quiet = true,
    this.quietFrom = 22,
    this.quietTo = 7,
    this.maxPerDay = 3,
  }) : sports = sports ?? {'wing': SportNotify(on: true)};

  /// Master switch.
  bool on;

  /// Good-conditions alerts per sport.
  final Map<String, SportNotify> sports;

  /// Lowest warning level that notifies: off, yellow, orange (default: severe only), red.
  String warnings;

  /// A day's rating changes by a full point (only for sports with alerts on).
  bool changes;

  bool morning;
  int morningHour;

  /// Quiet hours: nothing is shown; items wait until the quiet time ends (if still current).
  bool quiet;
  int quietFrom, quietTo;

  /// 0 = no limit.
  int maxPerDay;

  static const levels = ['off', 'yellow', 'orange', 'red'];
  static int levelRank(String l) => levels.indexOf(l);

  SportNotify sport(String s) => sports[s] ?? SportNotify(on: false);

  bool isQuiet(DateTime t) {
    if (!quiet || quietFrom == quietTo) return false;
    final h = t.hour;
    return quietFrom > quietTo ? (h >= quietFrom || h < quietTo) : (h >= quietFrom && h < quietTo);
  }

  /// Anything at all that could notify.
  bool get any => on && (sports.values.any((s) => s.on) || warnings != 'off' || morning);

  factory NotifySettings.fromJson(Object? raw) {
    if (raw is! Map) return NotifySettings();
    final j = Map<String, dynamic>.from(raw);
    int i(String k, int d) => (j[k] as num?)?.toInt() ?? d;
    return NotifySettings(
      on: j['on'] != false,
      sports: {
        for (final e in (Map<String, dynamic>.from(
          j['sports'] as Map? ??
              const {
                'wing': {'on': true},
              },
        )).entries)
          e.key: SportNotify.fromJson(e.value),
      },
      warnings: levels.contains(j['warnings']) ? j['warnings'] as String : 'orange',
      changes: j['changes'] == true,
      morning: j['morning'] == true,
      morningHour: i('morningHour', 7),
      quiet: j['quiet'] != false,
      quietFrom: i('quietFrom', 22),
      quietTo: i('quietTo', 7),
      maxPerDay: i('maxPerDay', 3),
    );
  }

  Map<String, dynamic> toJson() => {
    'on': on,
    'sports': {for (final e in sports.entries) e.key: e.value.toJson()},
    'warnings': warnings,
    'changes': changes,
    'morning': morning,
    'morningHour': morningHour,
    'quiet': quiet,
    'quietFrom': quietFrom,
    'quietTo': quietTo,
    'maxPerDay': maxPerDay,
  };

  /// One line for the Profile list.
  String summary(String Function(String) sportName) {
    if (!on) return 'Off';
    final s = [
      for (final e in sports.entries)
        if (e.value.on) sportName(e.key),
    ];
    final parts = [
      if (s.isNotEmpty) s.join(', '),
      if (warnings != 'off')
        '${warnings == 'yellow'
            ? 'all'
            : warnings == 'orange'
            ? 'severe'
            : 'red'} warnings',
      if (changes) 'changes',
      if (morning) 'morning summary',
    ];
    return parts.isEmpty ? 'Nothing selected' : parts.join(' · ');
  }
}

class SportNotify {
  SportNotify({this.on = false, this.minRating = 4, this.daysAhead = 1});

  bool on;

  /// 4 = good and epic, 5 = epic only.
  int minRating;

  /// 0 = today only, 1 = today and tomorrow, 2 = up to the day after tomorrow.
  int daysAhead;

  factory SportNotify.fromJson(Object? raw) {
    final j = raw is Map ? Map<String, dynamic>.from(raw) : const <String, dynamic>{};
    return SportNotify(
      on: j['on'] == true,
      minRating: ((j['min'] as num?)?.toInt() ?? 4).clamp(3, 5),
      daysAhead: ((j['days'] as num?)?.toInt() ?? 1).clamp(0, 2),
    );
  }

  Map<String, dynamic> toJson() => {'on': on, 'min': minRating, 'days': daysAhead};
}
