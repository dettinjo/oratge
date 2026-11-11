import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/profile.dart';
import '../../data/sync.dart';
import '../../theme/oratge_tokens.dart';
import '../components/basics.dart';
import '../components/rows_cards.dart';
import 'common.dart';

/// Light / Dark / System switch (persisted).
class AppearanceSwitch extends StatelessWidget {
  const AppearanceSwitch({super.key});
  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final c = context.og;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SegmentedButton<ThemeMode>(
        showSelectedIcon: false,
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor: c.text,
          selectedForegroundColor: c.bg,
          foregroundColor: c.text2,
          side: BorderSide(color: c.line),
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: 8), // fits the 200 px desktop sidebar
        ),
        segments: const [
          ButtonSegment(value: ThemeMode.light, label: Text('Light')),
          ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
          ButtonSegment(value: ThemeMode.system, label: Text('System')),
        ],
        selected: {app.themeMode},
        onSelectionChanged: (s) => app.setThemeMode(s.first),
      ),
      const SizedBox(height: 6),
      Text('System follows your device’s light or dark setting.', style: OgText.src.copyWith(color: c.text2)),
    ]);
  }
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final c = context.og;
    final done = app.doneSteps.length;
    final name = '${app.profile['name']}';
    Widget row(String stepId, String title) {
      final isDone = app.doneSteps.contains(stepId);
      return InkWell(
        onTap: () => context.go('/setup/${setupSteps.indexWhere((s) => s.id == stepId) + 1}'),
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.line))),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: OgText.actName.copyWith(color: c.text)),
                Text(isDone ? app.summary(stepId) : 'Not set up yet', style: OgText.chip.copyWith(color: c.text2)),
              ]),
            ),
            Text(isDone ? '✓' : 'Add details', style: OgText.chip.copyWith(color: isDone ? c.text : c.text2)),
            const SizedBox(width: 10),
            Text('›', style: OgText.actWindow.copyWith(color: c.text2)),
          ]),
        ),
      );
    }

    return OgPage(title: 'Profile', subtitle: '${app.profile['home']}', showProfile: false, children: [
      OgCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            CircleAvatar(
                radius: 22,
                backgroundColor: c.surface2,
                child: Text(name.isEmpty ? '?' : name[0], style: OgText.actWindow.copyWith(color: c.text))),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: OgText.actWindow.copyWith(color: c.text)),
              Text('${app.profile['home']} · ${app.profile['windUnit']} · ${app.profile['tempUnit']}',
                  style: OgText.chip.copyWith(color: c.text2)),
            ]),
          ]),
          const SizedBox(height: 14),
          Row(children: [
            Text('Setup $done of ${setupSteps.length + 1} done', style: OgText.day.copyWith(color: c.text)),
            const Spacer(),
            Text('${(done / (setupSteps.length + 1) * 100).round()} %', style: OgText.day.copyWith(color: c.text2)),
          ]),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
                value: done / (setupSteps.length + 1), minHeight: 6, backgroundColor: c.surface2, color: c.r4),
          ),
        ]),
      ),
      Columns(left: [
        const OgSectionLabel('You'),
        row('you', 'Personal and units'),
        row('body', 'Body and pace'),
        const OgSectionLabel('Appearance'),
        const AppearanceSwitch(),
      ], right: [
        const OgSectionLabel('Sports and gear'),
        for (final s in ['wing', 'surf', 'bike', 'run', 'hike']) row(s, sportNames[s]!),
        row('sports', 'Add or remove sports'),
        const OgSectionLabel('App'),
        row('alerts', 'Alerts and privacy'),
        const OgSectionLabel('Sync and server'),
        const SyncCard(),
      ]),
    ]);
  }
}

/// One step of the 10-step setup flow (Back / Continue / Skip, progress).
class SetupScreen extends StatelessWidget {
  const SetupScreen({super.key, required this.step});
  final int step; // 1-based

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final c = context.og;
    final total = setupSteps.length + 1;
    final isDone = step > setupSteps.length;
    final def = isDone ? null : setupSteps[step - 1];
    void next() {
      if (def != null) app.markDone(def.id);
      context.go(step >= total ? '/today' : '/setup/${step + 1}');
    }

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 32), children: [
              Row(children: [
                TextButton(
                  style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(44, 44)),
                  onPressed: () => context.go(step == 1 ? '/profile' : '/setup/${step - 1}'),
                  child: Text(step == 1 ? '‹ Profile' : '‹ Back', style: OgText.day.copyWith(color: c.text2, fontSize: 14)),
                ),
                const Spacer(),
                Text('Step $step of $total', style: OgText.chip.copyWith(color: c.text2)),
                const Spacer(),
                IconButton(
                    tooltip: 'Close setup', onPressed: () => context.go('/profile'), icon: Icon(Icons.close, color: c.text2)),
              ]),
              Semantics(
                label: 'Setup progress',
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(value: step / total, minHeight: 6, backgroundColor: c.surface2, color: c.r4),
                ),
              ),
              const SizedBox(height: 18),
              Text((isDone ? 'Done' : def!.kicker).toUpperCase(), style: OgText.label.copyWith(color: c.text2)),
              const SizedBox(height: 4),
              Text(isDone ? 'You’re all set' : def!.title, style: OgText.verdictBest.copyWith(fontSize: 26, color: c.text)),
              const SizedBox(height: 4),
              Text(isDone ? 'Change anything later in Profile.' : def!.intro, style: OgText.verdictSummary.copyWith(color: c.text2)),
              const SizedBox(height: 8),
              if (isDone) ..._doneSummary(context, app) else ...[
                for (final g in def!.groups) ...[
                  if (g.title.isNotEmpty) OgSectionLabel(g.title),
                  OgCard(child: Column(children: [for (final f in g.fields) _Field(f)])),
                ],
                if (def.changes != null) ...[
                  const OgSectionLabel('What this changes'),
                  Text(def.changes!, style: OgText.verdictSummary.copyWith(color: c.text2)),
                ],
              ],
              const SizedBox(height: 24),
              FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor: c.text,
                    foregroundColor: c.bg,
                    minimumSize: const Size.fromHeight(50),
                    textStyle: OgText.actWindow),
                onPressed: next,
                child: Text(isDone ? 'Start using Oratge' : 'Continue'),
              ),
              if (!isDone && step > 1)
                TextButton(
                  style: TextButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                  onPressed: () => context.go('/setup/${step + 1}'),
                  child: Text('Skip this step', style: OgText.day.copyWith(color: c.text2)),
                ),
            ]),
          ),
        ),
      ),
    );
  }

  List<Widget> _doneSummary(BuildContext context, AppState app) {
    final c = context.og;
    return [
      const SizedBox(height: 8),
      Text('✓ Ratings, ranges and advice now use your setup.', style: OgText.day.copyWith(color: c.text)),
      const OgSectionLabel('Your setup'),
      OgCard(
        child: Column(children: [
          for (final (i, s) in setupSteps.indexed)
            Container(
              constraints: const BoxConstraints(minHeight: 52),
              decoration: BoxDecoration(border: i == setupSteps.length - 1 ? null : Border(bottom: BorderSide(color: c.line))),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                    Text(s.kicker, style: OgText.actName.copyWith(color: c.text)),
                    Text(app.summary(s.id), style: OgText.chip.copyWith(color: c.text2)),
                  ]),
                ),
                TextButton(onPressed: () => context.go('/setup/${i + 1}'), child: Text('Edit', style: OgText.day.copyWith(color: c.text))),
              ]),
            ),
        ]),
      ),
    ];
  }
}

class _Field extends StatelessWidget {
  const _Field(this.f);
  final FieldDef f;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final c = context.og;
    final v = app.profile[f.key];
    Widget labelCol() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(f.label + (f.optional ? ' · optional' : ''), style: OgText.actName.copyWith(color: c.text)),
          if (f.hint != null) Text(f.hint!, style: OgText.chip.copyWith(color: c.text2)),
        ]);
    Widget input(String key, {double width = 90}) => SizedBox(
          width: width,
          child: TextFormField(
            initialValue: '${app.profile[key] ?? ''}',
            textAlign: TextAlign.right,
            keyboardType: f.kind == FieldKind.text ? TextInputType.text : const TextInputType.numberWithOptions(decimal: true),
            style: OgText.body.copyWith(color: c.text),
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: c.surface2,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
            ),
            onChanged: (s) => app.setField(key, s),
          ),
        );

    final pad = const EdgeInsets.symmetric(vertical: 8);
    switch (f.kind) {
      case FieldKind.text:
      case FieldKind.number:
        return Padding(
          padding: pad,
          child: Row(children: [
            Expanded(child: labelCol()),
            input(f.key, width: f.kind == FieldKind.text ? 170 : 90),
            if (f.unit != null) SizedBox(width: 44, child: Text('  ${f.unit}', style: OgText.chip.copyWith(color: c.text2))),
          ]),
        );
      case FieldKind.range:
        return Padding(
          padding: pad,
          child: Row(children: [
            Expanded(child: labelCol()),
            input(f.key, width: 64),
            Text(' – ', style: OgText.body.copyWith(color: c.text2)),
            input(f.toKey!, width: 64),
            if (f.unit != null) SizedBox(width: 36, child: Text('  ${f.unit}', style: OgText.chip.copyWith(color: c.text2))),
          ]),
        );
      case FieldKind.toggle:
        return SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(f.label, style: OgText.actName.copyWith(color: c.text)),
          subtitle: f.hint == null ? null : Text(f.hint!, style: OgText.chip.copyWith(color: c.text2)),
          value: v == true,
          activeThumbColor: c.bg,
          activeTrackColor: c.r4,
          onChanged: (b) => app.setField(f.key, b),
        );
      case FieldKind.choice:
      case FieldKind.multi:
        final multi = f.kind == FieldKind.multi;
        final selected = multi ? {for (final s in (v as List? ?? const [])) '$s'} : {'$v'};
        return Padding(
          padding: pad,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (f.key != 'sports') ...[labelCol(), const SizedBox(height: 8)],
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final o in f.options)
                FilterChip(
                  label: Text(f.key == 'sports' ? sportNames[o]! : o),
                  selected: selected.contains(o),
                  showCheckmark: multi,
                  checkmarkColor: c.bg,
                  selectedColor: c.text,
                  backgroundColor: c.surface2,
                  labelStyle: OgText.chip.copyWith(
                      fontSize: 14, color: selected.contains(o) ? c.bg : c.text, fontWeight: FontWeight.w500),
                  side: BorderSide.none,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                  materialTapTargetSize: MaterialTapTargetSize.padded,
                  onSelected: (on) {
                    if (multi) {
                      final next = {...selected};
                      on ? next.add(o) : next.remove(o);
                      app.setField(f.key, [for (final x in f.options) if (next.contains(x)) x]);
                    } else {
                      app.setField(f.key, o);
                    }
                  },
                ),
            ]),
          ]),
        );
    }
  }
}


/// Server address and token, the sync switch and its status.
class SyncCard extends StatelessWidget {
  const SyncCard({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final c = context.og;
    final sync = app.sync;
    return ListenableBuilder(
      listenable: sync ?? ValueNotifier(0),
      builder: (context, _) {
        String status;
        if (!app.hasServer) {
          status = 'Add your server to sync.';
        } else if (!app.syncOn) {
          status = 'Off: your details stay on this device.';
        } else if (sync == null || (sync.busy && sync.lastSync == null)) {
          status = 'Syncing…';
        } else if (sync.error != null) {
          status = sync.error!;
        } else {
          final t = sync.lastSync!;
          status = 'Synced at ${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')} · profile, setup and places';
        }
        return OgCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.dns_outlined, color: c.text2, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Server', style: OgText.actName.copyWith(color: c.text)),
                  Text(app.hasServer ? app.serverUrl : 'Not set: sample data',
                      style: OgText.chip.copyWith(color: c.text2), overflow: TextOverflow.ellipsis),
                ]),
              ),
              TextButton(
                style: TextButton.styleFrom(minimumSize: const Size(48, 44), foregroundColor: c.text),
                onPressed: () => showDialog(context: context, builder: (_) => AppScope(state: app, child: const _ServerDialog())),
                child: const Text('Change'),
              ),
            ]),
            Divider(color: c.line, height: 20),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: app.syncOn,
              onChanged: app.hasServer ? (v) => app.setField('sync', v) : null,
              activeThumbColor: c.bg,
              activeTrackColor: c.r4,
              title: Text('Sync between my devices', style: OgText.actName.copyWith(color: c.text)),
              subtitle: Text(status,
                  style: OgText.chip.copyWith(color: sync?.error != null && app.syncOn ? c.warnRed : c.text2)),
            ),
            if (app.syncOn && sync != null)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  style: TextButton.styleFrom(minimumSize: const Size(48, 44), foregroundColor: c.text),
                  onPressed: sync.busy ? null : sync.syncNow,
                  icon: sync.busy
                      ? SizedBox.square(dimension: 14, child: CircularProgressIndicator(strokeWidth: 2, color: c.text2))
                      : const Icon(Icons.sync, size: 18),
                  label: const Text('Sync now'),
                ),
              ),
          ]),
        );
      },
    );
  }
}

class _ServerDialog extends StatefulWidget {
  const _ServerDialog();
  @override
  State<_ServerDialog> createState() => _ServerDialogState();
}

class _ServerDialogState extends State<_ServerDialog> {
  late final _url = TextEditingController(text: AppScope.of(context).serverUrl);
  late final _token = TextEditingController(text: AppScope.of(context).serverToken);
  String? _msg;
  bool _ok = false, _testing = false, _hide = true;

  @override
  void dispose() {
    _url.dispose();
    _token.dispose();
    super.dispose();
  }

  Future<void> _test() async {
    setState(() => _testing = true);
    final url = _url.text.trim().replaceAll(RegExp(r'/+$'), '');
    final err = url.isEmpty ? 'Enter the server address.' : await testServer(url, _token.text.trim());
    if (!mounted) return;
    setState(() {
      _testing = false;
      _ok = err == null;
      _msg = err ?? 'Connected.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.og;
    final app = AppScope.of(context);
    InputDecoration deco(String label, {Widget? suffix}) => InputDecoration(
          labelText: label,
          labelStyle: OgText.chip.copyWith(color: c.text2),
          suffixIcon: suffix,
          filled: true,
          fillColor: c.surface,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        );
    return AlertDialog(
      backgroundColor: c.bg,
      title: Text('Oratge server', style: OgText.verdictBest.copyWith(color: c.text, fontSize: 20)),
      content: SizedBox(
        width: 380,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Forecasts and sync come from here. Leave the address empty to use the built-in setting.',
              style: OgText.chip.copyWith(color: c.text2)),
          const SizedBox(height: 14),
          TextField(
            controller: _url,
            keyboardType: TextInputType.url,
            autocorrect: false,
            style: OgText.body.copyWith(color: c.text),
            decoration: deco('Address, e.g. http://100.96.0.121:8199'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _token,
            obscureText: _hide,
            autocorrect: false,
            style: OgText.body.copyWith(color: c.text),
            decoration: deco('Access token',
                suffix: IconButton(
                  tooltip: _hide ? 'Show token' : 'Hide token',
                  icon: Icon(_hide ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: c.text2),
                  onPressed: () => setState(() => _hide = !_hide),
                )),
          ),
          if (_msg != null) ...[
            const SizedBox(height: 10),
            Text(_msg!, style: OgText.chip.copyWith(color: _ok ? c.r4 : c.warnRed)),
          ],
        ]),
      ),
      actions: [
        TextButton(
          style: TextButton.styleFrom(foregroundColor: c.text2),
          onPressed: _testing ? null : _test,
          child: Text(_testing ? 'Testing…' : 'Test'),
        ),
        TextButton(
            style: TextButton.styleFrom(foregroundColor: c.text2),
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: c.text, foregroundColor: c.bg),
          onPressed: () {
            app.setServer(_url.text, _token.text);
            Navigator.of(context).pop();
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
