import 'package:flutter/material.dart';

import '../components/sheets.dart';

import 'package:go_router/go_router.dart';

import '../../data/profile.dart';
import '../../data/repository.dart';
import '../../theme/oratge_tokens.dart';
import '../motion.dart';

/// Breakpoints from the handoff: < 600 phone, 600–1023 tablet, ≥ 1024 desktop.
enum FormFactor { phone, tablet, desktop }

FormFactor formFactorOf(double width) =>
    width >= 1024 ? FormFactor.desktop : (width >= 600 ? FormFactor.tablet : FormFactor.phone);

/// Standard scrolling page: header (title, date line, optional back link, profile button) + content.
class OgPage extends StatelessWidget {
  const OgPage({
    super.key,
    required this.title,
    this.subtitle,
    this.back,
    required this.children,
    this.showProfile = true,
    this.headerExtra,
  });
  final Widget? headerExtra;
  final String title;
  final String? subtitle;
  final ({String label, String route})? back;
  final List<Widget> children;
  final bool showProfile;

  @override
  Widget build(BuildContext context) {
    final c = context.og;
    final ff = formFactorOf(MediaQuery.sizeOf(context).width);
    return LayoutBuilder(
      builder: (context, box) {
        final maxW = ff == FormFactor.phone ? box.maxWidth : (ff == FormFactor.tablet ? 760.0 : 1100.0);
        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxW),
            child: RefreshIndicator(
              // Pull down on any screen: fresh data from the server (and settings sync when it's on).
              onRefresh: () => AppScope.of(context).refreshAll(),
              color: c.text,
              backgroundColor: c.surface,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(OgSpace.s5, MediaQuery.paddingOf(context).top + 8, OgSpace.s5, 32),
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (back != null)
                              TextButton(
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: const Size(44, 44),
                                  alignment: Alignment.centerLeft,
                                ),
                                onPressed: () => goBack(context, back!.route),
                                child: Text(
                                  context.canPop() ? '‹ Back' : '‹ ${back!.label}',
                                  style: OgText.day.copyWith(color: c.text2, fontSize: 14),
                                ),
                              ),
                            Semantics(
                              header: true,
                              child: Text(
                                title,
                                style: OgText.verdictBest.copyWith(fontSize: back != null ? 24 : 28, color: c.text),
                              ),
                            ),
                            if (subtitle != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(subtitle!, style: OgText.day.copyWith(color: c.text2)),
                              ),
                            ?headerExtra,
                            const _DataBanner(),
                          ],
                        ),
                      ),
                      const Padding(padding: EdgeInsets.only(top: 6, right: 6), child: SyncPill()),
                      if (showProfile && ff == FormFactor.phone) const _ProfileButton(),
                    ],
                  ),
                  const SizedBox(height: 12),
                  for (final (i, child) in children.indexed) FadeSlideIn(index: i + 1, child: child),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ProfileButton extends StatelessWidget {
  const _ProfileButton();
  @override
  Widget build(BuildContext context) {
    final c = context.og;
    final name = '${AppScope.of(context).profile['name'] ?? '?'}';
    return Semantics(
      button: true,
      label: 'Profile and setup',
      excludeSemantics: true,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => context.push('/profile'),
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: CircleAvatar(
            radius: 20,
            backgroundColor: c.surface2,
            child: Text(name.isEmpty ? '?' : name[0].toUpperCase(), style: OgText.actWindow.copyWith(color: c.text)),
          ),
        ),
      ),
    );
  }
}

/// Loads data once and shows it; spinner while loading, message on error.
class AsyncView<T> extends StatefulWidget {
  const AsyncView({super.key, required this.load, required this.builder});
  final Future<T> Function() load;
  final Widget Function(BuildContext, T) builder;

  @override
  State<AsyncView<T>> createState() => _AsyncViewState<T>();
}

class _AsyncViewState<T> extends State<AsyncView<T>> {
  late Future<T> _f = widget.load();
  T? _last;
  DataStatus? _status;
  int _seen = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final st = AppScope.of(context).status;
    if (!identical(st, _status)) {
      _status?.removeListener(_onStatus);
      _status = st..addListener(_onStatus);
      _seen = st.version;
    }
  }

  void _onStatus() {
    // A background refresh landed: reload from the (now fresh) cache, keeping the old data on screen meanwhile.
    if (_status!.version != _seen && mounted) {
      _seen = _status!.version;
      setState(() => _f = widget.load());
    }
  }

  @override
  void dispose() {
    _status?.removeListener(_onStatus);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant AsyncView<T> old) {
    super.didUpdateWidget(old);
    if (old.load != widget.load) _f = widget.load();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.og;
    return FutureBuilder<T>(
      future: _f,
      builder: (context, snap) {
        if (snap.hasData) _last = snap.data;
        if (snap.hasError && _last == null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Couldn’t load the forecast.', style: OgText.actWindow.copyWith(color: c.text)),
                  const SizedBox(height: 6),
                  Text(
                    '${snap.error}',
                    style: OgText.src.copyWith(color: c.text2),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  FilledButton(onPressed: () => setState(() => _f = widget.load()), child: const Text('Try again')),
                ],
              ),
            ),
          );
        }
        final data = snap.data ?? _last;
        if (data == null) return Center(child: CircularProgressIndicator(color: c.text2));
        return widget.builder(context, data);
      },
    );
  }
}

/// Small line under the page title when the data isn't live.
class _DataBanner extends StatelessWidget {
  const _DataBanner();
  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context).status;
    final c = context.og;
    return ListenableBuilder(
      listenable: st,
      builder: (context, _) {
        if (st.source == DataSource.live) return const SizedBox.shrink();
        final at = st.savedAt;
        final text = st.source == DataSource.sample
            ? 'Offline · showing sample data (is Tailscale on?)'
            : 'Offline · showing saved forecast from ${at == null ? 'earlier' : '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}'}';
        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            children: [
              Icon(Icons.cloud_off_outlined, size: 16, color: c.text2),
              const SizedBox(width: 6),
              Expanded(
                child: Text(text, style: OgText.chip.copyWith(color: c.text2)),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Two columns on tablet/desktop, one column on phone.
class Columns extends StatelessWidget {
  const Columns({super.key, required this.left, required this.right});
  final List<Widget> left, right;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        if (box.maxWidth < 700) {
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [...left, ...right]);
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: left),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: right),
            ),
          ],
        );
      },
    );
  }
}

/// Back to the screen the user came from; [fallback] when there is none (opened directly or from a tab).
void goBack(BuildContext context, String fallback) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go(fallback);
  }
}

/// "↻ 14:32" in every page header: when data last came from the server. Tap for details and
/// "Refresh now"; it spins while refreshing and turns amber when the server can't be reached.
class SyncPill extends StatelessWidget {
  const SyncPill({super.key});

  static String ago(DateTime? t) {
    if (t == null) return 'never';
    final d = DateTime.now().difference(t);
    if (d.inSeconds < 60) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes} min ago';
    final hm = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    return d.inHours < 24 ? hm : '${t.day}/${t.month} $hm';
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final c = context.og;
    return ListenableBuilder(
      listenable: Listenable.merge([app.status, ?app.sync]),
      builder: (context, _) {
        final st = app.status;
        final offline = st.error != null || st.source != DataSource.live;
        final label = !app.hasServer
            ? 'Sample'
            : st.refreshing
            ? 'Updating…'
            : (st.lastLive == null ? (st.savedAt == null ? '—' : _hm(st.savedAt!)) : _hm(st.lastLive!));
        return Semantics(
          button: true,
          label: 'Data updated ${ago(st.lastLive ?? st.savedAt)}. Show sync details',
          excludeSemantics: true,
          child: Material(
            color: offline && app.hasServer ? c.sun.withValues(alpha: 0.18) : c.surface,
            borderRadius: BorderRadius.circular(999),
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: () => showOgSheet(context, child: const _SyncDetails()),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    st.refreshing
                        ? SizedBox.square(dimension: 14, child: CircularProgressIndicator(strokeWidth: 2, color: c.text2))
                        : Icon(offline && app.hasServer ? Icons.cloud_off_outlined : Icons.sync, size: 16, color: c.text2),
                    const SizedBox(width: 6),
                    Text(label, style: OgText.chip.copyWith(color: c.text2)),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  static String _hm(DateTime t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}

class _SyncDetails extends StatefulWidget {
  const _SyncDetails();
  @override
  State<_SyncDetails> createState() => _SyncDetailsState();
}

class _SyncDetailsState extends State<_SyncDetails> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final c = context.og;
    return ListenableBuilder(
      listenable: Listenable.merge([app.status, ?app.sync]),
      builder: (context, _) {
        final st = app.status;
        final sync = app.sync;
        Widget row(IconData icon, String title, String body, {Color? tint}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 20, color: tint ?? c.text2),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: OgText.actName.copyWith(color: c.text)),
                    Text(body, style: OgText.chip.copyWith(color: c.text2, fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
        );
        final data = !app.hasServer
            ? 'Sample data: no server is set (Profile → Sync and server).'
            : st.error != null
            ? '${st.error}. Showing data saved ${SyncPill.ago(st.savedAt ?? st.lastLive)}.'
            : st.lastLive != null
            ? 'Updated from the server ${SyncPill.ago(st.lastLive)}. Refreshes by itself when data is older than 10 minutes.'
            : (st.savedAt != null ? 'Showing data saved ${SyncPill.ago(st.savedAt)}; refreshing in the background.' : 'Loading…');
        final settings = !app.syncOn
            ? 'Off: settings stay on this device. Turn on in Profile → Sync and server.'
            : (sync?.error != null
                  ? sync!.error!
                  : 'Last synced ${SyncPill.ago(sync?.lastSync)}: profile, setup, places, activities and layouts.');
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Data and sync', style: OgText.verdictBest.copyWith(color: c.text)),
            const SizedBox(height: 8),
            row(Icons.cloud_download_outlined, 'Forecasts and readings', data, tint: st.error != null ? c.sun : null),
            row(Icons.sync, 'Settings sync', settings, tint: sync?.error != null ? c.sun : null),
            if (app.hasServer) row(Icons.dns_outlined, 'Server', app.serverUrl),
            row(
              Icons.notifications_none,
              'Notifications',
              'Checked hourly in the background on Android; on the Mac while Oratge is open.',
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: c.text,
                      foregroundColor: c.bg,
                      minimumSize: const Size.fromHeight(48),
                    ),
                    onPressed: _busy || !app.hasServer
                        ? null
                        : () async {
                            setState(() => _busy = true);
                            await app.refreshAll();
                            if (mounted) setState(() => _busy = false);
                          },
                    icon: _busy
                        ? SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2, color: c.bg))
                        : const Icon(Icons.refresh),
                    label: Text(_busy ? 'Refreshing…' : (app.syncOn ? 'Refresh and sync now' : 'Refresh now')),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
