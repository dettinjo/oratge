import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'data/alerts.dart';
import 'data/profile.dart';
import 'theme/oratge_tokens.dart';
import 'ui/screens/activity_edit_screen.dart';
import 'ui/screens/browse_screens.dart';
import 'ui/screens/route_screen.dart';
import 'ui/screens/common.dart';
import 'ui/screens/planner_screen.dart';
import 'ui/screens/profile_screens.dart';
import 'ui/motion.dart';
import 'ui/screens/map_full.dart';
import 'ui/screens/notifications_screen.dart';
import 'ui/screens/today_screen.dart';
import 'ui/screens/wing_gear_screen.dart';

const _tabs = [
  (route: '/today', label: 'Today', icon: Icons.wb_sunny_outlined),
  (route: '/activities', label: 'Activities', icon: Icons.show_chart),
  (route: '/map', label: 'Map', icon: Icons.map_outlined),
  (route: '/spots', label: 'Spots', icon: Icons.place_outlined),
];

Page<void> _tab(GoRouterState s, Widget child) => CustomTransitionPage(
  key: s.pageKey,
  child: child,
  transitionDuration: const Duration(milliseconds: 220),
  transitionsBuilder: (context, a, _, child) => fadeThrough(a, child),
);

Page<void> _detail(GoRouterState s, Widget child) => CustomTransitionPage(
  key: s.pageKey,
  child: child,
  transitionDuration: const Duration(milliseconds: 300),
  reverseTransitionDuration: const Duration(milliseconds: 220),
  transitionsBuilder: (context, a, _, child) => slideUpFade(a, child),
);

GoRouter buildRouter() => GoRouter(
  initialLocation: '/today',
  routes: [
    ShellRoute(
      builder: (context, state, child) => AppShell(location: state.uri.path, child: child),
      routes: [
        GoRoute(path: '/today', pageBuilder: (c, s) => _tab(s, const TodayScreen())),
        GoRoute(
          path: '/activities',
          pageBuilder: (c, s) => _tab(s, const ActivitiesScreen()),
          routes: [
            // Before ':sport', which would match these single segments too.
            GoRoute(path: 'new', pageBuilder: (c, s) => _detail(s, const ActivityEditScreen())),
            GoRoute(path: 'edit/:id', pageBuilder: (c, s) => _detail(s, ActivityEditScreen(id: s.pathParameters['id']))),
            GoRoute(path: 'route/:id', pageBuilder: (c, s) => _detail(s, RouteScreen(id: s.pathParameters['id']!))),
            GoRoute(
              path: 'place/:id',
              pageBuilder: (c, s) {
                final a = AppScope.of(c).activity(s.pathParameters['id']!);
                return _detail(s, PlannerScreen(sport: a?.sport ?? 'wing', activityId: a?.id));
              },
            ),
            GoRoute(
              path: ':sport',
              pageBuilder: (c, s) => _detail(s, PlannerScreen(sport: s.pathParameters['sport']!)),
              routes: [
                GoRoute(
                  path: 'gear',
                  pageBuilder: (c, s) => _detail(
                    s,
                    WingGearScreen(
                      wind: double.tryParse(s.uri.queryParameters['wind'] ?? ''),
                      gust: double.tryParse(s.uri.queryParameters['gust'] ?? ''),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        GoRoute(path: '/map', pageBuilder: (c, s) => _tab(s, const MapScreen())),
        GoRoute(
          path: '/spots',
          pageBuilder: (c, s) => _tab(s, const SpotsScreen()),
          routes: [
            GoRoute(
              path: ':id',
              pageBuilder: (c, s) => _detail(s, SpotScreen(id: s.pathParameters['id']!)),
            ),
          ],
        ),
        GoRoute(
          path: '/profile',
          pageBuilder: (c, s) => _tab(s, const ProfileScreen()),
          routes: [GoRoute(path: 'notifications', pageBuilder: (c, s) => _detail(s, const NotificationsScreen()))],
        ),
      ],
    ),
    GoRoute(path: '/map/full', pageBuilder: (c, s) => _detail(s, const MapFullScreen())),
    GoRoute(
      path: '/setup/:step',
      builder: (c, s) => SetupScreen(step: int.tryParse(s.pathParameters['step'] ?? '1')?.clamp(1, 10) ?? 1),
    ),
  ],
);

class OratgeApp extends StatefulWidget {
  const OratgeApp({super.key, required this.state});
  final AppState state;
  @override
  State<OratgeApp> createState() => _OratgeAppState();
}

class _OratgeAppState extends State<OratgeApp> {
  late final GoRouter _router = buildRouter();

  @override
  void initState() {
    super.initState();
    AlertService.onOpen = (route) => _router.go(route); // tapping a notification opens its screen
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: widget.state,
      child: ListenableBuilder(
        listenable: widget.state,
        builder: (context, _) => MaterialApp.router(
          title: 'Oratge',
          debugShowCheckedModeBanner: false,
          theme: oratgeTheme(Brightness.light),
          darkTheme: oratgeTheme(Brightness.dark),
          themeMode: widget.state.themeMode,
          routerConfig: _router,
        ),
      ),
    );
  }
}

/// Phone: bottom navigation. Tablet: navigation rail. Desktop: sidebar with the appearance switch.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.location, required this.child});
  final String location;
  final Widget child;

  int get _index {
    final i = _tabs.indexWhere((t) => location.startsWith(t.route));
    return i < 0 ? -1 : i;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.og;
    final ff = formFactorOf(MediaQuery.sizeOf(context).width);
    final idx = _index;
    void go(int i) => context.go(_tabs[i].route);

    if (ff == FormFactor.phone) {
      return Scaffold(
        body: child,
        bottomNavigationBar: NavigationBarTheme(
          data: NavigationBarThemeData(
            backgroundColor: c.bg,
            indicatorColor: c.surface2,
            labelTextStyle: WidgetStateProperty.resolveWith(
              (s) => OgText.tab.copyWith(fontSize: 12, color: s.contains(WidgetState.selected) ? c.text : c.text2),
            ),
            iconTheme: WidgetStateProperty.resolveWith(
              (s) => IconThemeData(color: s.contains(WidgetState.selected) ? c.text : c.text2),
            ),
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: c.line)),
            ),
            child: NavigationBar(
              height: 72,
              selectedIndex: idx < 0 ? 0 : idx,
              onDestinationSelected: go,
              destinations: [for (final t in _tabs) NavigationDestination(icon: Icon(t.icon), label: t.label)],
            ),
          ),
        ),
      );
    }

    final profileSelected = location.startsWith('/profile');
    final railItems = [
      for (final t in _tabs) NavigationRailDestination(icon: Icon(t.icon), label: Text(t.label)),
      const NavigationRailDestination(icon: Icon(Icons.person_outline), label: Text('Profile')),
    ];
    return Scaffold(
      body: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              border: Border(right: BorderSide(color: c.line)),
            ),
            child: ff == FormFactor.desktop
                ? SizedBox(
                    width: 232,
                    child: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Oratge', style: OgText.verdictBest.copyWith(color: c.text)),
                            const SizedBox(height: 18),
                            for (final (i, t) in [
                              ..._tabs,
                              (route: '/profile', label: 'Profile', icon: Icons.person_outline),
                            ].indexed)
                              ListTile(
                                minTileHeight: 48,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                selected: i == idx || (i == 4 && profileSelected),
                                selectedTileColor: c.surface2,
                                leading: Icon(t.icon, color: c.text2),
                                title: Text(t.label, style: OgText.actName.copyWith(color: c.text)),
                                onTap: () => context.go(t.route),
                              ),
                            const Spacer(),
                            Text('APPEARANCE', style: OgText.label.copyWith(color: c.text2)),
                            const SizedBox(height: 8),
                            const AppearanceSwitch(),
                          ],
                        ),
                      ),
                    ),
                  )
                : NavigationRail(
                    backgroundColor: c.bg,
                    labelType: NavigationRailLabelType.all,
                    selectedIndex: profileSelected ? 4 : (idx < 0 ? null : idx),
                    indicatorColor: c.surface2,
                    selectedIconTheme: IconThemeData(color: c.text),
                    unselectedIconTheme: IconThemeData(color: c.text2),
                    selectedLabelTextStyle: OgText.tab.copyWith(fontSize: 12, color: c.text),
                    unselectedLabelTextStyle: OgText.tab.copyWith(fontSize: 12, color: c.text2),
                    onDestinationSelected: (i) => i == 4 ? context.go('/profile') : go(i),
                    destinations: railItems,
                  ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}
