import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../data/models.dart';
import '../../data/profile.dart';
import '../../theme/oratge_tokens.dart';
import 'basics.dart';
import 'sheets.dart';

/// Saved spots as quick picks (same coordinates as the backend's spot registry).
const savedPlaces = [
  Place(name: 'Castelldefels', region: 'Wing spot', lat: 41.265, lon: 1.975),
  Place(name: 'Ocata · El Masnou', region: 'Surf spot', lat: 41.477, lon: 2.338),
  Place(name: 'Collserola', region: 'Bike loop', lat: 41.418, lon: 2.118),
  Place(name: 'Pedraforca', region: 'Hike', lat: 42.239, lon: 1.703),
];

Future<void> showLocationSheet(BuildContext context) => showOgSheet(context, child: const _LocationPicker());

class _LocationPicker extends StatefulWidget {
  const _LocationPicker();
  @override
  State<_LocationPicker> createState() => _LocationPickerState();
}

class _LocationPickerState extends State<_LocationPicker> {
  final _q = TextEditingController();
  Timer? _debounce;
  List<Place> _results = const [];
  bool _searching = false;
  String? _locError;
  bool _locating = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _q.dispose();
    super.dispose();
  }

  void _search(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      if (q.trim().length < 2) {
        setState(() => _results = const []);
        return;
      }
      setState(() => _searching = true);
      final r = await AppScope.of(context).repository.places(q.trim());
      if (mounted) {
        setState(() {
          _results = r;
          _searching = false;
        });
      }
    });
  }

  Future<void> _useCurrent() async {
    setState(() {
      _locating = true;
      _locError = null;
    });
    try {
      if (!await Geolocator.isLocationServiceEnabled()) throw 'Location is switched off on this device.';
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        throw 'Oratge needs location permission for this. You can still search a place.';
      }
      final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.low, timeLimit: Duration(seconds: 12)));
      if (!mounted) return;
      final app = AppScope.of(context);
      if (pos.latitude < 40 || pos.latitude > 43.5 || pos.longitude < -0.5 || pos.longitude > 3.6) {
        throw 'You’re outside Catalonia; Oratge’s data covers Catalonia only.';
      }
      final place = await app.repository.reverse(pos.latitude, pos.longitude);
      app.setPlace(Place(name: place.name, lat: pos.latitude, lon: pos.longitude, current: true));
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _locError = '$e');
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _pick(Place? p) {
    AppScope.of(context).setPlace(p);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.og;
    final app = AppScope.of(context);
    final cur = app.place;
    Widget tile(IconData icon, String title, String sub, VoidCallback onTap, {bool selected = false, Widget? trailing}) =>
        ListTile(
          contentPadding: EdgeInsets.zero,
          minTileHeight: 56,
          leading: CircleAvatar(backgroundColor: c.surface2, child: Icon(icon, color: c.text, size: 20)),
          title: Text(title, style: OgText.actName.copyWith(color: c.text)),
          subtitle: sub.isEmpty ? null : Text(sub, style: OgText.chip.copyWith(color: c.text2)),
          trailing: trailing ?? (selected ? Icon(Icons.check, color: c.r4) : null),
          onTap: onTap,
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Location', style: OgText.verdictBest.copyWith(color: c.text)),
      const SizedBox(height: 12),
      TextField(
        controller: _q,
        autofocus: false,
        onChanged: _search,
        style: OgText.body.copyWith(color: c.text),
        decoration: InputDecoration(
          hintText: 'Search a town in Catalonia',
          hintStyle: OgText.body.copyWith(color: c.text3),
          prefixIcon: Icon(Icons.search, color: c.text2),
          suffixIcon: _searching ? Padding(padding: const EdgeInsets.all(14), child: SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2, color: c.text2))) : null,
          filled: true,
          fillColor: c.surface,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        ),
      ),
      const SizedBox(height: 8),
      for (final p in _results)
        tile(Icons.place_outlined, p.name, p.region, () => _pick(p), selected: cur?.name == p.name && cur?.current == false),
      if (_results.isEmpty) ...[
        tile(Icons.my_location, 'Current location', _locError ?? (cur?.current == true ? cur!.name : 'Uses your approximate position'),
            _locating ? () {} : _useCurrent,
            selected: cur?.current == true,
            trailing: _locating ? SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2, color: c.text2)) : null),
        tile(Icons.home_outlined, 'Home · ${app.profile['home']}', 'From your profile', () => _pick(null), selected: cur == null),
        const OgSectionLabel('Your spots'),
        for (final p in savedPlaces) tile(Icons.flag_outlined, p.name, p.region, () => _pick(p), selected: cur?.name == p.name),
      ],
    ]);
  }
}
