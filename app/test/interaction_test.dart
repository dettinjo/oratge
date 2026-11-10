import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:oratge/data/profile.dart';
import 'package:oratge/theme/oratge_tokens.dart';
import 'package:oratge/ui/charts/charts.dart';
import 'package:oratge/ui/screens/planner_screen.dart';
import 'package:oratge/ui/screens/today_screen.dart';

import 'helpers.dart';

Future<void> pump(WidgetTester tester, Widget screen) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = GoRouter(routes: [GoRoute(path: '/', builder: (c, s) => Scaffold(body: screen))]);
  await tester.pumpWidget(AppScope(state: AppState(null), child: MaterialApp.router(theme: oratgeTheme(Brightness.dark), routerConfig: router)));
  for (var i = 0; i < 40 && find.byType(CircularProgressIndicator).evaluate().isNotEmpty; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 25)));
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadFonts);

  testWidgets('dragging the hour chart shows a readout for that hour', (tester) async {
    await pump(tester, const PlannerScreen(sport: 'wing'));
    final chart = find.byType(OgHourChart).first;
    await tester.ensureVisible(chart);
    await tester.pumpAndSettle();
    expect(find.text('Touch and drag the chart'), findsWidgets);
    final box = tester.getRect(chart);
    await tester.dragFrom(Offset(box.left + 120, box.center.dy), const Offset(60, 0));
    await tester.pumpAndSettle();
    expect(find.textContaining(RegExp(r'^\d\d h$')), findsWidgets);
    expect(find.text('rating '), findsWidgets);
  });

  testWidgets('tapping a key number opens its detail sheet with the curve', (tester) async {
    await pump(tester, const PlannerScreen(sport: 'wing'));
    await tester.tap(find.text('GUSTS').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('strongest short burst'), findsOneWidget);
    expect(find.text('Through the day'.toUpperCase()), findsOneWidget);
  });

  testWidgets('tapping the verdict explains the rating', (tester) async {
    await pump(tester, const PlannerScreen(sport: 'wing'));
    await tester.tap(find.textContaining('Best 13–17 h'));
    await tester.pumpAndSettle();
    expect(find.textContaining('comes together'.toUpperCase()), findsOneWidget);
  });

  testWidgets('location chip opens the picker and search filters places', (tester) async {
    await pump(tester, const TodayScreen());
    await tester.tap(find.byTooltip('Change location').evaluate().isEmpty
        ? find.bySemanticsLabel(RegExp('Change location'))
        : find.byTooltip('Change location'));
    await tester.pumpAndSettle();
    expect(find.text('Current location'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Sit');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();
    expect(find.text('Sitges'), findsOneWidget);
    await tester.tap(find.text('Sitges'));
    await tester.pumpAndSettle();
  });
}
