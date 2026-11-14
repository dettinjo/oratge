import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'activities.dart';
import 'models.dart';
import 'repository.dart';
import 'sync.dart';
import 'units.dart';

/// Field kinds used by the setup flow.
enum FieldKind { text, number, choice, multi, toggle, range }

class FieldDef {
  const FieldDef(
    this.key,
    this.label, {
    this.kind = FieldKind.text,
    this.unit,
    this.options = const [],
    this.hint,
    this.toKey,
    this.optional = false,
  });
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
  const SetupStep({
    required this.id,
    required this.kicker,
    required this.title,
    required this.intro,
    required this.groups,
    this.changes,
    this.sport,
  });
  final String id, kicker, title, intro;
  final List<FieldGroup> groups;
  final String? changes;
  final String? sport;
}

/// The 10-step setup flow (design: phone-setup-1 … 10). Step 10 ("done") is built by the screen.
const setupSteps = <SetupStep>[
  SetupStep(
    id: 'you',
    kicker: 'You',
    title: 'Where are you and how do you measure?',
    intro: 'Two quick questions so readings come from your stations.',
    groups: [
      FieldGroup('Personal', [FieldDef('name', 'Name'), FieldDef('home', 'Home')]),
      FieldGroup('Units', [
        FieldDef('windUnit', 'Wind', kind: FieldKind.choice, options: ['kn', 'km/h', 'm/s', 'Bft']),
        FieldDef('tempUnit', 'Temperature', kind: FieldKind.choice, options: ['°C', '°F']),
      ]),
    ],
    changes: 'Your home sets the stations used for live readings. Every screen shows values in your units.',
  ),
  SetupStep(
    id: 'body',
    kicker: 'Body and pace',
    title: 'Tell us about you',
    intro: 'Used for gear size, turn-back times and what to wear.',
    groups: [
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
    ],
    changes: 'Wing and board advice uses your weight. Hike turn-back times use your climbing pace.',
  ),
  SetupStep(
    id: 'sports',
    kicker: 'Sports',
    title: 'Which sports do you do?',
    intro: 'Pick all that apply.',
    groups: [
      FieldGroup('', [
        FieldDef('sports', 'Sports', kind: FieldKind.multi, options: ['wing', 'surf', 'bike', 'run', 'hike']),
      ]),
    ],
    changes: 'Only the sports you pick get ratings, planners and alerts. You can add or remove them later.',
  ),
  SetupStep(
    id: 'wing',
    sport: 'wing',
    kicker: 'Wing foil',
    title: 'Your wing foil setup',
    intro: 'Gear and the conditions you enjoy.',
    groups: [
      FieldGroup('Your gear', [
        FieldDef('wings', 'Wings you own', kind: FieldKind.multi, options: ['3 m', '4 m', '5 m', '6 m']),
        FieldDef('boardVolume', 'Board volume', kind: FieldKind.number, unit: 'l'),
        FieldDef('frontWing', 'Front wing', kind: FieldKind.number, unit: 'cm²'),
      ]),
      FieldGroup('Your conditions', [
        FieldDef(
          'windFrom',
          'Wind range',
          kind: FieldKind.range,
          toKey: 'windTo',
          unit: 'kn',
          hint: 'Where you ride comfortably',
        ),
        FieldDef('gustLimit', 'Gust limit', kind: FieldKind.number, unit: 'kn'),
        FieldDef(
          'directions',
          'Allowed directions',
          kind: FieldKind.multi,
          options: ['Onshore', 'Side-on', 'Side', 'Offshore'],
          hint: 'Offshore never rates above 1',
        ),
      ]),
      FieldGroup('Level and wetsuit', [
        FieldDef('wingLevel', 'Level', kind: FieldKind.choice, options: ['Learning', 'Riding upwind', 'Jumping']),
        FieldDef('wetsuits', 'Wetsuits'),
      ]),
    ],
    changes: 'Your weight, board volume, front wing, wings and level set the wind your gear works in (Wing foil → Wing gear) and lower the rating when your quiver can’t cover the hour.',
  ),
  SetupStep(
    id: 'surf',
    sport: 'surf',
    kicker: 'Surf',
    title: 'Your surf setup',
    intro: 'Board and the waves you want.',
    groups: [
      FieldGroup('Your board', [FieldDef('board', 'Board'), FieldDef('surfVolume', 'Volume', kind: FieldKind.number, unit: 'l')]),
      FieldGroup('Your conditions', [
        FieldDef('waveFrom', 'Wave height', kind: FieldKind.range, toKey: 'waveTo', unit: 'm'),
        FieldDef('minPeriod', 'Minimum period', kind: FieldKind.number, unit: 's'),
      ]),
    ],
    changes: 'Windows end when the period drops below your minimum. Ratings peak inside your wave range.',
  ),
  SetupStep(
    id: 'bike',
    sport: 'bike',
    kicker: 'Bike',
    title: 'Your bike setup',
    intro: 'Bike, kit and your limits.',
    groups: [
      FieldGroup('Your bike', [
        FieldDef('bikeType', 'Type', kind: FieldKind.choice, options: ['Road', 'Gravel', 'MTB', 'E-bike']),
        FieldDef('tyres', 'Tyres', kind: FieldKind.number, unit: 'mm'),
        FieldDef('bikeKg', 'Bike and kit', kind: FieldKind.number, unit: 'kg'),
        FieldDef('mudguards', 'Mudguards', kind: FieldKind.toggle, hint: 'Without them, damp roads lower the rating'),
        FieldDef('lights', 'Lights', kind: FieldKind.toggle, hint: 'Allows windows after sunset'),
      ]),
      FieldGroup('Your limits', [
        FieldDef('maxWindBike', 'Max wind', kind: FieldKind.number, unit: 'kn'),
        FieldDef(
          'ftp',
          'FTP',
          kind: FieldKind.number,
          unit: 'W',
          hint: 'Optional, for climb times on GPX routes',
          optional: true,
        ),
      ]),
    ],
    changes: 'Damp roads lower the rating without mudguards. Climb times use your FTP, weight and the route’s GPX.',
  ),
  SetupStep(
    id: 'run',
    sport: 'run',
    kicker: 'Run',
    title: 'Your running setup',
    intro: 'How and where you run.',
    groups: [
      FieldGroup('Your runs', [
        FieldDef('runSurface', 'Usually on', kind: FieldKind.choice, options: ['Road', 'Trail', 'Track']),
        FieldDef('runDistance', 'Typical distance', kind: FieldKind.number, unit: 'km'),
        FieldDef('comfortFrom', 'Comfortable temperature', kind: FieldKind.range, toKey: 'comfortTo', unit: '°'),
        FieldDef('lightRainOk', 'Light rain is fine', kind: FieldKind.toggle),
      ]),
    ],
    changes: 'Best windows stay inside your comfortable range. What to wear uses how you feel the cold.',
  ),
  SetupStep(
    id: 'hike',
    sport: 'hike',
    kicker: 'Hike',
    title: 'Your hiking setup',
    intro: 'Gear and safety limits.',
    groups: [
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
    ],
    changes: 'Turn-back time = when storm risk passes your limit. Summits rate lower when gusts pass your wind limit.',
  ),
  SetupStep(
    id: 'alerts',
    kicker: 'Privacy',
    title: 'Sync and privacy',
    intro: 'Notifications are set in Profile → Notifications: by default only severe warnings and good wing foil conditions.',
    groups: [
      FieldGroup('Privacy', [
        FieldDef('sync', 'Sync between my devices', kind: FieldKind.toggle, hint: 'Through your own Oratge server'),
      ]),
    ],
    changes: 'Forecast requests include your sport ranges so ratings fit you. With sync off your details stay on this device; with sync on, your profile, setup and favourite places are kept on your Oratge server so every device you sign in on shares them. Every field is optional.',
  ),
];

/// Defaults = the sample profile from the design (Alex in Barcelona).
const Map<String, dynamic> defaultProfile = {
  'name': 'Alex',
  'home': 'Barcelona',
  'windUnit': 'kn',
  'tempUnit': '°C',
  'weight': '78',
  'height': '180',
  'age': '31',
  'maxHr': '188',
  'fitness': 'Regular',
  'cold': 'Average',
  'runPace': '5:15',
  'climbPace': '400',
  'rideSpeed': '24',
  'sports': ['wing', 'surf', 'bike', 'run', 'hike'],
  'wings': ['4 m', '5 m'],
  'boardVolume': '95',
  'frontWing': '1100',
  'windFrom': '14',
  'windTo': '24',
  'gustLimit': '26',
  'directions': ['Onshore', 'Side-on', 'Side'],
  'wingLevel': 'Riding upwind',
  'wetsuits': '3/2, 4/3 + booties',
  'board': '7\'2" mid-length',
  'surfVolume': '48',
  'waveFrom': '0.6',
  'waveTo': '1.8',
  'minPeriod': '8',
  'bikeType': 'Gravel',
  'tyres': '40',
  'bikeKg': '11.5',
  'mudguards': false,
  'lights': true,
  'maxWindBike': '20',
  'ftp': '240',
  'runSurface': 'Road',
  'runDistance': '10',
  'comfortFrom': '5',
  'comfortTo': '22',
  'lightRainOk': true,
  'packKg': '8',
  'crampons': true,
  'headlamp': true,
  'maxStorm': '20',
  'maxSummitWind': '30',
  'daylightMargin': '1',
  'alertWindow': true,
  'alertWarnings': true,
  'alertChange': true,
  'alertMorning': false,
  'sync': false,
};

/// Backend address and token from the build (--dart-define); the app's server settings override them.
const buildApi = String.fromEnvironment('ORATGE_API');
const buildToken = String.fromEnvironment('ORATGE_TOKEN');

/// App-wide state: theme, profile, setup progress, favourite places, data source. Persisted locally,
/// and with sync on, shared across devices through the backend (see [SyncService]).
class AppState extends ChangeNotifier implements Syncable {
  AppState(this._prefs, {ForecastRepository? repository}) : repository = repository ?? SampleRepository() {
    final raw = _prefs?.getString('profile');
    profile = {...defaultProfile, if (raw != null) ...(jsonDecode(raw) as Map<String, dynamic>)};
    currentUnits = Units.of(profile);
    themeMode = ThemeMode.values.firstWhere((m) => m.name == _prefs?.getString('themeMode'), orElse: () => ThemeMode.dark);
    final rawPlace = _prefs?.getString('place');
    place = rawPlace == null ? null : Place.fromJson(jsonDecode(rawPlace) as Map<String, dynamic>);
    doneSteps = {
      ...(_prefs?.getStringList('doneSteps') ?? ['you', 'body', 'sports', 'wing', 'surf', 'bike', 'hike', 'alerts']),
    };
    favorites = [
      for (final f in (jsonDecode(_prefs?.getString('favorites') ?? '[]') as List)) Place.fromJson(f as Map<String, dynamic>),
    ];
    stamps = {
      for (final e in (jsonDecode(_prefs?.getString('sync:stamps') ?? '{}') as Map<String, dynamic>).entries)
        e.key: (e.value as num).toInt(),
    };
  }

  final SharedPreferences? _prefs;
  SharedPreferences? get prefs => _prefs;
  ForecastRepository repository;

  /// Live / saved / sample, plus a version bumped by background refreshes.
  final DataStatus status = DataStatus();
  late Map<String, dynamic> profile;
  late ThemeMode themeMode;
  late Set<String> doneSteps;
  late List<Place> favorites;

  /// Last local change per synced key (epoch ms). Kept even with sync off, so turning it on later
  /// knows which side is newer.
  late Map<String, int> stamps;

  /// Place shown on Today (null = home from the profile). Per device, not synced.
  Place? place;

  // ── Server connection ──
  String get serverUrl => _prefs?.getString('server.url') ?? buildApi;
  String get serverToken => _prefs?.getString('server.token') ?? buildToken;
  bool get hasServer => serverUrl.isNotEmpty;
  SyncService? sync;
  bool get syncOn => profile['sync'] == true;

  /// (Re)connects to the backend: forecasts from [serverUrl], sync when it is on. Without a server the
  /// bundled sample data is shown.
  void connect() {
    sync?.dispose();
    sync = null;
    if (!hasServer) {
      repository = SampleRepository();
    } else {
      final api = ApiRepository(
        serverUrl,
        token: serverToken.isEmpty ? null : serverToken,
        fallback: SampleRepository(),
        profile: () => profile,
        prefs: _prefs,
        status: status,
      );
      repository = api;
      api.prefetch(); // warm every screen in parallel; navigation then reads from the cache
      if (syncOn) {
        sync = SyncService(this, serverUrl, serverToken.isEmpty ? null : serverToken)..start();
      }
    }
    status.bump(); // screens reload from the new source
    notifyListeners();
  }

  /// Saves new server settings (empty url = back to the build's default) and reconnects.
  void setServer(String url, String token) {
    url = url.trim().replaceAll(RegExp(r'/+$'), '');
    if (url.isEmpty) {
      _prefs?.remove('server.url');
      _prefs?.remove('server.token');
    } else {
      _prefs?.setString('server.url', url);
      _prefs?.setString('server.token', token.trim());
    }
    connect();
  }

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

  void _touch(String key) {
    stamps[key] = DateTime.now().millisecondsSinceEpoch;
    _prefs?.setString('sync:stamps', jsonEncode(stamps));
    sync?.changed();
  }

  Units get units => currentUnits;

  void setField(String key, dynamic value) {
    profile[key] = value;
    if (key == 'windUnit' || key == 'tempUnit') {
      currentUnits = Units.of(profile);
      status.bump(); // screens reload and convert in the new units
    }
    _prefs?.setString('profile', jsonEncode(profile));
    if (key == 'sync') {
      // The switch itself is per device; turning it on starts syncing right away.
      notifyListeners();
      connect();
      return;
    }
    _touch('p.$key');
    notifyListeners();
  }

  void markDone(String stepId) {
    if (!doneSteps.add(stepId)) return;
    _prefs?.setStringList('doneSteps', doneSteps.toList());
    _touch('doneSteps');
    notifyListeners();
  }

  bool isFavorite(Place p) => favorites.any((f) => _same(f, p));
  static bool _same(Place a, Place b) => (a.lat - b.lat).abs() < 0.005 && (a.lon - b.lon).abs() < 0.005;

  void toggleFavorite(Place p) {
    if (isFavorite(p)) {
      favorites.removeWhere((f) => _same(f, p));
    } else {
      favorites.add(Place(name: p.name, region: p.region, lat: p.lat, lon: p.lon));
    }
    _prefs?.setString('favorites', jsonEncode([for (final f in favorites) f.toJson()]));
    _touch('favorites');
    notifyListeners();
  }

  // ── Syncable ──
  @override
  Map<String, ({Object? v, int t})> syncFields() => {
    for (final e in profile.entries)
      if (e.key != 'sync') 'p.${e.key}': (v: e.value, t: stamps['p.${e.key}'] ?? 0),
    'doneSteps': (v: (doneSteps.toList()..sort()), t: stamps['doneSteps'] ?? 0),
    'favorites': (v: [for (final f in favorites) f.toJson()], t: stamps['favorites'] ?? 0),
  };

  @override
  int applyRemote(Map<String, ({Object? v, int t})> fields) {
    var n = 0;
    for (final MapEntry(:key, :value) in fields.entries) {
      if (value.t <= (stamps[key] ?? 0)) continue;
      if (key.startsWith('p.')) {
        final k = key.substring(2);
        if (k == 'sync') continue;
        if (value.v == null) {
          profile[k] = defaultProfile[k];
        } else {
          profile[k] = value.v;
        }
      } else if (key == 'doneSteps' && value.v is List) {
        doneSteps = {for (final s in value.v as List) '$s'};
      } else if (key == 'favorites' && value.v is List) {
        favorites = [for (final f in value.v as List) Place.fromJson(Map<String, dynamic>.from(f as Map))];
      } else {
        continue; // unknown key from a newer app version: leave it on the server
      }
      stamps[key] = value.t;
      n++;
    }
    if (n > 0) {
      currentUnits = Units.of(profile);
      _prefs?.setString('profile', jsonEncode(profile));
      _prefs?.setStringList('doneSteps', doneSteps.toList());
      _prefs?.setString('favorites', jsonEncode([for (final f in favorites) f.toJson()]));
      _prefs?.setString('sync:stamps', jsonEncode(stamps));
      status.bump(); // ranges may have changed: ratings reload
      notifyListeners();
    }
    return n;
  }

  // ── Activities to check (spots and GPX routes) ──
  List<Activity> get activities {
    final raw = profile['activities'];
    if (raw is! List) return [Activity.castelldefels()]; // default: wing foil at Castelldefels
    return [for (final a in raw) Activity.fromJson(Map<String, dynamic>.from(a as Map))];
  }

  void saveActivities(List<Activity> list) => setField('activities', [for (final a in list) a.toJson()]);

  void upsertActivity(Activity a) {
    final list = activities;
    final i = list.indexWhere((x) => x.id == a.id);
    i < 0 ? list.add(a) : list[i] = a;
    saveActivities(list);
  }

  void removeActivity(String id) => saveActivities(activities..removeWhere((a) => a.id == id));

  Activity? activity(String id) => activities.where((a) => a.id == id).firstOrNull;

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
        return p['sync'] == true ? 'Sync on' : 'Sync off';
    }
    return '';
  }
}

/// Makes [AppState] available to the widget tree.
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child}) : super(notifier: state);
  static AppState of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
