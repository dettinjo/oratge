import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/activities.dart';
import '../../data/models.dart';
import '../../data/profile.dart';
import '../../theme/oratge_tokens.dart';
import '../components/basics.dart';
import '../components/rows_cards.dart';

/// Today: the user's activities, but only what matters — spots when a window reaches their rating,
/// routes planned in the coming week. Nothing to show → the module disappears.
class ActivitiesModule extends StatefulWidget {
  const ActivitiesModule({super.key, this.minimal = false});
  final bool minimal;
  @override
  State<ActivitiesModule> createState() => _ActivitiesModuleState();
}

class _Item {
  _Item(this.a, this.title, this.sub, this.rating, this.route);
  final Activity a;
  final String title, sub, route;
  final num rating;
}

class _ActivitiesModuleState extends State<ActivitiesModule> {
  Future<List<_Item>>? _f;
  String _sig = '';

  Future<List<_Item>> _load(AppState app) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final acts = app.activities;
    final spots = acts.where((a) => !a.isRoute && a.lat != null).toList();
    final checks = {for (final r in await app.repository.checkActivities(spots).catchError((_) => <Json>[])) r['id']: r};
    final out = <_Item>[];
    for (final a in acts) {
      if (a.isRoute) {
        final start = a.startAt(now);
        final days = DateTime(start.year, start.month, start.day).difference(today).inDays;
        if (days < 0 || days > 6 || (days == 0 && start.add(const Duration(hours: 1)).isBefore(now))) continue;
        try {
          final r = await app.repository.route(a);
          final sum = r['summary'] as Map;
          final when = days == 0
              ? 'Today'
              : (days == 1 ? 'Tomorrow' : const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][start.weekday - 1]);
          out.add(
            _Item(
              a,
              '${sportNames[a.sport]} · ${a.name}',
              '$when ${a.start} · ${app.units.convert('${(sum['lines'] as List).first}')}',
              (sum['rating'] as num?) ?? 0,
              '/activities/route/${a.id}',
            ),
          );
        } catch (_) {
          // Server unreachable or route outside the forecast range: leave it out rather than guess.
        }
        continue;
      }
      final c = checks[a.id];
      if (c == null) continue;
      final days = [for (final d in (c['days'] as List? ?? const []).take(a.daysAhead + 1)) Map<String, dynamic>.from(d as Map)];
      final good = days.where((d) => (d['rating'] as num) >= a.minRating).toList();
      final route = a.builtin != null ? '/activities/${a.sport}' : '/activities/place/${a.id}';
      if (good.isNotEmpty) {
        final d = good.first;
        out.add(
          _Item(
            a,
            '${sportNames[a.sport]} · ${a.name}',
            '${d['day']} ${d['window']} · ${app.units.convert('${d['reason']}')}${good.length > 1 ? ' · also ${good.skip(1).map((x) => x['day']).join(', ')}' : ''}',
            d['rating'] as num,
            route,
          ),
        );
      } else if (!a.onlyWhenGood) {
        out.add(
          _Item(
            a,
            '${sportNames[a.sport]} · ${a.name}',
            'No ${a.minRating}+ window ${a.daysAhead == 0 ? 'today' : 'in the next ${a.daysAhead + 1} days'}',
            days.isEmpty ? 0 : days.map((d) => d['rating'] as num).reduce((x, y) => x > y ? x : y),
            route,
          ),
        );
      }
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final c = context.og;
    // Reload when the activities or the data version change.
    final sig = '${app.profile['activities']}|${app.status.version}';
    if (_f == null || sig != _sig) {
      _sig = sig;
      _f = _load(app);
    }
    return FutureBuilder<List<_Item>>(
      future: _f,
      builder: (context, snap) {
        final items = snap.data;
        if (app.activities.isEmpty) {
          return OgCard(
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Add a spot or a GPX route to see here when it’s worth going.',
                    style: OgText.chip.copyWith(color: c.text2, fontSize: 13),
                  ),
                ),
                TextButton(onPressed: () => context.push('/activities/new'), child: const Text('Add')),
              ],
            ),
          );
        }
        if (items == null || items.isEmpty) return const SizedBox.shrink();
        return OgCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Column(
            children: [
              for (final (i, it) in items.indexed)
                InkWell(
                  onTap: () => context.push(it.route),
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 60),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      border: i == 0 ? null : Border(top: BorderSide(color: c.line)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(it.title, style: OgText.actName.copyWith(color: c.text)),
                              if (!widget.minimal)
                                Text(
                                  it.sub,
                                  style: OgText.chip.copyWith(color: c.text2),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        OgRatingDots(value: it.rating),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
