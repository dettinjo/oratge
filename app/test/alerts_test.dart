import 'package:flutter_test/flutter_test.dart';
import 'package:oratge/data/alerts.dart';
import 'package:oratge/data/profile.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> answer({int wing = 4, bool warning = true}) => {
      'alerts': [
        if (wing >= 4) {'id': 'window:wing:2026-11-12:13', 'kind': 'window', 'title': 'Wing foil: good window tomorrow', 'body': 'b', 'route': '/activities/wing'},
        if (warning) {'id': 'warning:abc', 'kind': 'warning', 'title': 'Yellow warning · Wind', 'body': 'b', 'route': '/today'},
      ],
      'ratings': {
        'wing:2026-11-12': {'rating': wing, 'window': '13–16 h', 'sport': 'wing', 'day': '2026-11-12'},
        'bike:2026-11-11': {'rating': 5, 'window': '07–10 h', 'sport': 'bike', 'day': '2026-11-11'},
      },
    };

void main() {
  final noon = DateTime(2026, 11, 11, 12);
  Future<SharedPreferences> prefs() async {
    SharedPreferences.setMockInitialValues({});
    return SharedPreferences.getInstance();
  }

  test('first run records what exists without notifying; later only new items', () async {
    final p = await prefs();
    final profile = {...defaultProfile};
    expect(pickAlerts(answer(wing: 3), profile, p, noon), isEmpty);
    final next = pickAlerts(answer(wing: 4), profile, p, noon);
    // The wing window is new and the rating went 3 → 4 (plan change); the warning was already there.
    expect(next.map((n) => n.id), containsAll(['window:wing:2026-11-12:13', 'change:wing:2026-11-12:4']));
    expect(next.where((n) => n.id.startsWith('warning')), isEmpty);
    expect(pickAlerts(answer(wing: 4), profile, p, noon), isEmpty); // nothing repeats
  });

  test('switched-off kinds stay quiet', () async {
    final p = await prefs();
    final profile = {...defaultProfile, 'alertWindow': false, 'alertChange': false};
    pickAlerts(answer(wing: 3, warning: false), profile, p, noon);
    final next = pickAlerts(answer(wing: 5), profile, p, noon);
    expect(next.map((n) => n.id), ['warning:abc']);
  });

  test('morning summary once a day after 07:00, best sport first', () async {
    final p = await prefs();
    final profile = {...defaultProfile, 'alertMorning': true};
    final m = pickAlerts(answer(), profile, p, DateTime(2026, 11, 11, 7, 5));
    expect(m.single.title, 'Today: Bike 07–10 h (5/5)');
    expect(pickAlerts(answer(), profile, p, DateTime(2026, 11, 11, 8)), isEmpty);
  });
}
