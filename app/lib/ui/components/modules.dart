import 'package:flutter/material.dart';

import '../../data/profile.dart';
import '../../theme/oratge_tokens.dart';
import 'sheets.dart';

/// Size of a module on a customisable screen.
enum ModuleSize { minimal, detailed }

/// A building block of a customisable screen (Today, planners, spots).
class ModuleDef {
  const ModuleDef(
    this.id,
    this.title,
    this.icon, {
    this.sizes = const {ModuleSize.minimal, ModuleSize.detailed},
    this.defaultSize = ModuleSize.detailed,
    this.defaultOn = true,
    this.wide = false,
    this.hint,
  });
  final String id, title;
  final IconData icon;
  final Set<ModuleSize> sizes;
  final ModuleSize defaultSize;
  final bool defaultOn;

  /// Wide modules (lists, charts) span a row; tiles sit side by side.
  final bool wide;
  final String? hint;
}

class ModuleEntry {
  ModuleEntry(this.id, this.size, this.on);
  final String id;
  ModuleSize size;
  bool on;
  Map<String, dynamic> toJson() => {'id': id, 'size': size.name, 'on': on};
}

/// The user's order, sizes and visibility for one screen, kept in the profile (synced across devices).
class ScreenLayout {
  ScreenLayout(this.screen, this.defs, this.app);
  final String screen;
  final List<ModuleDef> defs;
  final AppState app;

  String get key => 'layout.$screen';

  List<ModuleEntry> entries() {
    final byId = {for (final d in defs) d.id: d};
    final out = <ModuleEntry>[];
    for (final raw in (app.profile[key] as List?) ?? const []) {
      final m = Map<String, dynamic>.from(raw as Map);
      final d = byId.remove(m['id']);
      if (d == null) continue; // a module this version no longer has
      final size = ModuleSize.values.firstWhere((s) => s.name == m['size'], orElse: () => d.defaultSize);
      out.add(ModuleEntry(d.id, d.sizes.contains(size) ? size : d.defaultSize, m['on'] != false));
    }
    // Modules added in a newer version join at their default place.
    for (final d in byId.values) {
      final at = defs.indexOf(d).clamp(0, out.length);
      out.insert(at, ModuleEntry(d.id, d.defaultSize, d.defaultOn));
    }
    return out;
  }

  void save(List<ModuleEntry> e) => app.setField(key, [for (final x in e) x.toJson()]);
  void reset() => app.setField(key, null);
  ModuleDef def(String id) => defs.firstWhere((d) => d.id == id);
}

/// Lays modules out in rows: tiles side by side (2 per row on phones, 4 on wide windows),
/// wide modules across the row (2 tiles wide on wide windows).
class ModuleGrid extends StatelessWidget {
  const ModuleGrid({super.key, required this.layout, required this.builder});
  final ScreenLayout layout;

  /// Returns null when the module has nothing to show right now (e.g. no warnings).
  final Widget? Function(BuildContext context, ModuleDef def, ModuleSize size) builder;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final cols = box.maxWidth >= 880 ? 4 : (box.maxWidth >= 560 ? 3 : 2);
        int span(ModuleDef d, ModuleSize s) {
          if (d.wide) return cols == 4 ? (s == ModuleSize.detailed && d.id == 'hourly' ? 4 : 2) : cols;
          return s == ModuleSize.detailed ? (cols == 4 ? 2 : cols) : 1;
        }

        final rows = <List<(int, Widget)>>[];
        var cur = <(int, Widget)>[];
        var used = 0;
        for (final e in layout.entries()) {
          if (!e.on) continue;
          final d = layout.def(e.id);
          final w = builder(context, d, e.size);
          if (w == null) continue;
          final sp = span(d, e.size);
          if (used + sp > cols) {
            rows.add(cur);
            cur = [];
            used = 0;
          }
          cur.add((sp, KeyedSubtree(key: ValueKey(e.id), child: w)));
          used += sp;
        }
        if (cur.isNotEmpty) rows.add(cur);
        return Column(
          children: [
            for (final r in rows)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final (i, (sp, w)) in r.indexed) ...[if (i > 0) const SizedBox(width: 12), Expanded(flex: sp, child: w)],
                    if (r.fold<int>(0, (a, x) => a + x.$1) < cols) ...[
                      const SizedBox(width: 12),
                      Spacer(flex: cols - r.fold<int>(0, (a, x) => a + x.$1)),
                    ],
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

/// "Customise" button for a screen header or footer.
class CustomiseButton extends StatelessWidget {
  const CustomiseButton({super.key, required this.layout, this.label = 'Customise', this.compact = false});
  final ScreenLayout layout;
  final String label;

  /// Icon only (headers on phones).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = context.og;
    if (compact) {
      return IconButton(
        tooltip: label,
        style: IconButton.styleFrom(backgroundColor: c.surface),
        onPressed: () => showOgSheet(context, initialSize: 0.85, child: LayoutEditor(layout: layout)),
        icon: Icon(Icons.tune, color: c.text, size: 20),
      );
    }
    return TextButton.icon(
      style: TextButton.styleFrom(foregroundColor: c.text2, minimumSize: const Size(48, 44)),
      onPressed: () => showOgSheet(context, initialSize: 0.85, child: LayoutEditor(layout: layout)),
      icon: const Icon(Icons.tune, size: 18),
      label: Text(label),
    );
  }
}

/// Reorder (drag the handle), show or hide, and pick minimal or detailed per module. Changes apply at once.
class LayoutEditor extends StatefulWidget {
  const LayoutEditor({super.key, required this.layout});
  final ScreenLayout layout;
  @override
  State<LayoutEditor> createState() => _LayoutEditorState();
}

class _LayoutEditorState extends State<LayoutEditor> {
  late List<ModuleEntry> _e = widget.layout.entries();

  void _save() {
    widget.layout.save(_e);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final c = context.og;
    final l = widget.layout;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Customise', style: OgText.verdictBest.copyWith(color: c.text)),
        const SizedBox(height: 4),
        Text(
          'Drag to reorder. Detailed modules show charts and more numbers; minimal ones show the current value — tap any module for its full forecast.',
          style: OgText.chip.copyWith(color: c.text2),
        ),
        const SizedBox(height: 12),
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          itemCount: _e.length,
          onReorderItem: (a, b) {
            final x = _e.removeAt(a);
            _e.insert(b, x);
            _save();
          },
          itemBuilder: (context, i) {
            final e = _e[i];
            final d = l.def(e.id);
            final narrow = MediaQuery.sizeOf(context).width < 560;
            final sizes = d.sizes.length > 1 && e.on
                ? SegmentedButton<ModuleSize>(
                    showSelectedIcon: false,
                    style: SegmentedButton.styleFrom(
                      selectedBackgroundColor: c.text,
                      selectedForegroundColor: c.bg,
                      foregroundColor: c.text2,
                      side: BorderSide(color: c.line),
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    segments: const [
                      ButtonSegment(value: ModuleSize.minimal, label: Text('Minimal')),
                      ButtonSegment(value: ModuleSize.detailed, label: Text('Detailed')),
                    ],
                    selected: {e.size},
                    onSelectionChanged: (s) {
                      e.size = s.first;
                      _save();
                    },
                  )
                : null;
            return Container(
              key: ValueKey(e.id),
              decoration: BoxDecoration(
                color: c.bg,
                border: Border(bottom: BorderSide(color: c.line)),
              ),
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  ReorderableDragStartListener(
                    index: i,
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Icon(Icons.drag_indicator, color: c.text3, semanticLabel: 'Drag to reorder'),
                    ),
                  ),
                  Icon(d.icon, size: 20, color: e.on ? c.text : c.text3),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(d.title, style: OgText.actName.copyWith(color: e.on ? c.text : c.text3)),
                        if (d.hint != null && !narrow) Text(d.hint!, style: OgText.chip.copyWith(color: c.text3)),
                        // Phones: the size choice goes under the title so names stay readable.
                        if (narrow && sizes != null) Padding(padding: const EdgeInsets.only(top: 6), child: sizes),
                      ],
                    ),
                  ),
                  if (!narrow && sizes != null) sizes,
                  Switch(
                    value: e.on,
                    activeThumbColor: c.bg,
                    activeTrackColor: c.r4,
                    onChanged: (v) {
                      e.on = v;
                      _save();
                    },
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            style: TextButton.styleFrom(foregroundColor: c.text2),
            onPressed: () {
              l.reset();
              setState(() => _e = l.entries());
            },
            child: const Text('Reset to default'),
          ),
        ),
      ],
    );
  }
}

/// A Today-style tile: label, big value, a line underneath, optionally a small chart (detailed).
class ValueTile extends StatelessWidget {
  const ValueTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.sub,
    this.color,
    this.chart,
    this.extra,
    this.onTap,
    this.minHeight = 132,
  });
  final IconData icon;
  final String label, value;
  final String? sub, extra;
  final Color? color;
  final Widget? chart;
  final VoidCallback? onTap;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    final c = context.og;
    return Semantics(
      button: onTap != null,
      label: '$label $value ${sub ?? ''}',
      excludeSemantics: true,
      child: Material(
        color: c.surface,
        borderRadius: BorderRadius.circular(OgRadius.card),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: minHeight),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(icon, size: 15, color: c.text2),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          label.toUpperCase(),
                          style: OgText.label.copyWith(color: c.text2),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (onTap != null) Icon(Icons.chevron_right, size: 16, color: c.text3),
                    ],
                  ),
                  const SizedBox(height: 8),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(value, style: OgText.verdictBest.copyWith(color: color ?? c.text, fontSize: 30, height: 1.1)),
                  ),
                  if (sub != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      sub!,
                      style: OgText.chip.copyWith(color: c.text2),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (chart != null) ...[const SizedBox(height: 10), SizedBox(height: 48, child: chart)],
                  if (extra != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      extra!,
                      style: OgText.chip.copyWith(color: c.text),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Tiny line or bar chart for detailed tiles (no axes; the full chart is one tap away).
class Sparkline extends StatelessWidget {
  const Sparkline(this.values, {super.key, required this.color, this.bars = false, this.nowIndex, this.min, this.max});
  final List<double?> values;
  final Color color;
  final bool bars;
  final int? nowIndex;
  final double? min, max;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.infinite, painter: _SparkPainter(values, color, bars, nowIndex, min, max, context.og.text2));
}

class _SparkPainter extends CustomPainter {
  _SparkPainter(this.v, this.color, this.bars, this.now, this.lo, this.hi, this.mark);
  final List<double?> v;
  final Color color, mark;
  final bool bars;
  final int? now;
  final double? lo, hi;

  @override
  void paint(Canvas canvas, Size size) {
    final xs = [
      for (final x in v)
        ?x,
    ];
    if (xs.isEmpty) return;
    final a = lo ?? xs.reduce((p, q) => p < q ? p : q), b = hi ?? xs.reduce((p, q) => p > q ? p : q);
    final span = (b - a).abs() < 1e-6 ? 1.0 : b - a;
    final n = v.length;
    double x(int i) => (i + 0.5) / n * size.width;
    double y(double val) => size.height - 2 - ((val - a) / span).clamp(0.0, 1.0) * (size.height - 4);
    if (bars) {
      final bw = size.width / n * 0.7;
      for (var i = 0; i < n; i++) {
        final val = v[i];
        if (val == null || val <= a) continue;
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTRB(x(i) - bw / 2, y(val), x(i) + bw / 2, size.height), const Radius.circular(1.5)),
          Paint()..color = color.withValues(alpha: 0.8),
        );
      }
    } else {
      final p = Path();
      var started = false;
      for (var i = 0; i < n; i++) {
        final val = v[i];
        if (val == null) continue;
        started ? p.lineTo(x(i), y(val)) : p.moveTo(x(i), y(val));
        started = true;
      }
      canvas.drawPath(
        p,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeJoin = StrokeJoin.round,
      );
    }
    if (now != null && now! >= 0 && now! < n) {
      canvas.drawLine(Offset(x(now!), 0), Offset(x(now!), size.height), Paint()..color = mark.withValues(alpha: 0.5));
    }
  }

  @override
  bool shouldRepaint(_SparkPainter o) => o.v != v || o.color != color;
}
