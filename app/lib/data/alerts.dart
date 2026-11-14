import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import 'activities.dart';
import 'notify_settings.dart';
import 'profile.dart';
import 'repository.dart';

/// One notification to show.
class AlertNote {
  const AlertNote(this.id, this.title, this.body, this.route);
  final String id, title, body, route;
}

/// Decides what to notify from a /v1/alerts answer, the user's [NotifySettings] and what this device
/// already sent. Pure apart from [prefs] (dedupe state, daily count, log), so it is testable.
///
/// - Good conditions: once per sport and day; again only if the rating improves (a window moving by an
///   hour stays quiet).
/// - Warnings: at or above the chosen level; again only if it escalates or after 24 h.
/// - Quiet hours: nothing is recorded, so items still current afterwards are sent then.
/// - Daily cap: extra items are recorded as handled and dropped.
List<AlertNote> pickAlerts(Map<String, dynamic> answer, Map<String, dynamic> profile, SharedPreferences prefs, DateTime now) {
  final cfg = NotifySettings.fromJson(profile['notify']);
  final firstRun = prefs.getBool('alerts:v2') != true;
  final alerts = [for (final a in answer['alerts'] as List? ?? const []) Map<String, dynamic>.from(a as Map)];
  // Activities the user asked to be told about (good conditions come only from these).
  final acts = {
    for (final a
        in profile['activities'] is List
            ? [for (final x in profile['activities'] as List) Activity.fromJson(Map<String, dynamic>.from(x as Map))]
            : [Activity.castelldefels()])
      a.id: a,
  };
  final checks = [for (final x in answer['activities'] as List? ?? const []) Map<String, dynamic>.from(x as Map)];
  // Ratings per activity and day (plan changes and the morning summary compare these).
  final ratings = <String, dynamic>{
    for (final ch in checks)
      if (acts[ch['id']] case final a? when a.notify)
        for (final d in ch['days'] as List? ?? const [])
          'act:${a.id}:${(d as Map)['date']}': {
            'rating': d['rating'],
            'window': d['window'],
            'sport': a.sport,
            'day': d['date'],
            'name': a.name,
            'id': a.id,
            'reason': d['reason'],
            'dayLabel': d['day'],
          },
  };
  final before = Map<String, dynamic>.from(jsonDecode(prefs.getString('alerts:ratings') ?? '{}') as Map);
  final windows = Map<String, dynamic>.from(jsonDecode(prefs.getString('alerts:win') ?? '{}') as Map); // sport:day → rating
  final warned = Map<String, dynamic>.from(jsonDecode(prefs.getString('alerts:warn') ?? '{}') as Map); // title → epoch ms
  final changed = (prefs.getStringList('alerts:changes') ?? const <String>[]).toSet();
  final out = <AlertNote>[];
  final record = <void Function()>[];

  void save() {
    prefs.setString('alerts:win', jsonEncode(windows));
    prefs.setString('alerts:warn', jsonEncode(warned));
    prefs.setStringList(
      'alerts:changes',
      changed.length > 200 ? changed.toList().sublist(changed.length - 200) : changed.toList(),
    );
    prefs.setString('alerts:ratings', jsonEncode(ratings));
  }

  // Good conditions: per activity, from its own rating and look-ahead; once per activity and day,
  // again only if it improves.
  String route(Activity a) =>
      a.isRoute ? '/activities/route/${a.id}' : (a.builtin != null ? '/activities/${a.sport}' : '/activities/place/${a.id}');
  for (final ch in checks) {
    final a = acts[ch['id']];
    if (a == null || !a.notify || a.isRoute) continue;
    for (final (i, d) in [for (final x in ch['days'] as List? ?? const []) Map<String, dynamic>.from(x as Map)].indexed) {
      final rating = (d['rating'] as num?)?.toInt() ?? 0;
      if (i > a.daysAhead || rating < a.minRating || d['window'] == '—') continue;
      final key = '${a.id}:${d['date']}';
      final was = (windows[key] as num?)?.toInt();
      if (was != null && rating <= was) continue;
      out.add(
        AlertNote(
          'act:$key:$rating',
          '${_title(a.sport)} at ${a.name}: ${_word(rating)} ${'${d['day']}'.toLowerCase()} ${d['window']}',
          '${d['reason']}',
          route(a),
        ),
      );
      record.add(() => windows[key] = rating);
    }
  }
  // Planned routes: from 18:00 the day before, and again if the rain picture changes.
  for (final e in (answer['routes'] as Map? ?? const {}).entries) {
    final a = acts[e.key];
    if (a == null || !a.notify) continue;
    final r = Map<String, dynamic>.from(e.value as Map);
    final start = a.startAt(now);
    final hoursAhead = start.difference(now).inMinutes / 60;
    final eveningBefore = DateTime(start.year, start.month, start.day).subtract(const Duration(hours: 6)); // 18:00 the day before
    if (hoursAhead < -1 || now.isBefore(eveningBefore)) continue;
    final lines = [for (final l in (r['summary'] as Map)['lines'] as List) '$l'];
    final key = 'route:${a.id}:${a.date ?? _iso(now)}';
    final state = lines.first;
    if (windows[key] == state) continue;
    final when = DateTime(start.year, start.month, start.day).difference(DateTime(now.year, now.month, now.day)).inDays == 0
        ? 'today'
        : 'tomorrow';
    out.add(
      AlertNote(
        '$key:${state.hashCode}',
        '${a.name} $when ${a.start}: $state',
        lines.skip(1).take(2).join(' · ') + (r['best_start'] != null ? ' · best start ${r['best_start']}' : ''),
        route(a),
      ),
    );
    record.add(() => windows[key] = state);
  }
  // Official warnings.
  if (cfg.warnings != 'off') {
    for (final a in alerts.where((a) => a['kind'] == 'warning')) {
      if (NotifySettings.levelRank('${a['level']}') < NotifySettings.levelRank(cfg.warnings)) continue;
      final key = '${a['title']}';
      final at = (warned[key] as num?)?.toInt();
      if (at != null && now.millisecondsSinceEpoch - at < const Duration(hours: 24).inMilliseconds) continue;
      out.add(AlertNote('${a['id']}', key, '${a['body']}', '${a['route'] ?? '/today'}'));
      record.add(() => warned[key] = now.millisecondsSinceEpoch);
    }
  }
  // Plan changes (activities with notifications on).
  if (cfg.changes) {
    for (final e in ratings.entries) {
      final r = Map<String, dynamic>.from(e.value as Map);
      final was = (before[e.key] as Map?)?['rating'] as num?;
      final now_ = r['rating'] as num;
      final id = 'change:${e.key}:$was>$now_';
      if (was == null || (now_ - was).abs() < 1 || changed.contains(id)) continue;
      out.add(
        AlertNote(
          id,
          '${_title(r['sport'])} at ${r['name']} ${_day(r['day'] as String, now)} ${now_ > was ? 'improved' : 'got worse'}: $was → $now_',
          'Best window ${r['window']}',
          acts[r['id']] == null ? '/activities' : route(acts[r['id']]!),
        ),
      );
      record.add(() => changed.add(id));
    }
  }
  // Morning summary (once a day, from the chosen hour until 11:00).
  final today = _iso(now);
  if (cfg.morning && now.hour >= cfg.morningHour && now.hour < 11 && prefs.getString('alerts:morning') != today) {
    final todays = [
      for (final e in ratings.entries)
        if (e.key.endsWith(today) && (e.value as Map)['window'] != '—') Map<String, dynamic>.from(e.value as Map),
    ]..sort((a, b) => (b['rating'] as num).compareTo(a['rating'] as num));
    if (todays.isNotEmpty) {
      final best = todays.first;
      out.add(
        AlertNote(
          'morning:$today',
          'Today: ${_title(best['sport'])} at ${best['name']} ${best['window']} (${best['rating']}/5)',
          todays.skip(1).map((r) => '${r['name']} ${r['rating']}/5').join(' · '),
          '/today',
        ),
      );
      record.add(() => prefs.setString('alerts:morning', today));
    }
  }

  // First run of this version: remember what exists, send nothing.
  if (firstRun || !cfg.on) {
    for (final r in record) {
      r();
    }
    save();
    prefs.setBool('alerts:v2', true);
    return const [];
  }
  // Quiet hours: keep everything pending (the morning summary has its own hour).
  if (cfg.isQuiet(now)) {
    prefs.setString('alerts:ratings', jsonEncode({...before}));
    return const [];
  }
  // Daily cap.
  final countKey = 'alerts:count:$today';
  final sentToday = prefs.getInt(countKey) ?? 0;
  final room = cfg.maxPerDay == 0 ? out.length : (cfg.maxPerDay - sentToday).clamp(0, out.length);
  for (final r in record) {
    r();
  }
  save();
  final send = out.take(room).toList();
  prefs.setInt(countKey, sentToday + send.length);
  // Log for Profile → Notifications ("Recently sent").
  final log = [...(prefs.getStringList('alerts:log') ?? const <String>[])];
  for (final n in send) {
    log.add(jsonEncode({'t': now.toIso8601String(), 'title': n.title, 'body': n.body}));
  }
  prefs.setStringList('alerts:log', log.length > 30 ? log.sublist(log.length - 30) : log);
  return send;
}

String _word(int r) => r >= 5 ? 'epic' : (r == 4 ? 'good' : 'fair');
String _iso(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
String _title(Object? s) =>
    const {'wing': 'Wing foil', 'surf': 'Surf', 'bike': 'Bike', 'run': 'Run', 'hike': 'Hike'}['$s'] ?? '$s';
String _day(String iso, DateTime now) {
  final d = DateTime.parse(iso);
  final diff = DateTime(d.year, d.month, d.day).difference(DateTime(now.year, now.month, now.day)).inDays;
  return diff == 0
      ? 'today'
      : diff == 1
      ? 'tomorrow'
      : const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][d.weekday - 1];
}

/// Fetches /v1/alerts with the device's settings and shows what is new. Works in the background isolate.
Future<int> checkAlerts(SharedPreferences prefs, {http.Client? client, FlutterLocalNotificationsPlugin? plugin}) async {
  await prefs.reload(); // the foreground may have changed settings
  final profile = Map<String, dynamic>.from(jsonDecode(prefs.getString('profile') ?? '{}') as Map);
  final p = {...defaultProfile, ...profile};
  final cfg = NotifySettings.fromJson(p['notify']);
  final acts = p['activities'] is List
      ? [for (final x in p['activities'] as List) Activity.fromJson(Map<String, dynamic>.from(x as Map))]
      : [Activity.castelldefels()];
  if (!cfg.on || !(acts.any((a) => a.notify) || cfg.warnings != 'off' || cfg.morning)) return 0;
  final url = prefs.getString('server.url') ?? buildApi;
  final token = prefs.getString('server.token') ?? buildToken;
  if (url.isEmpty) return 0;
  final sports = [for (final s in p['sports'] as List? ?? const []) '$s'].join(',');
  final place = prefs.getString('place');
  var q = 'v=2&sports=$sports';
  if (place != null) {
    final pl = jsonDecode(place) as Map;
    q +=
        '&lat=${(pl['lat'] as num).toStringAsFixed(3)}&lon=${(pl['lon'] as num).toStringAsFixed(3)}&place=${Uri.encodeQueryComponent('${pl['name']}')}';
  }
  final c = client ?? http.Client();
  final r = await c
      .get(Uri.parse('$url/v1/alerts?$q'), headers: {if (token.isNotEmpty) 'Authorization': 'Bearer $token'})
      .timeout(const Duration(seconds: 20));
  if (r.statusCode != 200) return 0;
  final answer = jsonDecode(r.body) as Map<String, dynamic>;
  final headers = {'Content-Type': 'application/json', if (token.isNotEmpty) 'Authorization': 'Bearer $token'};
  final pq = ApiRepository.profileQuery(p);
  // Spot activities: best window per day.
  final spots = acts.where((a) => a.notify && !a.isRoute && a.lat != null).toList();
  if (spots.isNotEmpty) {
    final cr = await c
        .post(
          Uri.parse('$url/v1/activities/check?$pq'),
          headers: headers,
          body: jsonEncode({
            'days': 3,
            'activities': [
              for (final a in spots)
                {'id': a.id, 'sport': a.sport, 'lat': a.lat, 'lon': a.lon, 'name': a.name, 'facing': a.facing},
            ],
          }),
        )
        .timeout(const Duration(seconds: 30));
    if (cr.statusCode == 200) answer['activities'] = (jsonDecode(cr.body) as Map)['activities'];
  }
  // Routes planned for today or tomorrow.
  final now = DateTime.now();
  final routes = <String, dynamic>{};
  for (final a in acts.where((a) => a.notify && a.isRoute && a.track.length > 1)) {
    final at = a.startAt(now);
    final days = DateTime(at.year, at.month, at.day).difference(DateTime(now.year, now.month, now.day)).inDays;
    if (days < 0 || days > 1) continue;
    String two(int x) => x.toString().padLeft(2, '0');
    final rr = await c
        .post(
          Uri.parse('$url/v1/route?$pq'),
          headers: headers,
          body: jsonEncode({
            'sport': a.sport,
            'points': a.track,
            'start': '${at.year}-${two(at.month)}-${two(at.day)}T${two(at.hour)}:${two(at.minute)}',
            if (a.speed != null) 'speed': a.speed,
          }),
        )
        .timeout(const Duration(seconds: 30));
    if (rr.statusCode == 200) routes[a.id] = jsonDecode(rr.body);
  }
  answer['routes'] = routes;
  final notes = pickAlerts(answer, p, prefs, now);
  if (notes.isEmpty) return 0;
  final n = plugin ?? await AlertService.plugin();
  const details = NotificationDetails(
    android: AndroidNotificationDetails(
      'oratge_alerts',
      'Weather alerts',
      channelDescription: 'Good windows, official warnings and plan changes',
      importance: Importance.high,
      priority: Priority.high,
    ),
    macOS: DarwinNotificationDetails(),
  );
  for (final (i, a) in notes.indexed) {
    await n.show(
      id: (a.id.hashCode & 0x7fffffff) + i,
      title: a.title,
      body: a.body,
      notificationDetails: details,
      payload: a.route,
    );
  }
  return notes.length;
}

/// Android: hourly background check (also when the app is closed).
@pragma('vm:entry-point')
void alertsDispatcher() {
  Workmanager().executeTask((task, input) async {
    try {
      await checkAlerts(await SharedPreferences.getInstance());
    } catch (_) {}
    return true;
  });
}

/// Sets up notifications: Android checks hourly in the background; the Mac checks while Oratge is open
/// (launch, return to the foreground, every 30 minutes). Tapping a notification opens its screen.
class AlertService {
  AlertService(this.app);
  final AppState app;
  static FlutterLocalNotificationsPlugin? _plugin;
  static void Function(String route)? onOpen;
  Timer? _timer;
  AppLifecycleListener? _life;
  bool _scheduled = false;

  static bool get supported => !kIsWeb && (Platform.isAndroid || Platform.isMacOS);

  static Future<FlutterLocalNotificationsPlugin> plugin() async {
    if (_plugin != null) return _plugin!;
    final p = FlutterLocalNotificationsPlugin();
    await p.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@drawable/ic_stat_oratge'),
        macOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (r) {
        if (r.payload != null) onOpen?.call(r.payload!);
      },
    );
    return _plugin = p;
  }

  bool get _wanted {
    final cfg = NotifySettings.fromJson(app.profile['notify']);
    return cfg.on && (app.activities.any((a) => a.notify) || cfg.warnings != 'off' || cfg.morning);
  }

  Future<void> start() async {
    if (!supported) return;
    final n = await plugin();
    final launch = await n.getNotificationAppLaunchDetails();
    final route = launch?.notificationResponse?.payload;
    if (launch?.didNotificationLaunchApp == true && route != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => onOpen?.call(route));
    }
    if (!_wanted) {
      // Switched on later in Profile → Alerts: set up then.
      void listen() {
        if (_wanted) {
          app.removeListener(listen);
          start();
        }
      }

      app.addListener(listen);
      return;
    }
    if (_scheduled) return;
    _scheduled = true;
    await requestPermission();
    if (Platform.isAndroid) {
      await Workmanager().initialize(alertsDispatcher);
      await Workmanager().registerPeriodicTask(
        'oratge-alerts',
        'alerts',
        frequency: const Duration(hours: 1),
        constraints: Constraints(networkType: NetworkType.connected),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      );
    } else {
      _timer ??= Timer.periodic(const Duration(minutes: 30), (_) => check());
      _life ??= AppLifecycleListener(onResume: check);
    }
    unawaited(check());
  }

  Future<bool> requestPermission() async {
    final n = await plugin();
    if (Platform.isAndroid) {
      return await n
              .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
              ?.requestNotificationsPermission() ??
          false;
    }
    return await n.resolvePlatformSpecificImplementation<MacOSFlutterLocalNotificationsPlugin>()?.requestPermissions(
          alert: true,
          badge: false,
          sound: true,
        ) ??
        false;
  }

  /// A sample notification, to check that this device shows them.
  static Future<bool> test() async {
    if (!supported) return false;
    final n = await plugin();
    final ok = await AlertService(AppState(null)).requestPermission();
    await n.show(
      id: 2,
      title: 'Oratge notifications work',
      body: 'You’ll hear about good windows, warnings and plan changes here.',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'oratge_alerts',
          'Weather alerts',
          importance: Importance.high,
          priority: Priority.high,
        ),
        macOS: DarwinNotificationDetails(),
      ),
      payload: '/today',
    );
    return ok;
  }

  Future<void> check() async {
    final prefs = app.prefs;
    if (prefs == null) return;
    try {
      await checkAlerts(prefs);
    } catch (_) {}
  }
}
