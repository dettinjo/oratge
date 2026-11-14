import 'package:flutter_test/flutter_test.dart';
import 'package:oratge/data/activities.dart';
import 'package:oratge/data/alerts.dart';
import 'package:oratge/data/notify_settings.dart';
import 'package:oratge/data/profile.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One /v1/activities/check entry: ratings for today, tomorrow and the day after.
Map<String, dynamic> check(String id, List<int> ratings, {String window = '13–16 h'}) => {
      'id': id,
      'days': [
        for (final (i, r) in ratings.indexed)
          {'day': ['Today', 'Tomorrow', 'Mon'][i], 'date': '2026-11-${14 + i}', 'rating': r, 'window': r > 0 ? window : '—', 'reason': 'side W 15 kn'},
      ],
    };

Map<String, dynamic> warning(String level, String title) =>
    {'id': 'warning:$title', 'kind': 'warning', 'level': level, 'title': title, 'body': 'b', 'route': '/today'};

Map<String, dynamic> answer({List<Map<String, dynamic>> checks = const [], List<Map<String, dynamic>> alerts = const [], Map<String, dynamic> routes = const {}}) =>
    {'alerts': alerts, 'activities': checks, 'routes': routes};

void main() {
  final noon = DateTime(2026, 11, 14, 12);
  late SharedPreferences p;
  setUp(() async {
    SharedPreferences.setMockInitialValues({'alerts:v2': true}); // past the first-run baseline
    p = await SharedPreferences.getInstance();
  });
  Map<String, dynamic> profile({NotifySettings? n, List<Activity>? acts}) => {
        ...defaultProfile,
        if (n != null) 'notify': n.toJson(),
        if (acts != null) 'activities': [for (final a in acts) a.toJson()],
      };
  final sitges = Activity(id: 'sitges', sport: 'wing', kind: 'spot', name: 'Sitges', lat: 41.24, lon: 1.81, facing: 170);

  test('defaults: the wing spot (Castelldefels) and severe warnings only', () {
    final out = pickAlerts(
        answer(checks: [check('castelldefels', [0, 4, 0])], alerts: [warning('yellow', 'Yellow · Rain'), warning('orange', 'Orange · Wind')]),
        profile(),
        p,
        noon);
    expect(out.map((n) => n.title), ['Wing foil at Castelldefels: good tomorrow 13–16 h', 'Orange · Wind']);
  });

  test('once per activity and day; again only when it gets better', () {
    final pr = profile(acts: [sitges]);
    expect(pickAlerts(answer(checks: [check('sitges', [0, 4, 0])]), pr, p, noon), hasLength(1));
    expect(pickAlerts(answer(checks: [check('sitges', [0, 4, 0], window: '14–17 h')]), pr, p, noon), isEmpty); // moved
    expect(pickAlerts(answer(checks: [check('sitges', [0, 5, 0])]), pr, p, noon), hasLength(1)); // now epic
  });

  test('each activity has its own rating, look-ahead and switch', () {
    final strict = Activity.fromJson({...sitges.toJson(), 'minRating': 5, 'days': 0});
    final off = Activity.fromJson({...sitges.toJson(), 'id': 'off', 'notify': false});
    final out = pickAlerts(answer(checks: [check('sitges', [4, 5, 0]), check('off', [5, 5, 5])]), profile(acts: [strict, off]), p, noon);
    expect(out, isEmpty); // today is only good, tomorrow is beyond "today only"; the other is switched off
  });

  test('routes: from the evening before, again when the rain picture changes', () {
    final ride = Activity(id: 'ride', sport: 'bike', kind: 'route', name: 'Saturday ride', date: '2026-11-15', start: '09:00',
        track: const [[41.3, 2.0, null], [41.4, 2.0, null]]);
    Map<String, dynamic> r(String first) => {
          'ride': {'summary': {'lines': [first, 'Feels 12–15°']}, 'best_start': '08:00'},
        };
    final pr = profile(acts: [ride]);
    expect(pickAlerts(answer(routes: r('Dry the whole way')), pr, p, DateTime(2026, 11, 14, 12)), isEmpty); // too early
    final first = pickAlerts(answer(routes: r('Dry the whole way')), pr, p, DateTime(2026, 11, 14, 19));
    expect(first.single.title, 'Saturday ride tomorrow 09:00: Dry the whole way');
    expect(pickAlerts(answer(routes: r('Dry the whole way')), pr, p, DateTime(2026, 11, 15, 7)), isEmpty);
    expect(pickAlerts(answer(routes: r('Rain km 20–35 (10:10–11:00)')), pr, p, DateTime(2026, 11, 15, 7)), hasLength(1));
  });

  test('warnings repeat only when they escalate or after 24 h', () {
    final n = NotifySettings()..warnings = 'yellow';
    expect(pickAlerts(answer(alerts: [warning('yellow', 'Yellow · Wind')]), profile(n: n), p, noon), hasLength(1));
    expect(pickAlerts(answer(alerts: [warning('yellow', 'Yellow · Wind')]), profile(n: n), p, noon.add(const Duration(hours: 3))), isEmpty);
    expect(pickAlerts(answer(alerts: [warning('orange', 'Orange · Wind')]), profile(n: n), p, noon.add(const Duration(hours: 3))), hasLength(1));
  });

  test('quiet hours hold items until later; the daily cap drops the rest', () {
    final pr = profile(acts: [sitges]);
    expect(pickAlerts(answer(checks: [check('sitges', [0, 4, 0])]), pr, p, DateTime(2026, 11, 14, 23)), isEmpty);
    expect(pickAlerts(answer(checks: [check('sitges', [0, 4, 0])]), pr, p, DateTime(2026, 11, 15, 8)), hasLength(1));
    final n = NotifySettings(maxPerDay: 1)..warnings = 'yellow';
    expect(pickAlerts(answer(alerts: [warning('yellow', 'A'), warning('yellow', 'B')]), profile(n: n), p, DateTime(2026, 11, 16, 12)), hasLength(1));
  });

  test('plan changes for activities with notifications on', () {
    final pr = profile(n: NotifySettings(changes: true), acts: [sitges]);
    pickAlerts(answer(checks: [check('sitges', [2, 2, 0])]), pr, p, noon);
    final out = pickAlerts(answer(checks: [check('sitges', [2, 3, 0])]), pr, p, noon);
    expect(out.map((x) => x.title), ['Wing foil at Sitges tomorrow improved: 2 → 3']);
  });
}
