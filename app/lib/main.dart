import 'package:flutter/material.dart';

import 'app.dart';
import 'data/alerts.dart';
import 'data/location.dart';
import 'data/profile.dart';

/// Backend: --dart-define=ORATGE_API=https://… and ORATGE_TOKEN at build time, or set in the app
/// (Profile → Server). Without either, the bundled sample data is shown.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final state = await AppState.load();
  state.connect();
  LocationFollower(state).start(); // only acts when Today is set to "Current location"
  runApp(OratgeApp(state: state));
  AlertService(state).start(); // notifications for good windows, warnings, plan changes, morning summary
}
