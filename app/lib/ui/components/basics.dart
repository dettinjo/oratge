import 'package:flutter/material.dart';

import '../../theme/og_helpers.dart';
import '../../theme/oratge_tokens.dart';

/// Rounded surface (20 px radius, no shadow).
class OgCard extends StatelessWidget {
  const OgCard({super.key, required this.child, this.raised = false, this.tight = false, this.padding});
  final Widget child;
  final bool raised;
  final bool tight;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    final c = context.og;
    // A Material (not a decorated box) so ListTiles and ink splashes inside the card stay visible.
    return Material(
      color: raised ? c.surface2 : c.surface,
      borderRadius: BorderRadius.circular(OgRadius.card),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: padding ?? EdgeInsets.all(tight ? OgSpace.s3 : OgSpace.s4),
        child: SizedBox(width: double.infinity, child: child),
      ),
    );
  }
}

/// Small uppercase section heading.
class OgSectionLabel extends StatelessWidget {
  const OgSectionLabel(this.text, {super.key, this.top = 22});
  final String text;
  final double top;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(top: top, bottom: 8),
        child: Semantics(
          header: true,
          child: Text(text.toUpperCase(), style: OgText.label.copyWith(color: context.og.text2)),
        ),
      );
}

/// Single key fact. `large` = the one strip of key numbers per screen (36 px).
class OgFactTile extends StatelessWidget {
  const OgFactTile({super.key, required this.label, required this.value, this.sub, this.accent, this.large = false});
  final String label;
  final String value;
  final String? sub;
  final OgAccent? accent;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final c = context.og;
    final valueStyle = (large ? OgText.factValueLg : OgText.factValue)
        .copyWith(color: accent != null ? c.accent(accent!) : c.text);
    return Container(
      padding: EdgeInsets.all(large ? 14 : 12),
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: OgText.label.copyWith(color: c.text2), maxLines: 1, overflow: TextOverflow.ellipsis),
          SizedBox(height: large ? 8 : 6),
          FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(value, style: valueStyle)),
          if (sub != null && sub!.isNotEmpty) ...[
            SizedBox(height: large ? 4 : 2),
            Text(sub!, style: OgText.chip.copyWith(color: c.text2, fontSize: large ? 13 : 12)),
          ],
        ],
      ),
    );
  }
}

/// Grid of fact tiles, 2 or 4 per row (4 collapses to 2 on narrow widths).
class OgFactGrid extends StatelessWidget {
  const OgFactGrid({super.key, required this.children, this.columns = 2});
  final List<Widget> children;
  final int columns;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      var cols = columns;
      if (cols > 2 && box.maxWidth < 360) cols = 2;
      const gap = 10.0;
      final w = (box.maxWidth - gap * (cols - 1)) / cols;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [for (final ch in children) SizedBox(width: w, child: ch)],
      );
    });
  }
}

/// Five dots on the rating ramp: count + colour carry the rating.
class OgRatingDots extends StatelessWidget {
  const OgRatingDots({super.key, required this.value, this.large = false, this.showWord = false});
  final num value;
  final bool large;
  final bool showWord;

  @override
  Widget build(BuildContext context) {
    final c = context.og;
    final v = value.round().clamp(0, 5);
    final d = large ? 12.0 : 8.0;
    return Semantics(
      label: 'rating $v of 5',
      excludeSemantics: true,
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        for (var i = 0; i < 5; i++)
          Container(
            width: d,
            height: d,
            margin: const EdgeInsets.only(right: 4),
            decoration: BoxDecoration(shape: BoxShape.circle, color: i < v ? c.ratingColor(v) : c.r0),
          ),
        if (showWord)
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              v > 0 ? ratingWords[v - 1] : 'Not possible',
              style: OgText.day.copyWith(
                  fontWeight: FontWeight.w600, color: v >= 3 ? c.ratingColor(v) : (v == 0 ? c.text3 : c.text2)),
            ),
          ),
      ]),
    );
  }
}

/// Compact bar of rating cells, e.g. one per hour.
class OgRatingStrip extends StatelessWidget {
  const OgRatingStrip({super.key, required this.values, this.caption, this.height = 8});
  final List<num> values;
  final List<String>? caption;
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = context.og;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        for (var i = 0; i < values.length; i++)
          Expanded(
            child: Container(
              height: height,
              margin: EdgeInsets.only(right: i == values.length - 1 ? 0 : 3),
              decoration: BoxDecoration(
                  color: values[i] > 0 ? c.ratingColor(values[i]) : c.r0, borderRadius: BorderRadius.circular(2)),
            ),
          ),
      ]),
      if (caption != null && caption!.length == 3)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            for (final t in caption!) Text(t, style: OgText.src.copyWith(color: c.text3)),
          ]),
        ),
    ]);
  }
}

/// Single-select pill chips. Touch targets ≥ 44 px tall.
class OgChipGroup extends StatelessWidget {
  const OgChipGroup({super.key, required this.options, required this.selected, this.label, this.onSelect});
  final List<String> options;
  final String selected;
  final String? label;
  final ValueChanged<String>? onSelect;

  @override
  Widget build(BuildContext context) {
    final c = context.og;
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 6,
      children: [
        if (label != null)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Text(label!.toUpperCase(), style: OgText.label.copyWith(color: c.text2)),
          ),
        for (final o in options)
          Semantics(
            button: true,
            selected: o == selected,
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: onSelect == null ? null : () => onSelect!(o),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                child: Center(
                  widthFactor: 1,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                        color: o == selected ? c.text : c.surface, borderRadius: BorderRadius.circular(999)),
                    child: Text(o,
                        style: OgText.chip.copyWith(
                            color: o == selected ? c.bg : c.text2,
                            fontWeight: o == selected ? FontWeight.w600 : FontWeight.w400)),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Data attribution footnote — required at the end of every planner.
class OgDataSources extends StatelessWidget {
  const OgDataSources(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.og;
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.only(top: 10),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: c.line))),
      width: double.infinity,
      child: Text('Data: $text', style: OgText.src.copyWith(color: c.text2)),
    );
  }
}

/// Small rounded outline pill, e.g. "High confidence".
class OgPill extends StatelessWidget {
  const OgPill(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.og;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(border: Border.all(color: c.line), borderRadius: BorderRadius.circular(999)),
      child: Text(text, style: OgText.chip.copyWith(color: c.text2)),
    );
  }
}
