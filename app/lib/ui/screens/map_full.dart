import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
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
import '../motion.dart';

bool get _inTest => !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');

/// Full-screen map: a live wind / temperature / rain field over Catalonia plus your spots.
class MapFullScreen extends StatefulWidget {
  const MapFullScreen({super.key});
  @override
  State<MapFullScreen> createState() => _MapFullScreenState();
}

class _MapFullScreenState extends State<MapFullScreen> {
  final _map = MapController();
  String _layer = 'Wind';
  LatLng? _me;
  late Future<(GridData, MapData)> _data;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final repo = AppScope.of(context).repository;
    _data = Future.wait([repo.grid(), repo.map()]).then((r) => (r[0] as GridData, r[1] as MapData));
  }

  Future<void> _locate() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) return;
      final p = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.low, timeLimit: Duration(seconds: 12)));
      setState(() => _me = LatLng(p.latitude, p.longitude));
      _map.move(_me!, 10);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Couldn’t get your location.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.og;
    return Scaffold(
      body: FutureBuilder<(GridData, MapData)>(
        future: _data,
        builder: (context, snap) {
          final grid = snap.data?.$1;
          final pins = snap.data?.$2.pins ?? const <MapPin>[];
          return Stack(children: [
            if (_inTest)
              Positioned.fill(child: ColoredBox(color: c.surface))
            else
              FlutterMap(
                mapController: _map,
                options: MapOptions(
                  initialCenter: const LatLng(41.75, 1.85),
                  initialZoom: 7.6,
                  minZoom: 6,
                  maxZoom: 14,
                  backgroundColor: c.bg,
                  interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
                ),
                children: [
                  oratgeTiles(context),
                  if (grid != null) _FieldLayer(points: grid.points, layer: _layer),
                  MarkerLayer(markers: [
                    for (final p in pins.where((p) => p.lat != null))
                      Marker(
                        point: LatLng(p.lat!, p.lon!),
                        width: 130,
                        height: 56,
                        child: GestureDetector(
                          onTap: () => _spotSheet(context, p),
                          child: Semantics(
                            button: true,
                            label: '${p.name}, rating ${p.rating}. Open',
                            child: Column(children: [
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                    color: c.ratingColor(p.rating),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: c.bg, width: 2.5),
                                    boxShadow: [BoxShadow(color: c.bg.withValues(alpha: 0.5), blurRadius: 6)]),
                                child: Center(
                                    child: Text('${p.rating}',
                                        style: OgText.chip.copyWith(color: c.bg, fontWeight: FontWeight.w800))),
                              ),
                              Text(p.name.split(' · ').first,
                                  style: OgText.chip.copyWith(color: c.text, fontWeight: FontWeight.w700, shadows: [
                                    Shadow(color: c.bg, blurRadius: 3),
                                    Shadow(color: c.bg, blurRadius: 8),
                                  ])),
                            ]),
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
                              color: c.water, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3)),
                        ),
                      ),
                  ]),
                  const SimpleAttributionWidget(source: Text('OpenStreetMap contributors')),
                ],
              ),
            // Top bar: back, title + time, layer chips.
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    _RoundButton(icon: Icons.arrow_back, label: 'Back', onTap: () => context.pop()),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                        decoration: BoxDecoration(color: c.bg.withValues(alpha: 0.88), borderRadius: BorderRadius.circular(999)),
                        child: Text(
                            grid == null
                                ? 'Loading the map…'
                                : grid.points.isEmpty
                                    ? 'Live field needs the backend (offline)'
                                    : '$_layer at ${grid.time} · ${grid.points.length} points (model)',
                            style: OgText.chip.copyWith(color: c.text, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: BoxDecoration(color: c.bg.withValues(alpha: 0.88), borderRadius: BorderRadius.circular(999)),
                    child: OgChipGroup(
                        options: const ['Wind', 'Temp', 'Rain', 'Rating'],
                        selected: _layer,
                        onSelect: (o) => setState(() => _layer = o)),
                  ),
                ]),
              ),
            ),
            Positioned(left: 12, bottom: 24, child: SafeArea(child: _Legend(layer: _layer))),
            Positioned(
              right: 16,
              bottom: 28,
              child: SafeArea(child: _RoundButton(icon: Icons.my_location, label: 'My location', onTap: _locate)),
            ),
          ]);
        },
      ),
    );
  }

  void _spotSheet(BuildContext context, MapPin p) {
    final c = context.og;
    showOgSheet(
      context,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(p.name, style: OgText.verdictBest.copyWith(color: c.text)),
        Text(sportNames[p.sport] ?? '', style: OgText.day.copyWith(color: c.text2)),
        const SizedBox(height: 12),
        Row(children: [
          OgRatingDots(value: p.rating, large: true, showWord: true),
          const Spacer(),
          if (p.window != null) Text(p.window!, style: OgText.actWindow.copyWith(color: c.text)),
        ]),
        const SizedBox(height: 14),
        OgFactGrid(columns: 2, children: [
          OgFactTile(label: 'Wind', value: '${p.wind.round()} kn', sub: 'from ${compassName(p.windFrom.toDouble())}', accent: OgAccent.wind),
          OgFactTile(label: 'Gusts', value: p.gust == null ? '—' : '${p.gust!.round()} kn', accent: OgAccent.wind),
        ]),
        const SizedBox(height: 16),
        Row(children: [
          if (p.sport != null)
            Expanded(
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: c.text, foregroundColor: c.bg, minimumSize: const Size.fromHeight(48)),
                onPressed: () {
                  Navigator.of(context).pop();
                  context.go('/activities/${p.sport}');
                },
                child: const Text('Open planner'),
              ),
            ),
          if (p.id != null) ...[
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48), side: BorderSide(color: c.line), foregroundColor: c.text),
                onPressed: () {
                  Navigator.of(context).pop();
                  context.go('/spots/${p.id}');
                },
                child: const Text('Spot details'),
              ),
            ),
          ],
        ]),
      ]),
    );
  }
}

/// Grid of current conditions; values are shown once zoomed in enough to read them.
class _FieldLayer extends StatelessWidget {
  const _FieldLayer({required this.points, required this.layer});
  final List<GridPoint> points;
  final String layer;

  @override
  Widget build(BuildContext context) {
    if (layer == 'Rating') return const SizedBox.shrink();
    final c = context.og;
    final zoom = MapCamera.of(context).zoom;
    final showValues = zoom >= 7.9;
    return MarkerLayer(markers: [
      for (final p in points)
        if (layer != 'Rain' || p.precip > 0)
          Marker(
            point: LatLng(p.lat, p.lon),
            width: 40,
            height: 44,
            child: IgnorePointer(
              child: Column(children: [
                if (layer == 'Wind')
                  CustomPaint(size: const Size(26, 26), painter: _ArrowPainter(c, p))
                else
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: layer == 'Temp'
                          ? Color.lerp(c.snow, c.heat, ((p.temp - 0) / 30).clamp(0, 1))!.withValues(alpha: 0.85)
                          : c.water.withValues(alpha: (0.25 + p.precip / 4).clamp(0.25, 0.95)),
                    ),
                  ),
                if (showValues)
                  Text(
                    layer == 'Wind'
                        ? '${p.wind.round()}'
                        : layer == 'Temp'
                            ? '${p.temp.round()}°'
                            : p.precip.toStringAsFixed(1),
                    style: OgText.chip.copyWith(color: c.text, fontWeight: FontWeight.w700, shadows: [Shadow(color: c.bg, blurRadius: 4)]),
                  ),
              ]),
            ),
          ),
    ]);
  }
}

class _ArrowPainter extends CustomPainter {
  _ArrowPainter(this.c, this.p);
  final OratgeColors c;
  final GridPoint p;
  @override
  void paint(Canvas canvas, Size size) =>
      windArrow(canvas, Offset(size.width / 2, size.height / 2), p.wdir, c.windColor(p.wind), len: 10, width: 2.6);
  @override
  bool shouldRepaint(_ArrowPainter o) => o.p != p || o.c != c;
}

class _Legend extends StatelessWidget {
  const _Legend({required this.layer});
  final String layer;
  @override
  Widget build(BuildContext context) {
    final c = context.og;
    Widget sw(Color col, String t) => Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 12, height: 12, decoration: BoxDecoration(color: col, borderRadius: BorderRadius.circular(3))),
            const SizedBox(width: 4),
            Text(t, style: OgText.chip.copyWith(color: c.text)),
          ]),
        );
    final items = switch (layer) {
      'Wind' => [sw(c.wind1, '<8'), sw(c.wind2, '8'), sw(c.wind3, '11'), sw(c.wind4, '14'), sw(c.wind5, '17+ kn')],
      'Temp' => [sw(c.snow, '0°'), sw(Color.lerp(c.snow, c.heat, 0.5)!, '15°'), sw(c.heat, '30°')],
      'Rain' => [sw(c.water.withValues(alpha: 0.3), 'light'), sw(c.water, '4+ mm/h')],
      _ => [for (var r = 1; r <= 5; r++) sw(c.ratingColor(r), '$r')],
    };
    return AnimatedSwitcher(
      duration: motion(context, 200),
      child: Container(
        key: ValueKey(layer),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: c.bg.withValues(alpha: 0.88), borderRadius: BorderRadius.circular(14)),
        child: Row(mainAxisSize: MainAxisSize.min, children: items),
      ),
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
