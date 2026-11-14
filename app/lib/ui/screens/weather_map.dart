import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart' show LatLng;

import '../../data/models.dart';
import '../../data/profile.dart';
import '../../data/units.dart';
import '../../theme/og_helpers.dart';
import '../../theme/oratge_tokens.dart';
import '../charts/chart_utils.dart';
import '../components/basics.dart';
import '../components/og_map.dart';
import '../components/rows_cards.dart';
import '../components/sheets.dart';
import '../map/field.dart';
import '../map/layers.dart';
import '../motion.dart';
import 'common.dart';

bool get _inTest => !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');
const _wd = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// A place shown on the map: a built-in spot or one of the user's activities.
class _Pin {
  _Pin(this.name, this.lat, this.lon, {this.sport, this.rating, this.route});
  final String name;
  final double lat, lon;
  final String? sport, route;
  final int? rating;
}

/// The weather map: the whole Map tab (or full screen from elsewhere). The forecast field always fills
/// the view (the camera stays inside the forecast grid); a timeline steps through 48 hours; a details
/// panel shows the tapped point or place with all values and its 48-hour curve.
class WeatherMapScreen extends StatefulWidget {
  const WeatherMapScreen({super.key, this.embedded = false});

  /// In the Map tab (no back button, navigation bar visible).
  final bool embedded;
  @override
  State<WeatherMapScreen> createState() => _WeatherMapScreenState();
}

class _WeatherMapScreenState extends State<WeatherMapScreen> {
  final _map = MapController();
  FieldLayer _layer = FieldLayer.wind;
  int _t = 0;
  bool _playing = false;
  Timer? _play;
  LatLng? _me, _probe;
  _Pin? _pin;
  bool _expanded = false; // phone panel
  MapForecast? _fc;
  Future<List<(double, double)>>? _strikes;
  List<_Pin> _pins = const [];
  List<Warning> _warnings = const [];
  String? _error;
  final Map<(FieldLayer, int, Brightness), ui.Image> _images = {};
  bool _rendering = false;
  int _seenVersion = -1;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final v = AppScope.of(context).status.version;
    if (v != _seenVersion) {
      _seenVersion = v;
      _load();
    }
  }

  Future<void> _load() async {
    final app = AppScope.of(context);
    try {
      final r = await Future.wait([app.repository.mapForecast(), app.repository.map()]);
      if (!mounted) return;
      final data = r[1] as MapData;
      final pins = <_Pin>[
        for (final p in data.pins.where((p) => p.lat != null))
          _Pin(
            p.name.split(' · ').first,
            p.lat!,
            p.lon!,
            sport: p.sport,
            rating: p.rating,
            route: p.sport == null ? null : '/activities/${p.sport}',
          ),
        for (final a in app.activities.where((a) => !a.isRoute && a.lat != null && a.builtin == null))
          _Pin(a.name, a.lat!, a.lon!, sport: a.sport, route: '/activities/place/${a.id}'),
      ];
      setState(() {
        for (final img in _images.values) {
          img.dispose();
        }
        _images.clear();
        _fc = r[0] as MapForecast;
        _pins = pins;
        _warnings = data.warnings;
        _t = _t.clamp(0, math.max(0, (_fc?.times.length ?? 1) - 1));
      });
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  @override
  void dispose() {
    _play?.cancel();
    for (final img in _images.values) {
      img.dispose();
    }
    super.dispose();
  }

  FieldSampler? get _sampler => (_fc == null || _fc!.isEmpty) ? null : FieldSampler(_fc!, _t.clamp(0, _fc!.times.length - 1));

  void _ensureImage(OratgeColors c, Brightness b) {
    final s = _sampler;
    if (s == null || _layer == FieldLayer.rating || _rendering) return;
    final key = (_layer, _t, b);
    if (_images.containsKey(key)) return;
    _rendering = true;
    renderField(s, _layer, FieldColors(c), width: 300, height: 240).then((img) {
      _rendering = false;
      if (!mounted) return img.dispose();
      setState(() => _images[key] = img);
    });
  }

  void _togglePlay() {
    final n = _fc?.times.length ?? 0;
    if (n == 0) return;
    setState(() => _playing = !_playing);
    _play?.cancel();
    if (_playing) {
      _play = Timer.periodic(const Duration(milliseconds: 650), (_) {
        if (mounted) setState(() => _t = (_t + 1) % n);
      });
    }
  }

  void _setT(int v) {
    if (v != _t) HapticFeedback.selectionClick();
    setState(() => _t = v);
  }

  Future<void> _locate() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) return;
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.low, timeLimit: Duration(seconds: 12)),
      );
      setState(() {
        _me = LatLng(p.latitude, p.longitude);
        _probe = _me;
        _pin = null;
        _expanded = true;
      });
      _map.move(_me!, 9.5);
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Couldn’t get your location.')));
    }
  }

  /// The grid with half a cell trimmed: the camera may not show anything outside it.
  LatLngBounds? get _limits {
    final s = _sampler;
    if (s == null) return null;
    return LatLngBounds(LatLng(s.se.latitude + 0.15, s.nw.longitude + 0.15), LatLng(s.nw.latitude - 0.15, s.se.longitude - 0.15));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.og;
    final b = Theme.of(context).brightness;
    _ensureImage(c, b);
    final s = _sampler;
    final img =
        _images[(_layer, _t, b)] ??
        _images.entries.where((e) => e.key.$1 == _layer && e.key.$3 == b).map((e) => e.value).firstOrNull;
    final motionOn = !reduceMotion(context);
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final n = _fc?.times.length ?? 0;
    void step(int d) {
      if (n > 0) _setT((_t + d).clamp(0, n - 1));
    }

    final selected = _pin != null ? LatLng(_pin!.lat, _pin!.lon) : _probe;
    final map = _inTest
        ? ColoredBox(color: c.surface)
        : FlutterMap(
            key: ValueKey(_limits == null),
            mapController: _map,
            options: MapOptions(
              initialCameraFit: CameraFit.bounds(
                bounds: LatLngBounds(const LatLng(40.5, 0.2), const LatLng(42.85, 3.35)),
                padding: EdgeInsets.fromLTRB(12, 120, 12, wide ? 90 : 170),
              ),
              cameraConstraint: _limits == null
                  ? const CameraConstraint.unconstrained()
                  : CameraConstraint.contain(bounds: _limits!),
              minZoom: 6.2,
              maxZoom: 13,
              backgroundColor: c.bg,
              interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
              onTap: (_, ll) {
                HapticFeedback.selectionClick();
                setState(() {
                  _probe = ll;
                  _pin = null;
                  _expanded = true; // show the point's chart and days straight away
                });
              },
            ),
            children: [
              oratgeTiles(context),
              if (s != null && img != null && _layer != FieldLayer.rating) FieldImageLayer(image: img, nw: s.nw, se: s.se),
              if (s != null && _layer == FieldLayer.wind && motionOn) WindParticleLayer(sampler: s),
              if (s != null && (_layer == FieldLayer.rain || _layer == FieldLayer.chance)) RainLayer(sampler: s),
              if (_layer == FieldLayer.thunder)
                FutureBuilder<List<(double, double)>>(
                  future: _strikes ??= AppScope.of(context).repository.lightning(),
                  builder: (context, snap) => MarkerLayer(
                    markers: [
                      for (final (la, lo) in (snap.data ?? const <(double, double)>[]).take(600))
                        Marker(
                          point: LatLng(la, lo),
                          width: 14,
                          height: 14,
                          child: IgnorePointer(
                            child: Text('⚡', style: TextStyle(fontSize: 12, color: c.storm)),
                          ),
                        ),
                    ],
                  ),
                ),
              if (s != null) ValueLabelsLayer(sampler: s, layer: _layer),
              MarkerLayer(
                markers: [
                  for (final p in _pins)
                    Marker(
                      point: LatLng(p.lat, p.lon),
                      width: 120,
                      height: 52,
                      child: GestureDetector(
                        onTap: () => setState(() {
                          _pin = p;
                          _probe = null;
                          _expanded = true;
                        }),
                        child: Semantics(
                          button: true,
                          label: '${p.name}. Show details',
                          child: Column(
                            children: [
                              Container(
                                width: _pin == p ? 26 : 20,
                                height: _pin == p ? 26 : 20,
                                decoration: BoxDecoration(
                                  color: p.rating == null ? c.text : c.ratingColor(p.rating!),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: c.bg, width: 2.5),
                                ),
                                child: p.rating == null
                                    ? null
                                    : Center(
                                        child: Text(
                                          '${p.rating}',
                                          style: OgText.chip.copyWith(color: c.bg, fontWeight: FontWeight.w800, fontSize: 11),
                                        ),
                                      ),
                              ),
                              Text(
                                p.name,
                                overflow: TextOverflow.ellipsis,
                                style: OgText.chip.copyWith(
                                  color: c.text,
                                  fontWeight: FontWeight.w700,
                                  shadows: [
                                    Shadow(color: c.bg, blurRadius: 3),
                                    Shadow(color: c.bg, blurRadius: 8),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  if (_probe != null)
                    Marker(
                      point: _probe!,
                      width: 26,
                      height: 26,
                      child: IgnorePointer(
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: c.text, width: 2.5),
                            color: c.text.withValues(alpha: 0.15),
                          ),
                        ),
                      ),
                    ),
                  if (_me != null)
                    Marker(
                      point: _me!,
                      width: 20,
                      height: 20,
                      child: Container(
                        decoration: BoxDecoration(
                          color: c.water,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                        ),
                      ),
                    ),
                ],
              ),
              // Phones show the attribution inside the panel (it would sit under it).
              if (wide) const SimpleAttributionWidget(source: Text('OpenStreetMap contributors · Open-Meteo')),
            ],
          );

    final panel = _Panel(
      fc: _fc,
      t: _t,
      layer: _layer,
      at: selected,
      pin: _pin,
      pins: _pins,
      expanded: wide || _expanded,
      wide: wide,
      playing: _playing,
      error: _error,
      onPlay: _togglePlay,
      onTime: _setT,
      onToggle: () => setState(() => _expanded = !_expanded),
      onPick: (p) {
        setState(() {
          _pin = p;
          _probe = null;
          _expanded = true;
        });
        if (!_inTest) _map.move(LatLng(p.lat, p.lon), math.max(_map.camera.zoom, 8.5));
      },
      onClear: () => setState(() {
        _pin = null;
        _probe = null;
      }),
    );

    final overlays = SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!widget.embedded) ...[
                  _RoundButton(icon: Icons.arrow_back, label: 'Back', onTap: () => goBack(context, '/map')),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: _Glass(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: OgChipGroup(
                        options: [for (final l in FieldLayer.values) l.label],
                        selected: _layer.label,
                        onSelect: (o) => setState(() => _layer = FieldLayer.values.firstWhere((l) => l.label == o)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _Legend(layer: _layer),
                if (_warnings.isNotEmpty)
                  Material(
                    color: _warnColor(c, _warnings.first.level).withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(999),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(999),
                      onTap: () => showOgSheet(context, child: _WarningsList(_warnings)),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Text(
                          '⚠ ${_warnings.length} warning${_warnings.length == 1 ? '' : 's'}',
                          style: OgText.chip.copyWith(color: Colors.black87, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );

    final buttons = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (wide) ...[
          _RoundButton(icon: Icons.add, label: 'Zoom in', onTap: () => _map.move(_map.camera.center, _map.camera.zoom + 1)),
          const SizedBox(height: 8),
          _RoundButton(icon: Icons.remove, label: 'Zoom out', onTap: () => _map.move(_map.camera.center, _map.camera.zoom - 1)),
          const SizedBox(height: 8),
        ],
        _RoundButton(icon: Icons.my_location, label: 'My location', onTap: _locate),
      ],
    );

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () => step(-1),
        const SingleActivator(LogicalKeyboardKey.arrowRight): () => step(1),
        const SingleActivator(LogicalKeyboardKey.arrowLeft, shift: true): () => step(-6),
        const SingleActivator(LogicalKeyboardKey.arrowRight, shift: true): () => step(6),
        const SingleActivator(LogicalKeyboardKey.space): _togglePlay,
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            widget.embedded ? setState(() => _pin = _probe = null) : goBack(context, '/map'),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: c.bg,
          body: wide
              ? Row(
                  children: [
                    Expanded(
                      child: Stack(
                        children: [
                          Positioned.fill(child: map),
                          overlays,
                          Positioned(right: 12, bottom: 100, child: buttons),
                          if (_fc != null && !_fc!.isEmpty)
                            Positioned(
                              left: 12,
                              right: 12,
                              bottom: 24,
                              child: _Timeline(fc: _fc!, t: _t, playing: _playing, onPlay: _togglePlay, onChanged: _setT),
                            ),
                        ],
                      ),
                    ),
                    Container(
                      width: 380,
                      decoration: BoxDecoration(
                        color: c.bg,
                        border: Border(left: BorderSide(color: c.line)),
                      ),
                      child: SafeArea(left: false, child: panel),
                    ),
                  ],
                )
              : Stack(
                  children: [
                    Positioned.fill(child: map),
                    overlays,
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Padding(padding: const EdgeInsets.only(right: 12, bottom: 10), child: buttons),
                          Padding(padding: const EdgeInsets.fromLTRB(8, 0, 8, 8), child: panel),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  static Color _warnColor(OratgeColors c, String level) => switch (level) {
    'red' => c.warnRed,
    'orange' => c.warnOrange,
    _ => c.warnYellow,
  };
}

class _WarningsList extends StatelessWidget {
  const _WarningsList(this.ws);
  final List<Warning> ws;
  @override
  Widget build(BuildContext context) {
    final c = context.og;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Official warnings', style: OgText.verdictBest.copyWith(color: c.text)),
        const SizedBox(height: 10),
        for (final w in ws) ...[
          OgWarningBanner(level: w.level, title: w.title, detail: w.detail, pre: w.pre),
          const SizedBox(height: 10),
        ],
        Text('Servei Meteorològic de Catalunya', style: OgText.src.copyWith(color: c.text3)),
      ],
    );
  }
}

/// Details panel: timeline (phone), the selected point or place with every value and its 48-hour
/// curve for the active layer, and — with nothing selected — your places at the selected hour.
class _Panel extends StatelessWidget {
  const _Panel({
    required this.fc,
    required this.t,
    required this.layer,
    required this.at,
    required this.pin,
    required this.pins,
    required this.expanded,
    required this.wide,
    required this.playing,
    required this.error,
    required this.onPlay,
    required this.onTime,
    required this.onToggle,
    required this.onPick,
    required this.onClear,
  });
  final MapForecast? fc;
  final int t;
  final FieldLayer layer;
  final LatLng? at;
  final _Pin? pin;
  final List<_Pin> pins;
  final bool expanded, wide, playing;
  final String? error;
  final VoidCallback onPlay, onToggle, onClear;
  final ValueChanged<int> onTime;
  final ValueChanged<_Pin> onPick;

  @override
  Widget build(BuildContext context) {
    final c = context.og;
    final u = AppScope.of(context).units;
    final f = fc;
    if (f == null || f.isEmpty) {
      return _Glass(
        child: Text(
          f == null ? (error ?? 'Loading the forecast…') : 'The weather map needs the Oratge server.',
          style: OgText.chip.copyWith(color: c.text2),
        ),
      );
    }
    final cur = f.times[t];
    final title =
        pin?.name ?? (at == null ? 'Your places' : '${at!.latitude.toStringAsFixed(2)}, ${at!.longitude.toStringAsFixed(2)}');
    final timeLine = '${_wd[cur.weekday - 1]} ${cur.hour.toString().padLeft(2, '0')}:00 · ${t == 0 ? 'now' : 'in $t h'}';

    final body = <Widget>[
      Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: OgText.actWindow.copyWith(color: c.text),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  pin?.sport == null ? timeLine : '${sportNames[pin!.sport]} · $timeLine',
                  style: OgText.chip.copyWith(color: c.text2),
                ),
              ],
            ),
          ),
          if (at != null)
            IconButton(
              tooltip: 'Clear',
              onPressed: onClear,
              icon: Icon(Icons.close, color: c.text2),
            )
          else if (!wide)
            IconButton(
              tooltip: expanded ? 'Show less' : 'Show more',
              onPressed: onToggle,
              icon: Icon(expanded ? Icons.expand_more : Icons.expand_less, color: c.text2),
            ),
        ],
      ),
      const SizedBox(height: 8),
      if (at != null) ...[
        _Values(f: f, t: t, at: at!, u: u),
        if (expanded) ...[
          const SizedBox(height: 12),
          Text(
            '${layer == FieldLayer.rating ? 'WIND' : layer.label.toUpperCase()} · NEXT 48 HOURS',
            style: OgText.label.copyWith(color: c.text2),
          ),
          const SizedBox(height: 6),
          _PointChart(f: f, t: t, at: at!, layer: layer == FieldLayer.rating ? FieldLayer.wind : layer, u: u, onTime: onTime),
          const SizedBox(height: 10),
          _Days(f: f, at: at!, u: u),
          if (pin?.route != null) ...[
            const SizedBox(height: 10),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: c.text,
                foregroundColor: c.bg,
                minimumSize: const Size.fromHeight(44),
              ),
              onPressed: () => context.push(pin!.route!),
              child: const Text('Open planner'),
            ),
          ],
        ],
      ] else if (expanded) ...[
        if (pins.isEmpty) Text('Tap the map anywhere for details.', style: OgText.chip.copyWith(color: c.text2)),
        for (final p in pins)
          InkWell(
            onTap: () => onPick(p),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: _PlaceRow(p: p, f: f, t: t, u: u),
            ),
          ),
        const SizedBox(height: 4),
        Text('Tap the map anywhere for that point’s forecast.', style: OgText.chip.copyWith(color: c.text3)),
      ],
    ];

    if (wide) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
        children: [
          Text('DETAILS', style: OgText.label.copyWith(color: c.text2)),
          const SizedBox(height: 8),
          ...body,
        ],
      );
    }
    return _Glass(
      padding: const EdgeInsets.fromLTRB(14, 8, 6, 10),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.55),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _Timeline(fc: f, t: t, playing: playing, onPlay: onPlay, onChanged: onTime, bare: true),
              ),
              Divider(color: c.line, height: 14),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: body),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('© OpenStreetMap contributors · Open-Meteo', style: OgText.src.copyWith(color: c.text3, fontSize: 10)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlaceRow extends StatelessWidget {
  const _PlaceRow({required this.p, required this.f, required this.t, required this.u});
  final _Pin p;
  final MapForecast f;
  final int t;
  final Units u;
  @override
  Widget build(BuildContext context) {
    final c = context.og;
    final s = FieldSampler(f, t);
    final (wu, wv) = s.wind(p.lat, p.lon);
    final speed = math.sqrt(wu * wu + wv * wv);
    final from = (math.atan2(-wu, -wv) * 180 / math.pi + 360) % 360;
    final rain = s.sample('pprob', p.lat, p.lon);
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: p.rating == null ? c.text3 : c.ratingColor(p.rating!), shape: BoxShape.circle),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            p.name,
            style: OgText.day.copyWith(color: c.text),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Text('${compassName(from)} ${u.windText(speed)}', style: OgText.chip.copyWith(color: c.wind)),
        const SizedBox(width: 10),
        Text(u.tempText(s.sample('temp', p.lat, p.lon)), style: OgText.chip.copyWith(color: c.heat)),
        const SizedBox(width: 10),
        SizedBox(
          width: 38,
          child: Text(
            '${rain.round()}%',
            textAlign: TextAlign.right,
            style: OgText.chip.copyWith(color: c.water),
          ),
        ),
      ],
    );
  }
}

/// Every value at the point for the selected hour.
class _Values extends StatelessWidget {
  const _Values({required this.f, required this.t, required this.at, required this.u});
  final MapForecast f;
  final int t;
  final LatLng at;
  final Units u;
  @override
  Widget build(BuildContext context) {
    final c = context.og;
    final s = FieldSampler(f, t);
    final (wu, wv) = s.wind(at.latitude, at.longitude);
    final speed = math.sqrt(wu * wu + wv * wv);
    final from = (math.atan2(-wu, -wv) * 180 / math.pi + 360) % 360;
    Widget item(String label, String value, Color col) => SizedBox(
      width: 92,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: OgText.label.copyWith(color: c.text2)),
          Text(value, style: OgText.actWindow.copyWith(color: col, fontSize: 17)),
        ],
      ),
    );
    final storm = f.fields.containsKey('storm') ? s.sample('storm', at.latitude, at.longitude) : null;
    return Wrap(
      spacing: 4,
      runSpacing: 10,
      children: [
        item('Wind', '${compassName(from)} ${u.windText(speed)}', c.wind),
        item('Gusts', u.windText(s.sample('gust', at.latitude, at.longitude)), c.wind),
        item('Temp', u.tempText(s.sample('temp', at.latitude, at.longitude)), c.heat),
        item('Rain', '${s.sample('precip', at.latitude, at.longitude).toStringAsFixed(1)} mm', c.water),
        item('Chance', '${s.sample('pprob', at.latitude, at.longitude).round()} %', c.water),
        if (storm != null) item('Thunder', '${storm.round()} %', storm >= 30 ? c.storm : c.text2),
      ],
    );
  }
}

/// 48-hour curve at the point for the active layer; tap or drag to move the timeline.
class _PointChart extends StatelessWidget {
  const _PointChart({
    required this.f,
    required this.t,
    required this.at,
    required this.layer,
    required this.u,
    required this.onTime,
  });
  final MapForecast f;
  final int t;
  final LatLng at;
  final FieldLayer layer;
  final Units u;
  final ValueChanged<int> onTime;

  String get _key => switch (layer) {
    FieldLayer.temp => 'temp',
    FieldLayer.rain => 'precip',
    FieldLayer.chance => 'pprob',
    FieldLayer.thunder => 'storm',
    _ => 'wind',
  };

  @override
  Widget build(BuildContext context) {
    final c = context.og;
    final n = f.times.length;
    final vals = [for (var i = 0; i < n; i++) FieldSampler(f, i).sample(_key, at.latitude, at.longitude)];
    final gust = layer == FieldLayer.wind
        ? [for (var i = 0; i < n; i++) FieldSampler(f, i).sample('gust', at.latitude, at.longitude)]
        : null;
    final col = switch (layer) {
      FieldLayer.temp => c.heat,
      FieldLayer.rain || FieldLayer.chance => c.water,
      FieldLayer.thunder => c.storm,
      _ => c.wind,
    };
    String fmt(double v) => switch (layer) {
      FieldLayer.temp => u.tempText(v),
      FieldLayer.rain => '${v.toStringAsFixed(1)} mm',
      FieldLayer.chance || FieldLayer.thunder => '${v.round()} %',
      _ => u.windText(v),
    };
    return LayoutBuilder(
      builder: (context, box) {
        int idx(double dx) => ((dx / box.maxWidth) * n).floor().clamp(0, n - 1);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) => onTime(idx(d.localPosition.dx)),
          onHorizontalDragUpdate: (d) => onTime(idx(d.localPosition.dx)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${fmt(vals[t])}${gust != null ? ' · gusts ${fmt(gust[t])}' : ''}',
                style: OgText.chip.copyWith(color: c.text, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              SizedBox(
                height: 90,
                child: CustomPaint(
                  size: Size.infinite,
                  painter: _PointPainter(f.times, vals, gust, t, col, c, bars: layer == FieldLayer.rain, fmt: fmt),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PointPainter extends CustomPainter {
  _PointPainter(this.times, this.v, this.band, this.t, this.col, this.c, {required this.bars, required this.fmt});
  final List<DateTime> times;
  final List<double> v;
  final List<double>? band;
  final int t;
  final Color col;
  final OratgeColors c;
  final bool bars;
  final String Function(double) fmt;

  @override
  void paint(Canvas canvas, Size size) {
    final n = v.length;
    if (n < 2) return;
    final all = [...v, ...?band];
    var lo = all.reduce(math.min), hi = all.reduce(math.max);
    if (bars) lo = 0;
    if (hi - lo < 1) hi = lo + 1;
    final top = 6.0, bottom = size.height - 14;
    double x(int i) => (i + 0.5) / n * size.width;
    double y(double val) => bottom - (val - lo) / (hi - lo) * (bottom - top);
    for (var i = 1; i < n; i++) {
      if (times[i].hour == 0) {
        canvas.drawLine(Offset(x(i), 0), Offset(x(i), bottom), Paint()..color = c.line);
        ogText(canvas, _wd[times[i].weekday - 1], x(i) + 3, size.height - 2, color: c.text3, size: 10);
      }
    }
    if (bars) {
      final w = size.width / n * 0.7;
      for (var i = 0; i < n; i++) {
        if (v[i] <= 0.05) continue;
        canvas.drawRect(
          Rect.fromLTRB(x(i) - w / 2, y(v[i]), x(i) + w / 2, bottom),
          Paint()..color = col.withValues(alpha: i == t ? 1 : 0.7),
        );
      }
    } else {
      if (band != null) {
        final p = Path()..moveTo(x(0), y(band![0]));
        for (var i = 1; i < n; i++) {
          p.lineTo(x(i), y(band![i]));
        }
        for (var i = n - 1; i >= 0; i--) {
          p.lineTo(x(i), y(v[i]));
        }
        canvas.drawPath(p..close(), Paint()..color = col.withValues(alpha: 0.18));
      }
      final line = Path()..moveTo(x(0), y(v[0]));
      for (var i = 1; i < n; i++) {
        line.lineTo(x(i), y(v[i]));
      }
      canvas.drawPath(
        line,
        Paint()
          ..color = col
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
    ogText(canvas, fmt(hi), 2, top + 8, color: c.text3, size: 10);
    canvas.drawLine(
      Offset(x(t), 0),
      Offset(x(t), bottom),
      Paint()
        ..color = c.text
        ..strokeWidth = 1.5,
    );
    if (!bars) canvas.drawCircle(Offset(x(t), y(v[t])), 4, Paint()..color = col);
  }

  @override
  bool shouldRepaint(_PointPainter o) => o.t != t || o.v != v || o.col != col;
}

/// Day by day at the point: low–high temperature, strongest wind, rain total.
class _Days extends StatelessWidget {
  const _Days({required this.f, required this.at, required this.u});
  final MapForecast f;
  final LatLng at;
  final Units u;
  @override
  Widget build(BuildContext context) {
    final c = context.og;
    final byDay = <DateTime, List<int>>{};
    for (var i = 0; i < f.times.length; i++) {
      final d = DateTime(f.times[i].year, f.times[i].month, f.times[i].day);
      (byDay[d] ??= []).add(i);
    }
    return Column(
      children: [
        for (final e in byDay.entries.where((e) => e.value.length >= 6))
          Builder(
            builder: (context) {
              double v(String k, int i) => FieldSampler(f, i).sample(k, at.latitude, at.longitude);
              final temps = [for (final i in e.value) v('temp', i)];
              final wind = e.value.map((i) => v('wind', i)).reduce(math.max);
              final rain = e.value.map((i) => v('precip', i)).fold<double>(0, (a, b) => a + b);
              final storm = f.fields.containsKey('storm') ? e.value.map((i) => v('storm', i)).reduce(math.max) : 0.0;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    SizedBox(
                      width: 44,
                      child: Text(_wd[e.key.weekday - 1], style: OgText.day.copyWith(color: c.text)),
                    ),
                    Expanded(
                      child: Text(
                        '${u.tempText(temps.reduce(math.min))}–${u.tempText(temps.reduce(math.max))}',
                        style: OgText.chip.copyWith(color: c.heat),
                      ),
                    ),
                    Text('max ${u.windText(wind)}', style: OgText.chip.copyWith(color: c.wind)),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 74,
                      child: Text(
                        '${rain.toStringAsFixed(1)} mm${storm >= 30 ? ' ⚡' : ''}',
                        textAlign: TextAlign.right,
                        style: OgText.chip.copyWith(color: c.water),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
}

/// 48-hour timeline: scrub or play; bars show the area's heaviest rain each hour.
class _Timeline extends StatelessWidget {
  const _Timeline({
    required this.fc,
    required this.t,
    required this.playing,
    required this.onPlay,
    required this.onChanged,
    this.bare = false,
  });
  final MapForecast fc;
  final int t;
  final bool playing, bare;
  final VoidCallback onPlay;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.og;
    final n = fc.times.length;
    final rain = [for (final row in fc.fields['precip']!) row.reduce(math.max)];
    final cur = fc.times[t];
    final content = Row(
      children: [
        IconButton(
          tooltip: playing ? 'Pause' : 'Play forecast',
          iconSize: 30,
          onPressed: onPlay,
          icon: Icon(playing ? Icons.pause_circle_filled : Icons.play_circle_fill, color: c.text),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text(
                    '${_wd[cur.weekday - 1]} ${cur.hour.toString().padLeft(2, '0')}:00',
                    style: OgText.actWindow.copyWith(color: c.text),
                  ),
                  const Spacer(),
                  Text(t == 0 ? 'now' : '+$t h', style: OgText.chip.copyWith(color: c.text2)),
                ],
              ),
              SizedBox(
                height: 38,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: CustomPaint(painter: _TrackPainter(fc.times, rain, c)),
                      ),
                    ),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 2,
                        activeTrackColor: c.text,
                        inactiveTrackColor: c.line,
                        thumbColor: c.text,
                        overlayColor: c.text.withValues(alpha: 0.12),
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                        tickMarkShape: SliderTickMarkShape.noTickMark,
                      ),
                      child: Semantics(
                        label: 'Forecast hour',
                        value: '${_wd[cur.weekday - 1]} ${cur.hour}:00',
                        child: Slider(
                          value: t.toDouble(),
                          min: 0,
                          max: (n - 1).toDouble(),
                          divisions: n - 1,
                          onChanged: (v) => onChanged(v.round()),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
    return bare ? content : _Glass(padding: const EdgeInsets.fromLTRB(6, 6, 14, 8), child: content);
  }
}

class _TrackPainter extends CustomPainter {
  _TrackPainter(this.times, this.rain, this.c);
  final List<DateTime> times;
  final List<double> rain;
  final OratgeColors c;
  @override
  void paint(Canvas canvas, Size size) {
    final n = times.length;
    final w = size.width / n;
    for (var i = 0; i < n; i++) {
      if (times[i].hour == 0 && i > 0) {
        canvas.drawLine(Offset(i * w, 0), Offset(i * w, size.height), Paint()..color = c.line);
        ogText(canvas, _wd[times[i].weekday - 1], i * w + 3, 11, color: c.text2);
      }
      final r = rain[i];
      if (r >= 0.1) {
        final h = (math.min(r, 8) / 8) * 12 + 2;
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(i * w + 0.5, size.height - h, math.max(1, w - 1), h), const Radius.circular(1)),
          Paint()..color = c.water.withValues(alpha: 0.8),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_TrackPainter o) => o.times != times || o.c != c;
}

class _Legend extends StatelessWidget {
  const _Legend({required this.layer});
  final FieldLayer layer;
  @override
  Widget build(BuildContext context) {
    final c = context.og;
    final colors = FieldColors(c);
    final stops = colors.legend(layer);
    return _Glass(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 170,
            height: 7,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              gradient: LinearGradient(colors: [for (final s in stops) s.$2]),
            ),
          ),
          const SizedBox(height: 3),
          SizedBox(
            width: 170,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [for (final s in stops) Text(s.$1, style: OgText.chip.copyWith(color: c.text, fontSize: 11))],
            ),
          ),
          if (colors.unit(layer).isNotEmpty) Text(colors.unit(layer), style: OgText.chip.copyWith(color: c.text2, fontSize: 11)),
        ],
      ),
    );
  }
}

class _Glass extends StatelessWidget {
  const _Glass({required this.child, this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 9)});
  final Widget child;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) {
    final c = context.og;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: c.bg.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 12)],
      ),
      child: child,
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final c = context.og;
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: c.bg.withValues(alpha: 0.92),
        shape: const CircleBorder(),
        elevation: 2,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox.square(dimension: 46, child: Icon(icon, color: c.text)),
        ),
      ),
    );
  }
}
