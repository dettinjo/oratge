import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../data/activities.dart';
import '../../data/models.dart';
import '../../data/profile.dart';
import '../../theme/oratge_tokens.dart';
import '../charts/chart_utils.dart';
import '../components/basics.dart';
import '../components/rows_cards.dart';
import 'common.dart';

/// Add or edit an activity to check: a sport at a place, or a GPX route on a day.
class ActivityEditScreen extends StatefulWidget {
  const ActivityEditScreen({super.key, this.id});
  final String? id;
  @override
  State<ActivityEditScreen> createState() => _ActivityEditScreenState();
}

class _ActivityEditScreenState extends State<ActivityEditScreen> {
  late Activity _a;
  bool _loaded = false;
  final _name = TextEditingController();
  final _q = TextEditingController();
  final _speed = TextEditingController();
  List<Place> _results = const [];
  Timer? _debounce;
  String? _msg;
  bool _busy = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    final existing = widget.id == null ? null : AppScope.of(context).activity(widget.id!);
    _a = existing ?? Activity(id: 'a${DateTime.now().millisecondsSinceEpoch}', sport: 'wing', kind: 'spot', name: '');
    _name.text = _a.name;
    _speed.text = _a.speed?.toStringAsFixed(0) ?? '';
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _name.dispose();
    _q.dispose();
    _speed.dispose();
    super.dispose();
  }

  void _set(Activity Function(Activity a) f) => setState(() => _a = f(_a));

  Activity _copy({String? sport, String? kind, String? name, List<List<double?>>? track}) => Activity(
        id: _a.id,
        sport: sport ?? _a.sport,
        kind: kind ?? _a.kind,
        name: name ?? _a.name,
        lat: _a.lat,
        lon: _a.lon,
        facing: _a.facing,
        builtin: _a.builtin,
        track: track ?? _a.track,
        date: _a.date,
        start: _a.start,
        speed: _a.speed,
        notify: _a.notify,
        minRating: _a.minRating,
        daysAhead: _a.daysAhead,
        onlyWhenGood: _a.onlyWhenGood,
      );

  Future<void> _place(Place p) async {
    final repo = AppScope.of(context).repository;
    setState(() {
      _a.lat = p.lat;
      _a.lon = p.lon;
      _results = const [];
      _q.clear();
      if (_name.text.trim().isEmpty) _name.text = p.name;
    });
    if (_a.sport == 'wing' || _a.sport == 'surf') {
      final f = await repo.shore(p.lat, p.lon);
      if (mounted) setState(() => _a.facing = f ?? _a.facing ?? 180);
    }
  }

  Future<void> _current() async {
    setState(() => _busy = true);
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) throw 'Location permission is off.';
      final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium, timeLimit: Duration(seconds: 15)));
      if (!mounted) return;
      final named = await AppScope.of(context).repository.reverse(pos.latitude, pos.longitude);
      await _place(Place(name: named.name, lat: pos.latitude, lon: pos.longitude));
    } catch (e) {
      if (mounted) setState(() => _msg = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _search(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      if (q.trim().length < 2) return setState(() => _results = const []);
      final r = await AppScope.of(context).repository.places(q.trim());
      if (mounted) setState(() => _results = r);
    });
  }

  Future<void> _gpx() async {
    setState(() => _msg = null);
    try {
      final files = await FilePicker.pickFiles(type: FileType.any, dialogTitle: 'Choose a GPX file');
      if (files.isEmpty) return;
      final text = await files.first.xFile.readAsString();
      final g = parseGpx(text);
      if (g.points.length < 2) throw 'No track in that file (expected a GPX with a track or route).';
      final track = simplify(g.points);
      setState(() {
        _a = _copy(track: track);
        _a.lat = track.first[0];
        _a.lon = track.first[1];
        if (_name.text.trim().isEmpty) _name.text = g.name ?? files.first.name.replaceAll(RegExp(r'\.gpx$', caseSensitive: false), '');
      });
    } catch (e) {
      setState(() => _msg = e is String ? e : 'Couldn’t read that file as GPX.');
    }
  }

  void _save() {
    final name = _name.text.trim();
    if (_a.isRoute ? _a.track.length < 2 : _a.lat == null) {
      setState(() => _msg = _a.isRoute ? 'Choose a GPX file first.' : 'Choose a place first.');
      return;
    }
    final a = _copy(name: name.isEmpty ? (sportNames[_a.sport] ?? _a.sport) : name)..speed = double.tryParse(_speed.text.trim());
    AppScope.of(context).upsertActivity(a);
    goBack(context, '/activities');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.og;
    final app = AppScope.of(context);
    final routeOk = const {'bike', 'run', 'hike'}.contains(_a.sport);
    Widget seg<T>(List<(T, String)> o, T v, void Function(T) on) => SegmentedButton<T>(
          showSelectedIcon: false,
          style: SegmentedButton.styleFrom(
              selectedBackgroundColor: c.text,
              selectedForegroundColor: c.bg,
              foregroundColor: c.text2,
              side: BorderSide(color: c.line),
              visualDensity: VisualDensity.compact),
          segments: [for (final (x, l) in o) ButtonSegment(value: x, label: Text(l))],
          selected: {v},
          onSelectionChanged: (s) => on(s.first),
        );
    InputDecoration deco(String hint, {Widget? prefix}) => InputDecoration(
          hintText: hint,
          hintStyle: OgText.body.copyWith(color: c.text3),
          prefixIcon: prefix,
          filled: true,
          fillColor: c.surface,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        );
    final now = DateTime.now();
    String iso(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    return OgPage(
      title: widget.id == null ? 'Add an activity' : 'Edit activity',
      subtitle: 'Checked on Today and in notifications',
      back: (label: 'Back', route: '/activities'),
      children: [
        Columns(left: [
          const OgSectionLabel('Sport', top: 4),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final s in const ['wing', 'surf', 'bike', 'run', 'hike'])
              ChoiceChip(
                label: Text(sportNames[s] ?? s),
                selected: _a.sport == s,
                showCheckmark: false,
                selectedColor: c.text,
                backgroundColor: c.surface,
                labelStyle: OgText.chip.copyWith(color: _a.sport == s ? c.bg : c.text),
                onSelected: (_) => _set((a) => _copy(sport: s, kind: const {'bike', 'run', 'hike'}.contains(s) ? a.kind : 'spot')),
              ),
          ]),
          if (routeOk) ...[
            const OgSectionLabel('What to check'),
            seg<String>([('spot', 'A place'), ('route', 'A GPX route')], _a.kind, (v) => _set((a) => _copy(kind: v))),
          ],
          if (!_a.isRoute) ...[
            const OgSectionLabel('Place'),
            if (_a.lat != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text('📍 ${_a.lat!.toStringAsFixed(4)}, ${_a.lon!.toStringAsFixed(4)}', style: OgText.chip.copyWith(color: c.text2)),
              ),
            Row(children: [
              Expanded(
                child: TextField(controller: _q, onChanged: _search, style: OgText.body.copyWith(color: c.text),
                    decoration: deco('Search a place in Catalonia', prefix: Icon(Icons.search, color: c.text2))),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                tooltip: 'Use my current location',
                onPressed: _busy ? null : _current,
                icon: _busy ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.my_location),
              ),
            ]),
            for (final p in _results)
              ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(p.name, style: OgText.actName.copyWith(color: c.text)),
                  subtitle: Text(p.region, style: OgText.chip.copyWith(color: c.text2)),
                  onTap: () => _place(p)),
            if (_results.isEmpty && app.favorites.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final f in app.favorites)
                    ActionChip(
                        avatar: Icon(Icons.star, size: 16, color: c.sun),
                        label: Text(f.name),
                        backgroundColor: c.surface,
                        labelStyle: OgText.chip.copyWith(color: c.text),
                        onPressed: () => _place(f)),
                ]),
              ),
            if ((_a.sport == 'wing' || _a.sport == 'surf') && _a.lat != null) ...[
              const OgSectionLabel('Beach faces'),
              Text('Detected from the coastline; adjust if needed. Offshore wind (from the land) rates 0.',
                  style: OgText.chip.copyWith(color: c.text2, fontSize: 13)),
              Row(children: [
                Expanded(
                  child: Slider(
                    value: (_a.facing ?? 180).clamp(0, 359),
                    min: 0,
                    max: 359,
                    divisions: 72,
                    activeColor: c.water,
                    onChanged: (v) => setState(() => _a.facing = v),
                  ),
                ),
                SizedBox(
                    width: 70,
                    child: Text('${compassName(_a.facing ?? 180)} ${(_a.facing ?? 180).round()}°',
                        style: OgText.actName.copyWith(color: c.text))),
              ]),
            ],
          ] else ...[
            const OgSectionLabel('Route'),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48), foregroundColor: c.text, side: BorderSide(color: c.line)),
              onPressed: _gpx,
              icon: const Icon(Icons.route),
              label: Text(_a.track.isEmpty ? 'Choose a GPX file' : 'Replace the GPX file'),
            ),
            if (_a.track.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('${_a.distanceKm.toStringAsFixed(1)} km · ${_a.track.length} points',
                    style: OgText.chip.copyWith(color: c.text2)),
              ),
            const OgSectionLabel('When'),
            seg<String?>(
              [(null, 'Today'), (iso(now.add(const Duration(days: 1))), 'Tomorrow'), ('pick', _a.date != null && _a.date != iso(now.add(const Duration(days: 1))) ? _a.date!.substring(5) : 'Pick a day')],
              _a.date == null ? null : (_a.date == iso(now.add(const Duration(days: 1))) ? _a.date : 'pick'),
              (v) async {
                if (v != 'pick') return setState(() => _a.date = v);
                final d = await showDatePicker(
                    context: context, firstDate: now, lastDate: now.add(const Duration(days: 6)), initialDate: now.add(const Duration(days: 2)));
                if (d != null) setState(() => _a.date = iso(d));
              },
            ),
            const SizedBox(height: 10),
            Row(children: [
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(foregroundColor: c.text, side: BorderSide(color: c.line)),
                onPressed: () async {
                  final hm = _a.start.split(':');
                  final t = await showTimePicker(context: context, initialTime: TimeOfDay(hour: int.parse(hm[0]), minute: int.parse(hm[1])));
                  if (t != null) setState(() => _a.start = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}');
                },
                icon: const Icon(Icons.schedule, size: 18),
                label: Text('Start ${_a.start}'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _speed,
                  keyboardType: TextInputType.number,
                  style: OgText.body.copyWith(color: c.text),
                  decoration: deco('Speed km/h (optional)'),
                ),
              ),
            ]),
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('Without a speed, your profile’s pace is used; climbs add time.', style: OgText.chip.copyWith(color: c.text3)),
            ),
          ],
        ], right: [
          const OgSectionLabel('Name', top: 4),
          TextField(controller: _name, style: OgText.body.copyWith(color: c.text), decoration: deco('e.g. Sitges or Saturday ride')),
          const OgSectionLabel('Notifications and Today'),
          OgCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _a.notify,
                activeThumbColor: c.bg,
                activeTrackColor: c.r4,
                title: Text('Notify me', style: OgText.actName.copyWith(color: c.text)),
                subtitle: Text(_a.isRoute ? 'The day before and on the day, and if the rain picture changes' : 'When a window reaches the rating below',
                    style: OgText.chip.copyWith(color: c.text2)),
                onChanged: (v) => setState(() => _a.notify = v),
              ),
              if (!_a.isRoute) ...[
                Text('Good enough from', style: OgText.chip.copyWith(color: c.text2)),
                const SizedBox(height: 6),
                seg<int>([(3, 'Fair (3)'), (4, 'Good (4)'), (5, 'Epic (5)')], _a.minRating, (v) => setState(() => _a.minRating = v)),
                const SizedBox(height: 10),
                Text('Looking ahead', style: OgText.chip.copyWith(color: c.text2)),
                const SizedBox(height: 6),
                seg<int>([(0, 'Today'), (1, '+ tomorrow'), (2, '+ 2 days')], _a.daysAhead, (v) => setState(() => _a.daysAhead = v)),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _a.onlyWhenGood,
                  activeThumbColor: c.bg,
                  activeTrackColor: c.r4,
                  title: Text('On Today only when it’s good', style: OgText.actName.copyWith(color: c.text)),
                  onChanged: (v) => setState(() => _a.onlyWhenGood = v),
                ),
              ],
            ]),
          ),
          if (_msg != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(_msg!, style: OgText.chip.copyWith(color: c.warnRed))),
          const SizedBox(height: 16),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: c.text, foregroundColor: c.bg, minimumSize: const Size.fromHeight(50)),
            onPressed: _save,
            child: const Text('Save'),
          ),
          if (widget.id != null)
            TextButton(
              style: TextButton.styleFrom(foregroundColor: c.warnRed, minimumSize: const Size.fromHeight(48)),
              onPressed: () {
                app.removeActivity(_a.id);
                goBack(context, '/activities');
              },
              child: const Text('Remove this activity'),
            ),
        ]),
      ],
    );
  }
}
