import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:oratge/data/profile.dart';
import 'package:oratge/theme/oratge_tokens.dart';
import 'package:oratge/ui/screens/browse_screens.dart';
import 'package:oratge/ui/screens/planner_screen.dart';
import 'package:oratge/ui/screens/profile_screens.dart';
import 'package:oratge/ui/screens/today_screen.dart';

/// Renders one screen inside the app theme + state, with a router so links resolve.
Future<void> pumpScreen(WidgetTester tester, Widget screen, {Brightness brightness = Brightness.dark, Size size = const Size(390, 844)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final state = AppState(null);
  final router = GoRouter(routes: [GoRoute(path: '/', builder: (c, s) => Scaffold(body: screen))]);
  await tester.pumpWidget(AppScope(
    state: state,
    child: MaterialApp.router(theme: oratgeTheme(brightness), routerConfig: router),
  ));
  // Sample data comes from the asset bundle: let real async work finish, then settle.
  for (var i = 0; i < 40 && find.byType(CircularProgressIndicator).evaluate().isNotEmpty; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 25)));
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

Future<void> _loadFonts() async {
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

void main() {
  setUpAll(_loadFonts);
  final screens = <String, Widget Function()>{
    'today': () => const TodayScreen(),
    'activities': () => const ActivitiesScreen(),
    'map': () => const MapScreen(),
    'spots': () => const SpotsScreen(),
    'spot': () => const SpotScreen(id: 'castelldefels'),
    'profile': () => const ProfileScreen(),
    for (final s in ['wing', 'surf', 'bike', 'run', 'hike']) 'planner-$s': () => PlannerScreen(sport: s),
    for (var i = 1; i <= 10; i++) 'setup-$i': () => SetupScreen(step: i),
  };

  for (final size in const [Size(390, 844), Size(834, 1112), Size(1280, 900)]) {
    for (final b in Brightness.values) {
      for (final e in screens.entries) {
        testWidgets('${e.key} renders (${size.width.toInt()} px, ${b.name})', (tester) async {
          await pumpScreen(tester, e.value(), brightness: b, size: size);
          expect(tester.takeException(), isNull);
          expect(find.byType(CircularProgressIndicator), findsNothing);
        });
      }
    }
  }

  testWidgets('planner analysis expands', (tester) async {
    await pumpScreen(tester, const PlannerScreen(sport: 'wing'));
    final tile = find.text('How this forecast was made');
    await tester.ensureVisible(tile);
    await tester.pumpAndSettle();
    await tester.tap(tile);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.textContaining('Oratge blend'));
    expect(find.textContaining('Oratge blend'), findsOneWidget);
  });

  testWidgets('theme mode persists in state', (tester) async {
    final state = AppState(null);
    state.setThemeMode(ThemeMode.light);
    expect(state.themeMode, ThemeMode.light);
  });
}
