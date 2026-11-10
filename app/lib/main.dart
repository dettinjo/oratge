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
    state.repository = ApiRepository(_api, token: _token.isEmpty ? null : _token, fallback: SampleRepository());
  }
  runApp(OratgeApp(state: state));
}
