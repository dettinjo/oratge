import 'dart:convert';

import 'package:http/http.dart' as http;

/// One radar image: when it was measured and its tile URL template for flutter_map.
class RadarFrame {
  const RadarFrame(this.time, this.url);
  final DateTime time;
  final String url;
}

/// Rain radar from RainViewer's free public API (personal/educational use, attribution with a link,
/// tiles up to zoom 7). It has the past 2 hours in 10-minute steps and no forecast frames.
/// Fetched straight from the app: it needs no key and costs nothing against the Meteocat quota.
class RainRadar {
  RainRadar({http.Client? client}) : _http = client ?? http.Client();
  final http.Client _http;

  static const index = 'https://api.rainviewer.com/public/weather-maps.json';
  static const maxNativeZoom = 7;

  /// Colour scheme 2 ("Universal Blue"), 512 px tiles (a quarter of the requests of 256 px), smoothed,
  /// snow in the same colours as rain. Tiles are rate-limited to about 500 a minute per IP.
  static String tileUrl(String host, String path) => '$host$path/512/{z}/{x}/{y}/2/1_0.png';

  List<RadarFrame> _frames = const [];
  DateTime? _fetched;

  /// The frames, oldest first. Reuses the last answer for 5 minutes (new frames come every 10).
  Future<List<RadarFrame>> frames({bool force = false}) async {
    final f = _fetched;
    if (!force && f != null && DateTime.now().difference(f) < const Duration(minutes: 5) && _frames.isNotEmpty) {
      return _frames;
    }
    final r = await _http.get(Uri.parse(index)).timeout(const Duration(seconds: 8));
    if (r.statusCode != 200) throw Exception('radar ${r.statusCode}');
    _frames = parse(jsonDecode(r.body) as Map<String, dynamic>);
    _fetched = DateTime.now();
    return _frames;
  }

  static List<RadarFrame> parse(Map<String, dynamic> j) {
    final host = j['host'] as String? ?? 'https://tilecache.rainviewer.com';
    final past = ((j['radar'] as Map<String, dynamic>?)?['past'] as List?) ?? const [];
    return [
      for (final p in past.cast<Map<String, dynamic>>())
        RadarFrame(DateTime.fromMillisecondsSinceEpoch((p['time'] as num).toInt() * 1000), tileUrl(host, p['path'] as String)),
    ]..sort((a, b) => a.time.compareTo(b.time));
  }
}
