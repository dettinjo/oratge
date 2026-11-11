import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;

/// What the sync service needs from the app state (kept as an interface so it can be tested alone).
abstract class Syncable {
  /// Every synced key with its value and last-change time (epoch ms; 0 = never changed here).
  Map<String, ({Object? v, int t})> syncFields();

  /// Applies values that are newer on the server. Returns how many keys changed.
  int applyRemote(Map<String, ({Object? v, int t})> fields);
}

/// Keeps the owner's settings in step across devices through the Oratge backend (`/v1/sync`).
///
/// One round trip does both directions: the device sends every synced key with its last-change time,
/// the server keeps the newest per key and answers with the merged set, and the device takes whatever
/// is newer than its own copy. Edits on different devices to different settings never overwrite each
/// other; the same setting changed on two devices ends with the later change.
class SyncService extends ChangeNotifier {
  SyncService(this.target, this.baseUrl, this.token, {http.Client? client}) : _client = client ?? http.Client();

  final Syncable target;
  final String baseUrl;
  final String? token;
  final http.Client _client;

  DateTime? lastSync;
  String? error;
  bool busy = false;
  int keys = 0;

  Timer? _debounce, _periodic;
  AppLifecycleListener? _life;
  Future<void>? _running;
  bool _again = false;

  static const timeout = Duration(seconds: 8);

  /// Syncs now, then every few minutes and whenever the app comes back to the foreground.
  void start() {
    _periodic ??= Timer.periodic(const Duration(minutes: 3), (_) => syncNow());
    _life ??= AppLifecycleListener(onResume: syncNow);
    syncNow();
  }

  void stop() {
    _debounce?.cancel();
    _periodic?.cancel();
    _periodic = null;
    _life?.dispose();
    _life = null;
  }

  /// A local edit: sync shortly after, so a burst of edits (typing, sliders) is one request.
  void changed() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 1500), syncNow);
  }

  /// Runs one sync; a request made while one is running is folded into a single follow-up.
  Future<void> syncNow() {
    if (_running != null) {
      _again = true;
      return _running!;
    }
    return _running = _run().whenComplete(() {
      _running = null;
      if (_again) {
        _again = false;
        syncNow();
      }
    });
  }

  Future<void> _run() async {
    busy = true;
    notifyListeners();
    try {
      final body = jsonEncode({
        'fields': {
          for (final e in target.syncFields().entries)
            // Never-edited values go up as "oldest possible", so any real edit elsewhere beats them.
            e.key: {'v': e.value.v, 't': e.value.t == 0 ? 1 : e.value.t},
        },
      });
      final r = await _client
          .put(Uri.parse('$baseUrl/v1/sync'),
              headers: {'Content-Type': 'application/json', if (token != null) 'Authorization': 'Bearer $token'}, body: body)
          .timeout(timeout);
      if (r.statusCode != 200) {
        throw switch (r.statusCode) {
          401 => 'The server refused the token.',
          403 => 'Sync isn’t enabled on this server.',
          _ => 'Server answered ${r.statusCode}.',
        };
      }
      final fields = (jsonDecode(r.body) as Map<String, dynamic>)['fields'] as Map<String, dynamic>;
      keys = fields.length;
      target.applyRemote({
        for (final e in fields.entries)
          e.key: (v: (e.value as Map)['v'], t: ((e.value as Map)['t'] as num).toInt()),
      });
      lastSync = DateTime.now();
      error = null;
    } on TimeoutException {
      error = 'The server didn’t answer. Is Tailscale on?';
    } catch (e) {
      error = e is String ? e : 'Couldn’t reach the server.';
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}

/// Checks a server address and token before saving them (health, then an authorised call).
Future<String?> testServer(String url, String? token, {http.Client? client}) async {
  final c = client ?? http.Client();
  try {
    final h = await c.get(Uri.parse('$url/health')).timeout(const Duration(seconds: 6));
    if (h.statusCode != 200) return 'No Oratge server at that address (${h.statusCode}).';
    final r = await c
        .get(Uri.parse('$url/v1/spots'), headers: {if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token'})
        .timeout(const Duration(seconds: 6));
    if (r.statusCode == 401) return 'The server refused the token.';
    if (r.statusCode != 200) return 'Server answered ${r.statusCode}.';
    return null;
  } on TimeoutException {
    return 'No answer. Check the address and that Tailscale is on.';
  } catch (_) {
    return 'Couldn’t reach that address.';
  }
}
