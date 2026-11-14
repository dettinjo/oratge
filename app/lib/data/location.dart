import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:geolocator/geolocator.dart';

import 'models.dart';
import 'profile.dart';

/// Keeps "Current location" current: re-reads the position at launch and when the app returns to the
/// foreground; moving more than 2 km updates the place (name from reverse geocoding) and the weather.
class LocationFollower {
  LocationFollower(this.app);
  final AppState app;
  AppLifecycleListener? _life;
  bool _busy = false;

  void start() {
    _life ??= AppLifecycleListener(onResume: refresh);
    refresh();
  }

  Future<void> refresh() async {
    final cur = app.place;
    if (cur == null || !cur.current || _busy) return;
    _busy = true;
    try {
      final perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) return;
      if (!await Geolocator.isLocationServiceEnabled()) return;
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.low, timeLimit: Duration(seconds: 12)),
      );
      // Unnamed ("41.23, 1.82", when reverse geocoding failed earlier): try naming it again even without moving.
      final unnamed = RegExp(r'^-?\d+\.\d+, -?\d+\.\d+$').hasMatch(cur.name);
      if (!unnamed && Geolocator.distanceBetween(cur.lat, cur.lon, pos.latitude, pos.longitude) < 2000) return;
      if (pos.latitude < 40 || pos.latitude > 43.5 || pos.longitude < -0.5 || pos.longitude > 3.6) return;
      final named = await app.repository.reverse(pos.latitude, pos.longitude);
      // Still following? (the user may have picked another place meanwhile)
      if (app.place?.current == true) {
        app.setPlace(Place(name: named.name, lat: pos.latitude, lon: pos.longitude, current: true));
      }
    } catch (_) {
      // No fix right now: keep the last known place.
    } finally {
      _busy = false;
    }
  }

  void dispose() => _life?.dispose();
}
