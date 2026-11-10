import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';
import 'repository.dart';

/// Field kinds used by the setup flow.
enum FieldKind { text, number, choice, multi, toggle, range }

class FieldDef {
  const FieldDef(this.key, this.label,
      {this.kind = FieldKind.text, this.unit, this.options = const [], this.hint, this.toKey, this.optional = false});
  final String key, label;
  final FieldKind kind;
  final String? unit, hint;
  final List<String> options;

  /// Second key for [FieldKind.range] (key = from, toKey = to).
  final String? toKey;
  final bool optional;
}

class FieldGroup {
  const FieldGroup(this.title, this.fields);
  final String title;
  final List<FieldDef> fields;
}

class SetupStep {
  const SetupStep(
      {required this.id, required this.kicker, required this.title, required this.intro, required this.groups, this.changes, this.sport});
  final String id, kicker, title, intro;
  final List<FieldGroup> groups;
  final String? changes;
  final String? sport;
}

/// The 10-step setup flow (design: phone-setup-1 … 10). Step 10 ("done") is built by the screen.
const setupSteps = <SetupStep>[
  SetupStep(id: 'you', kicker: 'You', title: 'Where are you and how do you measure?', intro: 'Two quick questions so readings come from your stations.', groups: [
    FieldGroup('Personal', [FieldDef('name', 'Name'), FieldDef('home', 'Home')]),
    FieldGroup('Units', [
      FieldDef('windUnit', 'Wind', kind: FieldKind.choice, options: ['kn', 'km/h', 'm/s', 'Bft']),
      FieldDef('tempUnit', 'Temperature', kind: FieldKind.choice, options: ['°C', '°F']),
    ]),
  ], changes: 'Your home sets the stations used for live readings. Every screen shows values in your units.'),
  SetupStep(id: 'body', kicker: 'Body and pace', title: 'Tell us about you', intro: 'Used for gear size, turn-back times and what to wear.', groups: [
    FieldGroup('Body', [
      FieldDef('weight', 'Weight', kind: FieldKind.number, unit: 'kg'),
      FieldDef('height', 'Height', kind: FieldKind.number, unit: 'cm'),
      FieldDef('age', 'Age', kind: FieldKind.number, unit: 'yrs'),
      FieldDef('maxHr', 'Max heart rate', kind: FieldKind.number, unit: 'bpm', optional: true),
    ]),
    FieldGroup('How you handle the weather', [
      FieldDef('fitness', 'Fitness', kind: FieldKind.choice, options: ['Easy-going', 'Regular', 'Athletic']),
      FieldDef('cold', 'You feel the cold', kind: FieldKind.choice, options: ['Less', 'Average', 'More']),
    ]),
    FieldGroup('Pace', [
      FieldDef('runPace', 'Running pace', unit: '/km'),
      FieldDef('climbPace', 'Climbing pace', kind: FieldKind.number, unit: 'm/h', hint: 'Hiking ascent'),
      FieldDef('rideSpeed', 'Riding speed', kind: FieldKind.number, unit: 'km/h', hint: 'Flat, average'),
    ]),
  ], changes: 'Wing and board advice uses your weight. Hike turn-back times use your climbing pace.'),
  SetupStep(id: 'sports', kicker: 'Sports', title: 'Which sports do you do?', intro: 'Pick all that apply.', groups: [
    FieldGroup('', [
      FieldDef('sports', 'Sports', kind: FieldKind.multi, options: ['wing', 'surf', 'bike', 'run', 'hike']),
    ]),
  ], changes: 'Only the sports you pick get ratings, planners and alerts. You can add or remove them later.'),
  SetupStep(id: 'wing', sport: 'wing', kicker: 'Wing foil', title: 'Your wing foil setup', intro: 'Gear and the conditions you enjoy.', groups: [
    FieldGroup('Your gear', [
      FieldDef('wings', 'Wings you own', kind: FieldKind.multi, options: ['3 m', '4 m', '5 m', '6 m']),
      FieldDef('boardVolume', 'Board volume', kind: FieldKind.number, unit: 'l'),
      FieldDef('frontWing', 'Front wing', kind: FieldKind.number, unit: 'cm²'),
    ]),
    FieldGroup('Your conditions', [
      FieldDef('windFrom', 'Wind range', kind: FieldKind.range, toKey: 'windTo', unit: 'kn', hint: 'Where you ride comfortably'),
      FieldDef('gustLimit', 'Gust limit', kind: FieldKind.number, unit: 'kn'),
      FieldDef('directions', 'Allowed directions', kind: FieldKind.multi, options: ['Onshore', 'Side-on', 'Side', 'Offshore'], hint: 'Offshore never rates above 1'),
    ]),
    FieldGroup('Level and wetsuit', [
      FieldDef('wingLevel', 'Level', kind: FieldKind.choice, options: ['Learning', 'Riding upwind', 'Jumping']),
      FieldDef('wetsuits', 'Wetsuits'),
    ]),
  ], changes: 'Your weight, board and level set the minimum rideable wind; wing size advice follows your gust limit.'),
  SetupStep(id: 'surf', sport: 'surf', kicker: 'Surf', title: 'Your surf setup', intro: 'Board and the waves you want.', groups: [
    FieldGroup('Your board', [FieldDef('board', 'Board'), FieldDef('surfVolume', 'Volume', kind: FieldKind.number, unit: 'l')]),
    FieldGroup('Your conditions', [
      FieldDef('waveFrom', 'Wave height', kind: FieldKind.range, toKey: 'waveTo', unit: 'm'),
      FieldDef('minPeriod', 'Minimum period', kind: FieldKind.number, unit: 's'),
    ]),
  ], changes: 'Windows end when the period drops below your minimum. Ratings peak inside your wave range.'),
  SetupStep(id: 'bike', sport: 'bike', kicker: 'Bike', title: 'Your bike setup', intro: 'Bike, kit and your limits.', groups: [
    FieldGroup('Your bike', [
      FieldDef('bikeType', 'Type', kind: FieldKind.choice, options: ['Road', 'Gravel', 'MTB', 'E-bike']),
      FieldDef('tyres', 'Tyres', kind: FieldKind.number, unit: 'mm'),
      FieldDef('bikeKg', 'Bike and kit', kind: FieldKind.number, unit: 'kg'),
      FieldDef('mudguards', 'Mudguards', kind: FieldKind.toggle, hint: 'Without them, damp roads lower the rating'),
      FieldDef('lights', 'Lights', kind: FieldKind.toggle, hint: 'Allows windows after sunset'),
    ]),
    FieldGroup('Your limits', [
      FieldDef('maxWindBike', 'Max wind', kind: FieldKind.number, unit: 'kn'),
      FieldDef('ftp', 'FTP', kind: FieldKind.number, unit: 'W', hint: 'Optional, for climb times on GPX routes', optional: true),
    ]),
  ], changes: 'Damp roads lower the rating without mudguards. Climb times use your FTP, weight and the route’s GPX.'),
  SetupStep(id: 'run', sport: 'run', kicker: 'Run', title: 'Your running setup', intro: 'How and where you run.', groups: [
    FieldGroup('Your runs', [
      FieldDef('runSurface', 'Usually on', kind: FieldKind.choice, options: ['Road', 'Trail', 'Track']),
      FieldDef('runDistance', 'Typical distance', kind: FieldKind.number, unit: 'km'),
      FieldDef('comfortFrom', 'Comfortable temperature', kind: FieldKind.range, toKey: 'comfortTo', unit: '°'),
      FieldDef('lightRainOk', 'Light rain is fine', kind: FieldKind.toggle),
    ]),
  ], changes: 'Best windows stay inside your comfortable range. What to wear uses how you feel the cold.'),
  SetupStep(id: 'hike', sport: 'hike', kicker: 'Hike', title: 'Your hiking setup', intro: 'Gear and safety limits.', groups: [
    FieldGroup('Your gear', [
      FieldDef('packKg', 'Pack weight', kind: FieldKind.number, unit: 'kg'),
      FieldDef('crampons', 'Crampons and ice axe', kind: FieldKind.toggle, hint: 'Allows routes above the snow level'),
      FieldDef('headlamp', 'Headlamp', kind: FieldKind.toggle),
    ]),
    FieldGroup('Your limits', [
      FieldDef('maxStorm', 'Max storm risk', kind: FieldKind.number, unit: '%'),
      FieldDef('maxSummitWind', 'Max summit wind', kind: FieldKind.number, unit: 'kn'),
      FieldDef('daylightMargin', 'Daylight margin', kind: FieldKind.number, unit: 'h', hint: 'Back before sunset by'),
    ]),
  ], changes: 'Turn-back time = when storm risk passes your limit. Summits rate lower when gusts pass your wind limit.'),
  SetupStep(id: 'alerts', kicker: 'Alerts', title: 'When should we tell you?', intro: 'Alerts and privacy.', groups: [
    FieldGroup('Notify me when', [
      FieldDef('alertWindow', 'A 4 or 5 window appears', kind: FieldKind.toggle, hint: 'Up to 3 days ahead'),
      FieldDef('alertWarnings', 'Official warnings hit my spots', kind: FieldKind.toggle),
      FieldDef('alertChange', 'The plan changes by a full point', kind: FieldKind.toggle),
      FieldDef('alertMorning', 'Morning summary at 07:00', kind: FieldKind.toggle),
    ]),
    FieldGroup('Privacy', [FieldDef('sync', 'Sync between my devices', kind: FieldKind.toggle, hint: 'End-to-end encrypted')]),
  ], changes:
      'Your details stay on this device. Forecast requests include your sport ranges so ratings fit you; the Oratge server uses them for that answer and doesn’t store them. Every field is optional.'),
];

/// Defaults = the sample profile from the design (Alex in Barcelona).
const Map<String, dynamic> defaultProfile = {
  'name': 'Alex', 'home': 'Barcelona', 'windUnit': 'kn', 'tempUnit': '°C',
  'weight': '78', 'height': '180', 'age': '31', 'maxHr': '188', 'fitness': 'Regular', 'cold': 'Average',
  'runPace': '5:15', 'climbPace': '400', 'rideSpeed': '24',
  'sports': ['wing', 'surf', 'bike', 'run', 'hike'],
  'wings': ['4 m', '5 m'], 'boardVolume': '95', 'frontWing': '1100', 'windFrom': '14', 'windTo': '24', 'gustLimit': '26',
  'directions': ['Onshore', 'Side-on', 'Side'], 'wingLevel': 'Riding upwind', 'wetsuits': '3/2, 4/3 + booties',
  'board': '7\'2" mid-length', 'surfVolume': '48', 'waveFrom': '0.6', 'waveTo': '1.8', 'minPeriod': '8',
  'bikeType': 'Gravel', 'tyres': '40', 'bikeKg': '11.5', 'mudguards': false, 'lights': true, 'maxWindBike': '20', 'ftp': '240',
  'runSurface': 'Road', 'runDistance': '10', 'comfortFrom': '5', 'comfortTo': '22', 'lightRainOk': true,
  'packKg': '8', 'crampons': true, 'headlamp': true, 'maxStorm': '20', 'maxSummitWind': '30', 'daylightMargin': '1',
  'alertWindow': true, 'alertWarnings': true, 'alertChange': true, 'alertMorning': false, 'sync': false,
};

/// App-wide state: theme, profile, setup progress, data source. Persisted locally.
class AppState extends ChangeNotifier {
  AppState(this._prefs, {ForecastRepository? repository}) : repository = repository ?? SampleRepository() {
    final raw = _prefs?.getString('profile');
    profile = {...defaultProfile, if (raw != null) ...(jsonDecode(raw) as Map<String, dynamic>)};
    themeMode = ThemeMode.values.firstWhere((m) => m.name == _prefs?.getString('themeMode'), orElse: () => ThemeMode.dark);
    final rawPlace = _prefs?.getString('place');
    place = rawPlace == null ? null : Place.fromJson(jsonDecode(rawPlace) as Map<String, dynamic>);
    doneSteps = {...(_prefs?.getStringList('doneSteps') ?? ['you', 'body', 'sports', 'wing', 'surf', 'bike', 'hike', 'alerts'])};
  }

  final SharedPreferences? _prefs;
  SharedPreferences? get prefs => _prefs;
  ForecastRepository repository;

  /// Live / saved / sample, plus a version bumped by background refreshes.
  final DataStatus status = DataStatus();
  late Map<String, dynamic> profile;
  late ThemeMode themeMode;
  late Set<String> doneSteps;

  /// Place shown on Today (null = home from the profile).
  Place? place;

  void setPlace(Place? p) {
    place = p;
    if (p == null) {
      _prefs?.remove('place');
    } else {
      _prefs?.setString('place', jsonEncode(p.toJson()));
    }
    notifyListeners();
  }

  static Future<AppState> load() async => AppState(await SharedPreferences.getInstance());

  void setThemeMode(ThemeMode m) {
    themeMode = m;
    _prefs?.setString('themeMode', m.name);
    notifyListeners();
  }

  void setField(String key, dynamic value) {
    profile[key] = value;
    _prefs?.setString('profile', jsonEncode(profile));
    notifyListeners();
  }

  void markDone(String stepId) {
    doneSteps.add(stepId);
    _prefs?.setStringList('doneSteps', doneSteps.toList());
    notifyListeners();
  }

  List<String> get mySports => [for (final s in (profile['sports'] as List? ?? const [])) s as String];

  String summary(String stepId) {
    final p = profile;
    switch (stepId) {
      case 'you':
        return '${p['name']} · ${p['home']} · ${p['windUnit']}, ${p['tempUnit']}';
      case 'body':
        return '${p['weight']} kg · ${p['height']} cm · ${p['runPace']} /km';
      case 'sports':
        return '${mySports.length} sports';
      case 'wing':
        return '${(p['wings'] as List).map((w) => '$w'.replaceAll(' m', '')).join(' + ')} m · ${p['boardVolume']} l · ${p['windFrom']}–${p['windTo']} kn';
      case 'surf':
        return '${p['board']} ${p['surfVolume']} l · ${p['waveFrom']}–${p['waveTo']} m';
      case 'bike':
        return '${p['bikeType']} · ${p['tyres']} mm · max ${p['maxWindBike']} kn';
      case 'run':
        return '${p['runSurface']} · ${p['runDistance']} km · ${p['comfortFrom']}–${p['comfortTo']}°';
      case 'hike':
        return '${p['packKg']} kg · storms ≤ ${p['maxStorm']} % · wind ≤ ${p['maxSummitWind']} kn';
      case 'alerts':
        final on = ['alertWindow', 'alertWarnings', 'alertChange', 'alertMorning'].where((k) => p[k] == true).length;
        return '$on of 4 on';
    }
    return '';
  }
}

/// Makes [AppState] available to the widget tree.
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child}) : super(notifier: state);
  static AppState of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
