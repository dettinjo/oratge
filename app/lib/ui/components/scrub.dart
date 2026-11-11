import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../../theme/oratge_tokens.dart';
import '../motion.dart';

/// One value in a scrub readout ("Wind 18 kn"), with an optional accent dot.
class ReadoutItem {
  const ReadoutItem(this.label, this.value, {this.color});
  final String label, value;
  final Color? color;
}

/// Makes a chart interactive: touch and drag across it, a cursor follows the finger and the
/// values at that position appear above the chart. A light haptic tick marks each new step.
/// Tap the same spot again (or tap outside the plotted area) to clear.
class Scrub extends StatefulWidget {
  const Scrub({super.key, required this.count, required this.indexAt, required this.chart, required this.readout, this.hint});

  final int count;

  /// Maps a horizontal position (and chart width) to a data index, or null outside the plot.
  final int? Function(double dx, double width) indexAt;
  final Widget Function(int? selected) chart;

  /// Title (e.g. "14 h") and values for an index.
  final (String, List<ReadoutItem>) Function(int index, OratgeColors c) readout;

  /// Defaults to a touch or a mouse hint, depending on the device.
  final String? hint;

  @override
  State<Scrub> createState() => _ScrubState();
}

class _ScrubState extends State<Scrub> {
  int? _sel;
  double _width = 0;
  bool _hovering = false;

  // Desktop always has a pointer; elsewhere (web, tablets) ask whether a mouse has shown up.
  bool get _mouse =>
      const {TargetPlatform.macOS, TargetPlatform.windows, TargetPlatform.linux}.contains(defaultTargetPlatform) ||
      RendererBinding.instance.mouseTracker.mouseIsConnected;

  void _at(double dx, {bool toggle = false}) {
    final i = widget.indexAt(dx, _width);
    final next = (i == null || i < 0 || i >= widget.count) ? null : i;
    if (toggle && next == _sel) {
      setState(() => _sel = null);
      return;
    }
    if (next != _sel) {
      if (next != null && !_hovering) HapticFeedback.selectionClick();
      setState(() => _sel = next);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.og;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnimatedSize(
          duration: motion(context, 180),
          alignment: Alignment.topLeft,
          child: AnimatedSwitcher(
            duration: motion(context, 140),
            child: _sel == null
                ? Padding(
                    key: const ValueKey('hint'),
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Icon(_mouse ? Icons.mouse_outlined : Icons.swipe_outlined, size: 15, color: c.text3),
                        const SizedBox(width: 6),
                        Text(
                          widget.hint ?? (_mouse ? 'Point at the chart to read values' : 'Touch and drag the chart'),
                          style: OgText.chip.copyWith(color: c.text3),
                        ),
                      ],
                    ),
                  )
                : _Readout(key: ValueKey(_sel), data: widget.readout(_sel!, c)),
          ),
        ),
        LayoutBuilder(
          builder: (context, box) {
            _width = box.maxWidth;
            // Mouse (Mac, desktop web): the readout follows the pointer and clears when it leaves.
            return MouseRegion(
              onHover: (e) {
                _hovering = true;
                _at(e.localPosition.dx);
              },
              onExit: (_) {
                if (_hovering) setState(() => _sel = null);
                _hovering = false;
              },
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (d) => _at(d.localPosition.dx, toggle: !_hovering),
                onHorizontalDragStart: (d) => _at(d.localPosition.dx),
                onHorizontalDragUpdate: (d) => _at(d.localPosition.dx),
                onLongPressStart: (d) => _at(d.localPosition.dx),
                onLongPressMoveUpdate: (d) => _at(d.localPosition.dx),
                child: widget.chart(_sel),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _Readout extends StatelessWidget {
  const _Readout({super.key, required this.data});
  final (String, List<ReadoutItem>) data;

  @override
  Widget build(BuildContext context) {
    final c = context.og;
    final (title, items) = data;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Semantics(
        liveRegion: true,
        child: Wrap(
          spacing: 8,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(color: c.text, borderRadius: BorderRadius.circular(999)),
              child: Text(
                title,
                style: OgText.chip.copyWith(color: c.bg, fontWeight: FontWeight.w700),
              ),
            ),
            for (final it in items)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (it.color != null) ...[
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(color: it.color, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 5),
                  ],
                  Text('${it.label} ', style: OgText.chip.copyWith(color: c.text2)),
                  Text(
                    it.value,
                    style: OgText.chip.copyWith(color: c.text, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
