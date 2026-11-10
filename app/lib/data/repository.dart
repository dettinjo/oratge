import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import 'models.dart';

const sports = ['wing', 'surf', 'bike', 'run', 'hike'];

/// Everything the UI needs. Implementations: sample data (bundled) and the Oratge backend.
abstract class ForecastRepository {
  Future<TodayData> today();
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
      jsonDecode(await _bundle.loadString('assets/sample/$name.json', cache: false)) as Json;

  @override
  Future<TodayData> today() async => TodayData.fromJson(await _load('today'));
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

/// The Oratge backend (FastAPI). Same JSON shapes as the sample data, under /v1.
class ApiRepository implements ForecastRepository {
  ApiRepository(this.baseUrl, {this.token, http.Client? client, this.fallback, this.profile})
      : _client = client ?? http.Client();
  final String baseUrl;
  final String? token;
  final http.Client _client;

  /// Returns the user's ranges (sent with each request, never stored server-side).
  final Map<String, dynamic> Function()? profile;

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

  /// Used when the backend is unreachable, so the app still opens offline.
  final ForecastRepository? fallback;

  Future<Json> _get(String path) async {
    final res = await _client
        .get(Uri.parse('$baseUrl/v1/${_query(path)}'), headers: {if (token != null) 'Authorization': 'Bearer $token'})
        .timeout(const Duration(seconds: 12));
    if (res.statusCode != 200) throw http.ClientException('HTTP ${res.statusCode} for $path');
    return jsonDecode(utf8.decode(res.bodyBytes)) as Json;
  }

  Future<T> _try<T>(Future<T> Function() remote, Future<T> Function(ForecastRepository) local) async {
    try {
      return await remote();
    } catch (_) {
      if (fallback == null) rethrow;
      return local(fallback!);
    }
  }

  @override
  Future<TodayData> today() => _try(() async => TodayData.fromJson(await _get('today')), (f) => f.today());
  @override
  Future<ActivitiesData> activities() =>
      _try(() async => ActivitiesData.fromJson(await _get('activities')), (f) => f.activities());
  @override
  Future<PlannerData> planner(String sport, {int day = 0}) => _try(
      () async => PlannerData.fromJson(await _get('planner/$sport?day=$day')), (f) => f.planner(sport, day: day));
  @override
  Future<MapData> map() => _try(() async => MapData.fromJson(await _get('map')), (f) => f.map());
  @override
  Future<List<SpotSummary>> spots() => _try(
      () async => [for (final s in (await _get('spots'))['spots'] as List) SpotSummary.fromJson(s as Json)],
      (f) => f.spots());
  @override
  Future<SpotDetail> spot(String id) =>
      _try(() async => SpotDetail.fromJson(await _get('spots/$id')), (f) => f.spot(id));
}
