import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/alerts.dart';
import '../../data/notify_settings.dart';
import '../../data/profile.dart';
import '../../theme/oratge_tokens.dart';
import '../components/basics.dart';
import '../components/rows_cards.dart';
import 'common.dart';

/// Profile → Notifications: exactly which conditions, warnings and summaries may notify, and when.
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final c = context.og;
    final cfg = NotifySettings.fromJson(app.profile['notify']);
    void save() => app.setField('notify', cfg.toJson());

    Widget seg<T>(List<(T, String)> opts, T value, void Function(T) onChanged) => SegmentedButton<T>(
      showSelectedIcon: false,
      style: SegmentedButton.styleFrom(
        selectedBackgroundColor: c.text,
        selectedForegroundColor: c.bg,
        foregroundColor: c.text2,
        side: BorderSide(color: c.line),
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 8),
      ),
      segments: [for (final (v, l) in opts) ButtonSegment(value: v, label: Text(l))],
      selected: {value},
      onSelectionChanged: (s) => onChanged(s.first),
    );

    Widget toggle(String title, String? sub, bool value, void Function(bool) onChanged, {bool enabled = true}) => SwitchListTile(
      contentPadding: EdgeInsets.zero,
      value: value,
      onChanged: enabled ? onChanged : null,
      activeThumbColor: c.bg,
      activeTrackColor: c.r4,
      title: Text(title, style: OgText.actName.copyWith(color: c.text)),
      subtitle: sub == null ? null : Text(sub, style: OgText.chip.copyWith(color: c.text2)),
    );

    Widget labelled(String label, Widget child) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 6,
        children: [
          SizedBox(
            width: 92,
            child: Text(label, style: OgText.chip.copyWith(color: c.text2)),
          ),
          child,
        ],
      ),
    );

    final on = cfg.on;
    final log = [
      for (final s in (app.prefs?.getStringList('alerts:log') ?? const <String>[]).reversed)
        Map<String, dynamic>.from(jsonDecode(s) as Map),
    ];

    return OgPage(
      title: 'Notifications',
      subtitle: cfg.summary((s) => sportNames[s] ?? s, activities: [for (final a in app.activities) if (a.notify) a.name]),
      back: (label: 'Back to Profile', route: '/profile'),
      children: [
        OgCard(
          child: toggle('Notifications', 'Master switch for this and your other devices (synced)', on, (v) {
            cfg.on = v;
            save();
          }),
        ),
        Columns(
          left: [
            const OgSectionLabel('Your activities'),
            Text(
              'Spots notify when a window reaches the activity’s rating (once per day, again only if it improves); '
              'routes the evening before and if the rain picture changes.',
              style: OgText.chip.copyWith(color: c.text2, fontSize: 13),
            ),
            const SizedBox(height: 8),
            OgCard(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Column(
                children: [
                  for (final a in app.activities)
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: a.notify && on,
                      onChanged: on
                          ? (v) {
                              a.notify = v;
                              app.upsertActivity(a);
                            }
                          : null,
                      activeThumbColor: c.bg,
                      activeTrackColor: c.r4,
                      title: Text('${sportNames[a.sport]} · ${a.name}', style: OgText.actName.copyWith(color: c.text)),
                      subtitle: Text(
                        a.isRoute
                            ? 'Route · ${a.date ?? 'today'} ${a.start}'
                            : 'From ${a.minRating}/5 · ${a.daysAhead == 0 ? 'today' : (a.daysAhead == 1 ? 'today and tomorrow' : 'up to 2 days ahead')}',
                        style: OgText.chip.copyWith(color: c.text2),
                      ),
                      secondary: IconButton(
                        tooltip: 'Edit',
                        icon: Icon(Icons.edit_outlined, color: c.text3, size: 20),
                        onPressed: () => context.push('/activities/edit/${a.id}'),
                      ),
                    ),
                  TextButton.icon(
                    onPressed: () => context.push('/activities/new'),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add an activity'),
                  ),
                ],
              ),
            ),
            const OgSectionLabel('Official warnings'),
            OgCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Meteocat warnings for your places, from this level up. A warning repeats only if it escalates.',
                    style: OgText.chip.copyWith(color: c.text2, fontSize: 13),
                  ),
                  const SizedBox(height: 10),
                  seg<String>([('off', 'Off'), ('yellow', 'All'), ('orange', 'Severe'), ('red', 'Red only')], cfg.warnings, (v) {
                    cfg.warnings = v;
                    save();
                  }),
                ],
              ),
            ),
          ],
          right: [
            const OgSectionLabel('More'),
            OgCard(
              child: Column(
                children: [
                  toggle('Plan changes', 'A day’s rating moves by a full point (activities with notifications on)', cfg.changes, (v) {
                    cfg.changes = v;
                    save();
                  }, enabled: on),
                  toggle('Morning summary', 'Best sport and window of the day', cfg.morning, (v) {
                    cfg.morning = v;
                    save();
                  }, enabled: on),
                  if (cfg.morning && on)
                    labelled(
                      'At',
                      seg<int>([(6, '06:00'), (7, '07:00'), (8, '08:00'), (9, '09:00')], cfg.morningHour, (v) {
                        cfg.morningHour = v;
                        save();
                      }),
                    ),
                ],
              ),
            ),
            const OgSectionLabel('When'),
            OgCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  toggle('Quiet hours', 'Held until the quiet time ends', cfg.quiet, (v) {
                    cfg.quiet = v;
                    save();
                  }, enabled: on),
                  if (cfg.quiet && on) ...[
                    labelled(
                      'From',
                      seg<int>([(21, '21:00'), (22, '22:00'), (23, '23:00')], cfg.quietFrom, (v) {
                        cfg.quietFrom = v;
                        save();
                      }),
                    ),
                    labelled(
                      'Until',
                      seg<int>([(6, '06:00'), (7, '07:00'), (8, '08:00')], cfg.quietTo, (v) {
                        cfg.quietTo = v;
                        save();
                      }),
                    ),
                  ],
                  labelled(
                    'At most',
                    seg<int>([(1, '1'), (3, '3'), (5, '5'), (0, 'No limit')], cfg.maxPerDay, (v) {
                      cfg.maxPerDay = v;
                      save();
                    }),
                  ),
                  Text('per day', style: OgText.chip.copyWith(color: c.text3)),
                ],
              ),
            ),
            if (AlertService.supported) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  style: TextButton.styleFrom(foregroundColor: c.text, minimumSize: const Size(48, 44)),
                  onPressed: () async {
                    final ok = await AlertService.test();
                    if (!ok && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Notifications are off for Oratge. Turn them on in the system settings.')),
                      );
                    }
                  },
                  icon: const Icon(Icons.notifications_active_outlined, size: 18),
                  label: const Text('Send a test notification'),
                ),
              ),
            ],
            const OgSectionLabel('Recently sent'),
            if (log.isEmpty)
              Text('Nothing yet.', style: OgText.chip.copyWith(color: c.text2, fontSize: 13))
            else
              OgCard(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Column(
                  children: [
                    for (final (i, e) in log.take(15).indexed)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          border: i == 0 ? null : Border(top: BorderSide(color: c.line)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${e['title']}', style: OgText.actName.copyWith(color: c.text)),
                            Text(
                              '${_when('${e['t']}')} · ${e['body']}',
                              style: OgText.chip.copyWith(color: c.text2),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }

  static String _when(String iso) {
    final t = DateTime.tryParse(iso);
    if (t == null) return '';
    const wd = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${wd[t.weekday - 1]} ${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }
}
