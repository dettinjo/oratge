import 'package:flutter/material.dart';

import 'app.dart';
import 'data/profile.dart';
import 'data/repository.dart';

/// Backend URL, set at build time: --dart-define=ORATGE_API=https://… (empty = bundled sample data).
const _api = String.fromEnvironment('ORATGE_API');
const _token = String.fromEnvironment('ORATGE_TOKEN');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final state = await AppState.load();
  if (_api.isNotEmpty) {
    final api = ApiRepository(_api,
        token: _token.isEmpty ? null : _token,
        fallback: SampleRepository(),
        profile: () => state.profile,
        prefs: state.prefs,
        status: state.status);
    state.repository = api;
    api.prefetch(); // warm every screen in parallel; navigation then reads from the cache
  }
  runApp(OratgeApp(state: state));
}
