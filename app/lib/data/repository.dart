import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';
import 'units.dart';

const sports = ['wing', 'surf', 'bike', 'run', 'hike'];

/// Everything the UI needs. Implementations: sample data (bundled) and the Oratge backend.
abstract class ForecastRepository {
  /// Today for [place] (null = home).
  Future<TodayData> today([Place? place]);
  Future<List<Place>> places(String query);
  Future<Place> reverse(double lat, double lon);
  Future<GridData> grid();

  /// 48-hour hourly forecast on the map grid (empty offline).
  Future<MapForecast> mapForecast();

  /// Seven days hour by hour for one place (metric detail views).
  Future<HourlyData> hourly([Place? place]);
  Future<ActivitiesData> activities();
  Future<PlannerData> planner(String sport, {int day = 0});
  Future<MapData> map();
  Future<List<SpotSummary>> spots();
  Future<SpotDetail> spot(String id);
}

/// Bundled sample data generated from the design handoff (tool/gen_sample.py).
class SampleRepository implements ForecastRepository {
  SampleRepository({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;
  final AssetBundle _bundle;

  Future<Json> _load(String name) async =>
      currentUnits.convertJson(jsonDecode(await _bundle.loadString('assets/sample/$name.json', cache: false))) as Json;

  /// A few Catalan places so search works offline too.
  static const _towns = [
    Place(name: 'Barcelona', region: 'Barcelona', lat: 41.389, lon: 2.159),
    Place(name: 'Castelldefels', region: 'Barcelona', lat: 41.281, lon: 1.977),
    Place(name: 'El Masnou', region: 'Barcelona', lat: 41.48, lon: 2.319),
    Place(name: 'Sitges', region: 'Barcelona', lat: 41.235, lon: 1.812),
    Place(name: 'Girona', region: 'Girona', lat: 41.979, lon: 2.821),
    Place(name: 'Tarragona', region: 'Tarragona', lat: 41.119, lon: 1.245),
    Place(name: 'Lleida', region: 'Lleida', lat: 41.617, lon: 0.62),
    Place(name: 'Berga', region: 'Barcelona', lat: 42.104, lon: 1.846),
    Place(name: 'Roses', region: 'Girona', lat: 42.262, lon: 3.176),
    Place(name: 'Puigcerdà', region: 'Girona', lat: 42.432, lon: 1.928),
  ];

  @override
  Future<TodayData> today([Place? place]) async => TodayData.fromJson(await _load('today'));
  @override
  Future<List<Place>> places(String query) async =>
      _towns.where((t) => t.name.toLowerCase().contains(query.toLowerCase())).toList();
  @override
  Future<Place> reverse(double lat, double lon) async {
    final near = [..._towns]..sort((a, b) =>
        ((a.lat - lat) * (a.lat - lat) + (a.lon - lon) * (a.lon - lon))
            .compareTo((b.lat - lat) * (b.lat - lat) + (b.lon - lon) * (b.lon - lon)));
    return Place(name: near.first.name, region: near.first.region, lat: lat, lon: lon, current: true);
  }

  @override
  Future<GridData> grid() async => GridData.fromJson({'time': '', 'points': [], 'source': 'offline'});
  @override
  Future<MapForecast> mapForecast() async => MapForecast.fromJson(const {});
  @override
  Future<HourlyData> hourly([Place? place]) async => HourlyData.fromJson(await _load('hourly'));
  @override
  Future<ActivitiesData> activities() async => ActivitiesData.fromJson(await _load('activities'));
  @override
  Future<PlannerData> planner(String sport, {int day = 0}) async => PlannerData.fromJson(await _load('planner-$sport'));
  @override
  Future<MapData> map() async => MapData.fromJson(await _load('map'));
  @override
  Future<List<SpotSummary>> spots() async =>
      [for (final s in (await _load('spots'))['spots'] as List) SpotSummary.fromJson(s as Json)];
  @override
  Future<SpotDetail> spot(String id) async => SpotDetail.fromJson(await _load('spot-castelldefels'));
}

/// Where the data on screen came from (shown as a small banner when not live).
enum DataSource { live, saved, sample }

class DataStatus extends ChangeNotifier {
  DataSource source = DataSource.live;
  DateTime? savedAt;

  /// Bumped when a background refresh brings newer data, so screens reload from the cache.
  int version = 0;

  void set(DataSource s, [DateTime? at]) {
    if (s == source && at == savedAt) return;
    source = s;
    savedAt = at;
    notifyListeners();
  }

  void bump() {
    version++;
    notifyListeners();
  }
}

/// The Oratge backend (FastAPI). Same JSON shapes as the sample data, under /v1.
///
/// Stale-while-revalidate: every response is cached on the device (memory + shared preferences).
/// A screen gets cached data instantly; data older than [fresh] is refreshed in the background.
/// After a network failure the backend isn't tried again for [backoff], so screens never wait
/// on repeated timeouts; with no cache at all the bundled sample data is shown.
class ApiRepository implements ForecastRepository {
  ApiRepository(this.baseUrl,
      {this.token, http.Client? client, this.fallback, this.profile, this.prefs, DataStatus? status})
      : _client = client ?? http.Client(),
        status = status ?? DataStatus();
  final String baseUrl;
  final String? token;
  final http.Client _client;
  final SharedPreferences? prefs;
  final DataStatus status;

  /// Returns the user's ranges (sent with each request, never stored server-side).
  final Map<String, dynamic> Function()? profile;

  /// Used when the backend is unreachable and nothing is cached yet.
  final ForecastRepository? fallback;

  static const fresh = Duration(minutes: 10);
  static const backoff = Duration(seconds: 45);
  static const timeout = Duration(seconds: 6);

  final Map<String, (DateTime, Json)> _mem = {};
  final Map<String, Future<Json>> _inflight = {};
  DateTime? _offlineUntil;

  static const _keys = ['windFrom', 'windTo', 'gustLimit', 'waveFrom', 'waveTo', 'minPeriod', 'maxWindBike',
      'comfortFrom', 'comfortTo', 'maxStorm', 'maxSummitWind', 'weight', 'climbPace', 'daylightMargin', 'runDistance',
      'mudguards', 'lights', 'lightRainOk', 'crampons', 'cold', 'directions'];

  String _query(String path) {
    final p = profile?.call() ?? const {};
    final q = <String, String>{
      for (final k in _keys)
        if (p[k] != null) k: p[k] is List ? (p[k] as List).join(',') : '${p[k]}',
    };
    if (q.isEmpty) return path;
    return '$path${path.contains('?') ? '&' : '?'}${Uri(queryParameters: q).query}';
  }

  (DateTime, Json)? _cached(String key) {
    final m = _mem[key];
    if (m != null) return m;
    final raw = prefs?.getString('cache:$key');
    if (raw == null) return null;
    try {
      final j = jsonDecode(raw) as Json;
      final entry = (DateTime.parse(j['at'] as String), j['body'] as Json);
      _mem[key] = entry;
      return entry;
    } catch (_) {
      return null;
    }
  }

  void _store(String key, Json body) {
    final now = DateTime.now();
    _mem[key] = (now, body);
    prefs?.setString('cache:$key', jsonEncode({'at': now.toIso8601String(), 'body': body}));
  }

  /// One network fetch per path at a time; fails fast while in back-off.
  Future<Json> _fetch(String path) {
    final key = _query(path);
    return _inflight[key] ??= () async {
      try {
        if (_offlineUntil != null && DateTime.now().isBefore(_offlineUntil!)) {
          throw http.ClientException('offline (backing off)');
        }
        final res = await _client
            .get(Uri.parse('$baseUrl/v1/$key'), headers: {if (token != null) 'Authorization': 'Bearer $token'})
            .timeout(timeout);
        if (res.statusCode != 200) throw http.ClientException('HTTP ${res.statusCode} for $path');
        final body = jsonDecode(utf8.decode(res.bodyBytes)) as Json;
        _offlineUntil = null;
        _store(key, body);
        status.set(DataSource.live);
        return body;
      } catch (e) {
        if (e is! http.ClientException || !e.message.startsWith('offline')) {
          _offlineUntil = DateTime.now().add(backoff);
        }
        rethrow;
      } finally {
        _inflight.remove(key);
      }
    }();
  }

  Future<T> _load<T>(String path, T Function(Json) parse, Future<T> Function(ForecastRepository) local) async {
    final key = _query(path);
    final hit = _cached(key);
    if (hit != null) {
      final (at, body) = hit;
      if (DateTime.now().difference(at) > fresh) {
        status.set(DataSource.saved, at);
        // Refresh quietly; screens reload from the cache when it lands.
        _fetch(path).then((_) => status.bump(), onError: (_) {});
      }
      return parse(currentUnits.convertJson(body) as Json);
    }
    try {
      return parse(currentUnits.convertJson(await _fetch(path)) as Json);
    } catch (_) {
      if (fallback == null) rethrow;
      status.set(DataSource.sample);
      return local(fallback!);
    }
  }

  /// Loads every screen in parallel (call at startup) so navigation is instant.
  Future<void> prefetch() async {
    await Future.wait([
      today(), activities(), map(), spots(), spot('castelldefels'),
      for (final s in sports) planner(s),
    ].map((f) => f.then((_) {}, onError: (_) {})));
  }

  @override
  Future<TodayData> today([Place? place]) => _load(
      place == null
          ? 'today'
          : 'today?lat=${place.lat.toStringAsFixed(3)}&lon=${place.lon.toStringAsFixed(3)}&place=${Uri.encodeQueryComponent(place.name)}',
      TodayData.fromJson,
      (f) => f.today(place));

  /// Live search (not cached on disk): falls back to the offline town list.
  @override
  Future<List<Place>> places(String query) async {
    try {
      final j = await _fetch('places?q=${Uri.encodeQueryComponent(query)}');
      return [for (final p in j['places'] as List) Place.fromJson(p as Json)];
    } catch (_) {
      return fallback?.places(query) ?? const [];
    }
  }

  @override
  Future<Place> reverse(double lat, double lon) async {
    try {
      final p = Place.fromJson(await _fetch('reverse?lat=${lat.toStringAsFixed(3)}&lon=${lon.toStringAsFixed(3)}'));
      return Place(name: p.name, lat: lat, lon: lon, current: true);
    } catch (_) {
      return fallback?.reverse(lat, lon) ?? Place(name: 'Current location', lat: lat, lon: lon, current: true);
    }
  }

  @override
  Future<GridData> grid() => _load('map/grid', GridData.fromJson, (f) => f.grid());
  @override
  Future<MapForecast> mapForecast() => _load('map/forecast', MapForecast.fromJson, (f) => f.mapForecast());
  @override
  Future<HourlyData> hourly([Place? place]) => _load(
      place == null
          ? 'hourly'
          : 'hourly?lat=${place.lat.toStringAsFixed(3)}&lon=${place.lon.toStringAsFixed(3)}&place=${Uri.encodeQueryComponent(place.name)}',
      HourlyData.fromJson,
      (f) => f.hourly(place));
  @override
  Future<ActivitiesData> activities() => _load('activities', ActivitiesData.fromJson, (f) => f.activities());
  @override
  Future<PlannerData> planner(String sport, {int day = 0}) =>
      _load('planner/$sport?day=$day', PlannerData.fromJson, (f) => f.planner(sport, day: day));
  @override
  Future<MapData> map() => _load('map', MapData.fromJson, (f) => f.map());
  @override
  Future<List<SpotSummary>> spots() => _load(
      'spots', (j) => [for (final s in j['spots'] as List) SpotSummary.fromJson(s as Json)], (f) => f.spots());
  @override
  Future<SpotDetail> spot(String id) => _load('spots/$id', SpotDetail.fromJson, (f) => f.spot(id));
}
