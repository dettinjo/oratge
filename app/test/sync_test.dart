import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:oratge/data/models.dart';
import 'package:oratge/data/profile.dart';
import 'package:oratge/data/sync.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// In-memory stand-in for the backend's /v1/sync: newest timestamp per key wins.
class FakeServer {
  final Map<String, Map<String, dynamic>> fields = {};
  int requests = 0;
  late final client = MockClient((req) async {
    requests++;
    if (req.headers['Authorization'] != 'Bearer t') return http.Response('{"detail":"no"}', 401);
    final incoming = (jsonDecode(req.body) as Map<String, dynamic>)['fields'] as Map<String, dynamic>;
    for (final e in incoming.entries) {
      final f = e.value as Map<String, dynamic>;
      final old = fields[e.key];
      if (old == null || (f['t'] as num) > (old['t'] as num)) fields[e.key] = f;
    }
    return http.Response(jsonEncode({'fields': fields}), 200);
  });
}

Future<AppState> device() async {
  SharedPreferences.setMockInitialValues({});
  return AppState(await SharedPreferences.getInstance());
}

SyncService syncOf(AppState s, FakeServer srv, {String token = 't'}) => SyncService(s, 'http://x', token, client: srv.client);

void main() {
  test('a second device takes the first device’s settings instead of its own defaults', () async {
    final srv = FakeServer();
    final a = await device();
    a.setField('windFrom', '12');
    a.toggleFavorite(const Place(name: 'Sitges', region: 'Garraf', lat: 41.235, lon: 1.812));
    await syncOf(a, srv).syncNow();

    final b = await device(); // fresh install: every value is a default, never edited here
    await syncOf(b, srv).syncNow();
    expect(b.profile['windFrom'], '12');
    expect(b.profile['name'], a.profile['name']);
    expect(b.favorites.single.name, 'Sitges');
  });

  test('edits to different settings on two devices both survive; the same setting ends with the later edit', () async {
    final srv = FakeServer();
    final a = await device(), b = await device();
    final sa = syncOf(a, srv), sb = syncOf(b, srv);
    await sa.syncNow();
    await sb.syncNow();

    a.setField('gustLimit', '30');
    a.setField('name', 'Joel');
    await Future<void>.delayed(const Duration(milliseconds: 5));
    b.setField('windTo', '28');
    b.setField('name', 'Joel D.'); // later edit of the same field
    await sa.syncNow();
    await sb.syncNow();
    await sa.syncNow();

    for (final d in [a, b]) {
      expect(d.profile['gustLimit'], '30');
      expect(d.profile['windTo'], '28');
      expect(d.profile['name'], 'Joel D.');
    }
  });

  test('the sync switch and the selected place stay per device', () async {
    final srv = FakeServer();
    final a = await device();
    a.setPlace(const Place(name: 'Sitges', lat: 41.235, lon: 1.812));
    a.profile['sync'] = true;
    await syncOf(a, srv).syncNow();
    expect(srv.fields.keys, isNot(contains('p.sync')));
    expect(srv.fields.keys.where((k) => k.contains('place')), isEmpty);
  });

  test('a wrong token is reported, not thrown', () async {
    final srv = FakeServer();
    final s = syncOf(await device(), srv, token: 'nope');
    await s.syncNow();
    expect(s.error, 'The server refused the token.');
    expect(s.lastSync, isNull);
  });

  test('requests during a running sync fold into one follow-up', () async {
    final srv = FakeServer();
    final s = syncOf(await device(), srv);
    await Future.wait([s.syncNow(), s.syncNow(), s.syncNow()]);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(srv.requests, 2);
  });
}
