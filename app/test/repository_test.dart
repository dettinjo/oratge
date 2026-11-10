import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:oratge/data/repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late String todayJson;

  setUpAll(() async => todayJson = await rootBundle.loadString('assets/sample/today.json'));
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('second load comes from the cache without a network call', () async {
    var calls = 0;
    final repo = ApiRepository('http://x',
        client: MockClient((r) async {
          calls++;
          return http.Response(todayJson, 200, headers: {'content-type': 'application/json; charset=utf-8'});
        }),
        prefs: await SharedPreferences.getInstance());
    await repo.today();
    await repo.today();
    expect(calls, 1);
    expect(repo.status.source, DataSource.live);
  });

  test('offline: falls back to sample data fast and backs off', () async {
    var calls = 0;
    final repo = ApiRepository('http://x',
        client: MockClient((r) async {
          calls++;
          throw http.ClientException('unreachable');
        }),
        fallback: SampleRepository(),
        prefs: await SharedPreferences.getInstance());
    final sw = Stopwatch()..start();
    final t = await repo.today();
    expect(t.title, 'Today');
    await repo.activities();
    await repo.map();
    expect(calls, 1, reason: 'after one failure the backend is not retried during back-off');
    expect(repo.status.source, DataSource.sample);
    expect(sw.elapsed, lessThan(const Duration(seconds: 2)));
  });

  test('saved data is returned instantly when the backend is down', () async {
    final at = DateTime.now().subtract(const Duration(hours: 3)).toIso8601String();
    SharedPreferences.setMockInitialValues({'cache:today': jsonEncode({'at': at, 'body': jsonDecode(todayJson)})});
    final repo = ApiRepository('http://x',
        client: MockClient((r) async => throw http.ClientException('unreachable')),
        prefs: await SharedPreferences.getInstance());
    final t = await repo.today();
    expect(t.title, 'Today');
    expect(repo.status.source, DataSource.saved);
  });
}
