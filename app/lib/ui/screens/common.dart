import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/profile.dart';
import '../../data/repository.dart';
import '../../theme/oratge_tokens.dart';

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
  });
  final String title;
  final String? subtitle;
  final ({String label, String route})? back;
  final List<Widget> children;
  final bool showProfile;

  @override
  Widget build(BuildContext context) {
    final c = context.og;
    final ff = formFactorOf(MediaQuery.sizeOf(context).width);
    return LayoutBuilder(builder: (context, box) {
      final maxW = ff == FormFactor.phone ? box.maxWidth : (ff == FormFactor.tablet ? 760.0 : 1100.0);
      return Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxW),
          child: ListView(
            padding: EdgeInsets.fromLTRB(OgSpace.s5, MediaQuery.paddingOf(context).top + 8, OgSpace.s5, 32),
            children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    if (back != null)
                      TextButton(
                        style: TextButton.styleFrom(
                            padding: EdgeInsets.zero, minimumSize: const Size(44, 44), alignment: Alignment.centerLeft),
                        onPressed: () => context.go(back!.route),
                        child: Text('‹ ${back!.label}', style: OgText.day.copyWith(color: c.text2, fontSize: 14)),
                      ),
                    Semantics(
                      header: true,
                      child: Text(title,
                          style: OgText.verdictBest.copyWith(fontSize: back != null ? 24 : 28, color: c.text)),
                    ),
                    if (subtitle != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(subtitle!, style: OgText.day.copyWith(color: c.text2)),
                      ),
                    const _DataBanner(),
                  ]),
                ),
                if (showProfile && ff == FormFactor.phone) const _ProfileButton(),
              ]),
              const SizedBox(height: 12),
              ...children,
            ],
          ),
        ),
      );
    });
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
        onTap: () => context.go('/profile'),
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: CircleAvatar(
            radius: 20,
            backgroundColor: c.surface2,
            child: Text(name.isEmpty ? '?' : name[0].toUpperCase(),
                style: OgText.actWindow.copyWith(color: c.text)),
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
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text('Couldn’t load the forecast.', style: OgText.actWindow.copyWith(color: c.text)),
                const SizedBox(height: 6),
                Text('${snap.error}', style: OgText.src.copyWith(color: c.text2), textAlign: TextAlign.center),
                const SizedBox(height: 12),
                FilledButton(onPressed: () => setState(() => _f = widget.load()), child: const Text('Try again')),
              ]),
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
          child: Row(children: [
            Icon(Icons.cloud_off_outlined, size: 16, color: c.text2),
            const SizedBox(width: 6),
            Expanded(child: Text(text, style: OgText.chip.copyWith(color: c.text2))),
          ]),
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
    return LayoutBuilder(builder: (context, box) {
      if (box.maxWidth < 700) {
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [...left, ...right]);
      }
      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: left)),
        const SizedBox(width: 24),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: right)),
      ]);
    });
  }
}
