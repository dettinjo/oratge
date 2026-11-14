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
import 'package:latlong2/latlong.dart';

import '../../data/models.dart';
import '../../data/profile.dart';
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

bool get _inTest => !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');
const _wd = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// Full-screen weather map: smooth wind / temperature / rain / rain-chance fields with wind
/// particles and falling rain, a 48-hour timeline (scrub or play), a tap-anywhere probe and your spots.
class MapFullScreen extends StatefulWidget {
  const MapFullScreen({super.key});
  @override
  State<MapFullScreen> createState() => _MapFullScreenState();
}

class _MapFullScreenState extends State<MapFullScreen> {
  final _map = MapController();
  FieldLayer _layer = FieldLayer.wind;
  int _t = 0;
  bool _playing = false;
  Timer? _play;
  LatLng? _me, _probe;
  MapForecast? _fc;
  Future<List<(double, double)>>? _strikes; // measured lightning, loaded when the Thunder layer opens
  List<MapPin> _pins = const [];
  String? _error;
  final Map<(FieldLayer, int, Brightness), ui.Image> _images = {};
  bool _rendering = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_fc == null && _error == null) _load();
  }

  Future<void> _load() async {
    final repo = AppScope.of(context).repository;
    try {
      final r = await Future.wait([repo.mapForecast(), repo.map()]);
      if (!mounted) return;
      setState(() {
        _fc = r[0] as MapForecast;
        _pins = (r[1] as MapData).pins;
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

  /// Renders (and caches) the field image for the current layer and hour.
  void _ensureImage(OratgeColors c, Brightness b) {
    final s = _sampler;
    if (s == null || _layer == FieldLayer.rating || _rendering) return;
    final key = (_layer, _t, b);
    if (_images.containsKey(key)) return;
    _rendering = true;
    renderField(s, _layer, FieldColors(c)).then((img) {
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
        if (!mounted) return;
        setState(() => _t = (_t + 1) % n);
      });
    }
  }

  Future<void> _locate() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) return;
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.low, timeLimit: Duration(seconds: 12)),
      );
      setState(() => _me = LatLng(p.latitude, p.longitude));
      _map.move(_me!, 10);
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Couldn’t get your location.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.og;
    final b = Theme.of(context).brightness;
    _ensureImage(c, b);
    final s = _sampler;
    final img =
        _images[(_layer, _t, b)] ??
        // While the next hour renders, keep showing the closest finished one so scrubbing stays smooth.
        _images.entries.where((e) => e.key.$1 == _layer && e.key.$3 == b).map((e) => e.value).firstOrNull;
    final motionOn = !reduceMotion(context);

    final n = _fc?.times.length ?? 0;
    void step(int d) {
      if (n == 0) return;
      setState(() => _t = (_t + d).clamp(0, n - 1));
    }

    return CallbackShortcuts(
      // Keyboard (Mac/desktop): ←/→ step the hour (shift: 6 h), space plays, Esc goes back.
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () => step(-1),
        const SingleActivator(LogicalKeyboardKey.arrowRight): () => step(1),
        const SingleActivator(LogicalKeyboardKey.arrowLeft, shift: true): () => step(-6),
        const SingleActivator(LogicalKeyboardKey.arrowRight, shift: true): () => step(6),
        const SingleActivator(LogicalKeyboardKey.space): _togglePlay,
        const SingleActivator(LogicalKeyboardKey.escape): () => context.pop(),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          body: Stack(
            children: [
              if (_inTest)
                Positioned.fill(child: ColoredBox(color: c.surface))
              else
                FlutterMap(
                  mapController: _map,
                  options: MapOptions(
                    // Fit the forecast area to any window, from a phone to a large Mac display.
                    initialCameraFit: CameraFit.bounds(
                      bounds: LatLngBounds(const LatLng(40.45, 0.2), const LatLng(42.85, 3.35)),
                      padding: const EdgeInsets.fromLTRB(16, 150, 16, 130),
                    ),
                    minZoom: 6,
                    maxZoom: 13,
                    backgroundColor: c.bg,
                    interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
                    onTap: (_, ll) {
                      HapticFeedback.selectionClick();
                      setState(() => _probe = ll);
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
                        builder: (context, snap) => MarkerLayer(markers: [
                          for (final (la, lo) in (snap.data ?? const <(double, double)>[]).take(600))
                            Marker(
                              point: LatLng(la, lo),
                              width: 14,
                              height: 14,
                              child: IgnorePointer(child: Text('⚡', style: TextStyle(fontSize: 12, color: c.storm))),
                            ),
                        ]),
                      ),
                    if (s != null) ValueLabelsLayer(sampler: s, layer: _layer),
                    MarkerLayer(
                      markers: [
                        for (final p in _pins.where((p) => p.lat != null))
                          Marker(
                            point: LatLng(p.lat!, p.lon!),
                            width: 130,
                            height: 56,
                            child: GestureDetector(
                              onTap: () => _spotSheet(context, p),
                              child: Semantics(
                                button: true,
                                label: '${p.name}, rating ${p.rating}. Open',
                                child: Column(
                                  children: [
                                    AnimatedContainer(
                                      duration: motion(context, 250),
                                      width: _layer == FieldLayer.rating ? 30 : 22,
                                      height: _layer == FieldLayer.rating ? 30 : 22,
                                      decoration: BoxDecoration(
                                        color: c.ratingColor(p.rating),
                                        shape: BoxShape.circle,
                                        border: Border.all(color: c.bg, width: 2.5),
                                        boxShadow: [BoxShadow(color: c.bg.withValues(alpha: 0.5), blurRadius: 6)],
                                      ),
                                      child: Center(
                                        child: Text(
                                          '${p.rating}',
                                          style: OgText.chip.copyWith(color: c.bg, fontWeight: FontWeight.w800, fontSize: 12),
                                        ),
                                      ),
                                    ),
                                    Text(
                                      p.name.split(' · ').first,
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
                            width: 22,
                            height: 22,
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
                    const SimpleAttributionWidget(source: Text('OpenStreetMap contributors · Open-Meteo')),
                  ],
                ),
              // Top: back, title, layers, legend.
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _RoundButton(icon: Icons.arrow_back, label: 'Back', onTap: () => context.pop()),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _Glass(
                              child: Text(
                                _fc == null
                                    ? (_error ?? 'Loading the forecast…')
                                    : _fc!.isEmpty
                                    ? 'Forecast map needs the backend (offline)'
                                    : '${_layer.label} · ${_timeLabel(_fc!.times[_t], _t)}',
                                style: OgText.chip.copyWith(color: c.text, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SingleChildScrollView(
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
                      const SizedBox(height: 8),
                      _Legend(layer: _layer),
                    ],
                  ),
                ),
              ),
              // Bottom: probe card + timeline.
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: SafeArea(
                  top: false,
                  child: Padding(
                    // Leaves room for the map attribution underneath.
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 26),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _RoundButton(icon: Icons.my_location, label: 'My location', onTap: _locate),
                        const SizedBox(height: 10),
                        AnimatedSwitcher(
                          duration: motion(context, 200),
                          child: (_probe != null && s != null)
                              ? _ProbeCard(
                                  key: ValueKey(_probe),
                                  sampler: s,
                                  at: _probe!,
                                  onClose: () => setState(() => _probe = null),
                                )
                              : const SizedBox.shrink(),
                        ),
                        if (_fc != null && !_fc!.isEmpty) ...[
                          const SizedBox(height: 8),
                          _Timeline(
                            fc: _fc!,
                            t: _t,
                            playing: _playing,
                            onPlay: _togglePlay,
                            onChanged: (v) {
                              if (v != _t) HapticFeedback.selectionClick();
                              setState(() => _t = v);
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Forecast times are local to Catalonia and step 0 is the current hour, so label by step, not device clock.
  static String _timeLabel(DateTime t, int step) {
    final when = step == 0 ? 'now' : 'in $step h';
    return '${_wd[t.weekday - 1]} ${t.hour.toString().padLeft(2, '0')}:00 · $when';
  }

  void _spotSheet(BuildContext context, MapPin p) {
    final c = context.og;
    showOgSheet(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(p.name, style: OgText.verdictBest.copyWith(color: c.text)),
          Text(sportNames[p.sport] ?? '', style: OgText.day.copyWith(color: c.text2)),
          const SizedBox(height: 12),
          Row(
            children: [
              OgRatingDots(value: p.rating, large: true, showWord: true),
              const Spacer(),
              if (p.window != null) Text(p.window!, style: OgText.actWindow.copyWith(color: c.text)),
            ],
          ),
          const SizedBox(height: 14),
          OgFactGrid(
            columns: 2,
            children: [
              OgFactTile(
                label: 'Wind',
                value: '${p.wind.round()} kn',
                sub: 'from ${compassName(p.windFrom.toDouble())}',
                accent: OgAccent.wind,
              ),
              OgFactTile(label: 'Gusts', value: p.gust == null ? '—' : '${p.gust!.round()} kn', accent: OgAccent.wind),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              if (p.sport != null)
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: c.text,
                      foregroundColor: c.bg,
                      minimumSize: const Size.fromHeight(48),
                    ),
                    onPressed: () {
                      Navigator.of(context).pop();
                      context.push('/activities/${p.sport}');
                    },
                    child: const Text('Open planner'),
                  ),
                ),
              if (p.id != null) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      side: BorderSide(color: c.line),
                      foregroundColor: c.text,
                    ),
                    onPressed: () {
                      Navigator.of(context).pop();
                      context.push('/spots/${p.id}');
                    },
                    child: const Text('Spot details'),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Values at a tapped point for the selected hour.
class _ProbeCard extends StatelessWidget {
  const _ProbeCard({super.key, required this.sampler, required this.at, required this.onClose});
  final FieldSampler sampler;
  final LatLng at;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final c = context.og;
    final s = sampler;
    final inside =
        at.latitude <= s.nw.latitude &&
        at.latitude >= s.se.latitude &&
        at.longitude >= s.nw.longitude &&
        at.longitude <= s.se.longitude;
    final (u, v) = s.wind(at.latitude, at.longitude);
    final speed = math.sqrt(u * u + v * v);
    final from = (math.atan2(-u, -v) * 180 / math.pi + 360) % 360;
    Widget item(String label, String value, Color col) => Padding(
      padding: const EdgeInsets.only(right: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: OgText.label.copyWith(color: c.text2)),
          Text(value, style: OgText.actWindow.copyWith(color: col, fontSize: 17)),
        ],
      ),
    );
    return _Glass(
      padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
      child: Row(
        children: [
          Expanded(
            child: !inside
                ? Text('Outside the forecast area', style: OgText.day.copyWith(color: c.text2))
                // One uniform scale for all values: narrow phones shrink the row instead of clipping it.
                : FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Row(
                      children: [
                        item('Wind', '${compassName(from)} ${speed.round()} kn', c.wind),
                        item('Gusts', '${s.sample('gust', at.latitude, at.longitude).round()} kn', c.wind),
                        item('Temp', '${s.sample('temp', at.latitude, at.longitude).round()}°', c.heat),
                        item('Rain', '${s.sample('precip', at.latitude, at.longitude).toStringAsFixed(1)} mm', c.water),
                        item('Chance', '${s.sample('pprob', at.latitude, at.longitude).round()}%', c.water),
                        if (s.f.fields.containsKey('storm'))
                          item('Thunder', '${s.sample('storm', at.latitude, at.longitude).round()}%', c.storm),
                      ],
                    ),
                  ),
          ),
          IconButton(
            tooltip: 'Close',
            onPressed: onClose,
            icon: Icon(Icons.close, color: c.text2),
          ),
        ],
      ),
    );
  }
}

/// 48-hour forecast timeline: scrub or play; rain bars show when and how hard it rains across the area.
class _Timeline extends StatelessWidget {
  const _Timeline({required this.fc, required this.t, required this.playing, required this.onPlay, required this.onChanged});
  final MapForecast fc;
  final int t;
  final bool playing;
  final VoidCallback onPlay;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.og;
    final n = fc.times.length;
    final rain = [for (final row in fc.fields['precip']!) row.reduce(math.max)];
    final cur = fc.times[t];
    return _Glass(
      padding: const EdgeInsets.fromLTRB(6, 6, 14, 8),
      child: Row(
        children: [
          Semantics(
            button: true,
            label: playing ? 'Pause' : 'Play forecast',
            child: IconButton(
              iconSize: 30,
              onPressed: onPlay,
              icon: AnimatedSwitcher(
                duration: motion(context, 150),
                child: Icon(playing ? Icons.pause_circle_filled : Icons.play_circle_fill, key: ValueKey(playing), color: c.text),
              ),
            ),
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
                  height: 40,
                  child: LayoutBuilder(
                    builder: (context, box) {
                      return Stack(
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
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
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
      // Day boundary + label.
      if (times[i].hour == 0 && i > 0) {
        canvas.drawLine(Offset(i * w, 0), Offset(i * w, size.height), Paint()..color = c.line);
        ogText(canvas, _wd[times[i].weekday - 1], i * w + 3, 11, color: c.text2);
      }
      // Area-max rain as small bars below the track.
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
    return AnimatedSwitcher(
      duration: motion(context, 200),
      child: _Glass(
        key: ValueKey(layer),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 190,
              height: 8,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                gradient: LinearGradient(colors: [for (final s in stops) s.$2]),
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: 190,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [for (final s in stops) Text(s.$1, style: OgText.chip.copyWith(color: c.text, fontSize: 12))],
              ),
            ),
            if (colors.unit(layer).isNotEmpty) Text(colors.unit(layer), style: OgText.chip.copyWith(color: c.text2)),
          ],
        ),
      ),
    );
  }
}

class _Glass extends StatelessWidget {
  const _Glass({super.key, required this.child, this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 9)});
  final Widget child;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) {
    final c = context.og;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: c.bg.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 10)],
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
        color: c.bg.withValues(alpha: 0.9),
        shape: const CircleBorder(),
        elevation: 2,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox.square(dimension: 48, child: Icon(icon, color: c.text)),
        ),
      ),
    );
  }
}
