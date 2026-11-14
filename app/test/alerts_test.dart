import 'package:flutter_test/flutter_test.dart';
import 'package:oratge/data/alerts.dart';
import 'package:oratge/data/notify_settings.dart';
import 'package:oratge/data/profile.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> window(String sport, String day, int rating, {int start = 13, int ahead = 1}) => {
      'id': 'window:$sport:$day:$start',
      'kind': 'window',
      'sport': sport,
      'day': day,
      'days_ahead': ahead,
      'rating': rating,
      'title': '$sport window',
      'body': 'b',
      'route': '/activities/$sport',
    };

Map<String, dynamic> warning(String level, String title) =>
    {'id': 'warning:$title', 'kind': 'warning', 'level': level, 'title': title, 'body': 'b', 'route': '/today'};

Map<String, dynamic> answer(List<Map<String, dynamic>> alerts, [Map<String, dynamic> ratings = const {}]) =>
    {'alerts': alerts, 'ratings': ratings};

void main() {
  final noon = DateTime(2026, 11, 14, 12);
  late SharedPreferences p;
  setUp(() async {
    SharedPreferences.setMockInitialValues({'alerts:v2': true}); // past the first-run baseline
    p = await SharedPreferences.getInstance();
  });
  Map<String, dynamic> profile([NotifySettings? n]) => {...defaultProfile, if (n != null) 'notify': n.toJson()};

  test('defaults: only wing windows and severe warnings', () {
    final out = pickAlerts(
        answer([
          window('wing', '2026-11-15', 4),
          window('bike', '2026-11-14', 5, ahead: 0),
          window('run', '2026-11-14', 5, ahead: 0),
          warning('yellow', 'Yellow warning · Rain'),
          warning('orange', 'Orange warning · Wind'),
        ]),
        profile(),
        p,
        noon);
    expect(out.map((n) => n.title), ['wing window', 'Orange warning · Wind']);
  });

  test('one notification per sport and day; again only when it gets better', () {
    final pr = profile();
    expect(pickAlerts(answer([window('wing', '2026-11-15', 4, start: 12)]), pr, p, noon), hasLength(1));
    expect(pickAlerts(answer([window('wing', '2026-11-15', 4, start: 13)]), pr, p, noon), isEmpty); // moved an hour
    expect(pickAlerts(answer([window('wing', '2026-11-15', 5, start: 13)]), pr, p, noon), hasLength(1)); // now epic
  });

  test('per-sport rating and look-ahead', () {
    final n = NotifySettings()..sports['wing'] = SportNotify(on: true, minRating: 5, daysAhead: 0);
    final out = pickAlerts(
        answer([window('wing', '2026-11-15', 5, ahead: 1), window('wing', '2026-11-14', 4, ahead: 0)]), profile(n), p, noon);
    expect(out, isEmpty); // tomorrow is beyond "today only"; today is only good, not epic
  });

  test('warnings repeat only when they escalate or after 24 h', () {
    final n = NotifySettings()..warnings = 'yellow';
    expect(pickAlerts(answer([warning('yellow', 'Yellow warning · Wind')]), profile(n), p, noon), hasLength(1));
    expect(pickAlerts(answer([warning('yellow', 'Yellow warning · Wind')]), profile(n), p, noon.add(const Duration(hours: 3))), isEmpty);
    expect(pickAlerts(answer([warning('orange', 'Orange warning · Wind')]), profile(n), p, noon.add(const Duration(hours: 3))), hasLength(1));
    expect(pickAlerts(answer([warning('yellow', 'Yellow warning · Wind')]), profile(n), p, noon.add(const Duration(hours: 25))), hasLength(1));
  });

  test('quiet hours hold items until later; the daily cap drops the rest', () {
    final night = DateTime(2026, 11, 14, 23);
    expect(pickAlerts(answer([window('wing', '2026-11-15', 4)]), profile(), p, night), isEmpty);
    expect(pickAlerts(answer([window('wing', '2026-11-15', 4)]), profile(), p, DateTime(2026, 11, 15, 8)), hasLength(1));

    final n = NotifySettings(maxPerDay: 1)..warnings = 'yellow';
    expect(pickAlerts(answer([warning('yellow', 'A'), warning('yellow', 'B')]), profile(n), p, DateTime(2026, 11, 16, 12)), hasLength(1));
    expect(pickAlerts(answer([warning('yellow', 'A'), warning('yellow', 'B')]), profile(n), p, DateTime(2026, 11, 16, 13)), isEmpty);
  });

  test('first run records without sending; master switch off sends nothing', () async {
    SharedPreferences.setMockInitialValues({});
    final fresh = await SharedPreferences.getInstance();
    expect(pickAlerts(answer([window('wing', '2026-11-15', 4)]), profile(), fresh, noon), isEmpty);
    expect(pickAlerts(answer([window('wing', '2026-11-15', 4)]), profile(), fresh, noon), isEmpty); // already known
    expect(pickAlerts(answer([window('wing', '2026-11-16', 5)]), profile(NotifySettings(on: false)), fresh, noon), isEmpty);
  });

  test('plan changes only for sports with alerts on', () {
    final n = NotifySettings(changes: true);
    Map<String, dynamic> r(int wing, int bike) => {
          'wing:2026-11-15': {'rating': wing, 'window': '13–16 h', 'sport': 'wing', 'day': '2026-11-15'},
          'bike:2026-11-15': {'rating': bike, 'window': '09–12 h', 'sport': 'bike', 'day': '2026-11-15'},
        };
    pickAlerts(answer([], r(2, 2)), profile(n), p, noon);
    final out = pickAlerts(answer([], r(3, 4)), profile(n), p, noon);
    expect(out.map((x) => x.title), ['Wing foil tomorrow improved: 2 → 3']);
  });
}
