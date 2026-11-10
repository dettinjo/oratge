import 'dart:io';

import 'package:flutter/services.dart';

Future<void> loadFonts() async {
  final dm = FontLoader('DMSans');
  for (final w in [300, 400, 500, 600, 700]) {
    dm.addFont(rootBundle.load('assets/fonts/DMSans-$w.ttf'));
  }
  await dm.load();
  // Material icons ship with the Flutter SDK.
  final flutterRoot = Platform.environment['FLUTTER_ROOT'] ?? '${Platform.environment['HOME']}/development/flutter';
  final icons = File('$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
  if (icons.existsSync()) {
    await (FontLoader('MaterialIcons')..addFont(Future.value(ByteData.sublistView(icons.readAsBytesSync())))).load();
  }
}

