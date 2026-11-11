import 'package:flutter/material.dart';

import 'app.dart';
import 'data/profile.dart';

/// Backend: --dart-define=ORATGE_API=https://… and ORATGE_TOKEN at build time, or set in the app
/// (Profile → Server). Without either, the bundled sample data is shown.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final state = await AppState.load();
  state.connect();
  runApp(OratgeApp(state: state));
}
