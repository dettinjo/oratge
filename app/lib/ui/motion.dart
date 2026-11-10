import 'package:flutter/material.dart';

/// True when the user asked the OS for less motion: every animation here becomes instant.
bool reduceMotion(BuildContext context) => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

Duration motion(BuildContext context, int ms) => reduceMotion(context) ? Duration.zero : Duration(milliseconds: ms);

/// Fades and lifts a child into place; `index` staggers siblings (capped so long pages don't lag).
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({super.key, required this.child, this.index = 0, this.offset = 14});
  final Widget child;
  final int index;
  final double offset;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
  late final Animation<double> _a = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_c.status == AnimationStatus.dismissed) {
      if (reduceMotion(context)) {
        _c.value = 1;
      } else {
        Future.delayed(Duration(milliseconds: 40 * widget.index.clamp(0, 8)), () {
          if (mounted) _c.forward();
        });
      }
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _a,
        builder: (context, child) => Opacity(
          opacity: _a.value,
          child: Transform.translate(offset: Offset(0, widget.offset * (1 - _a.value)), child: child),
        ),
        child: widget.child,
      );
}

/// Reveals a chart left to right once (0 → 1), then stays drawn.
class Reveal extends StatelessWidget {
  const Reveal({super.key, required this.child, this.radial = false});
  final Widget child;

  /// Round charts (compass, swell window) fade and scale instead of wiping.
  final bool radial;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: motion(context, radial ? 500 : 800),
      curve: Curves.easeOutCubic,
      child: child,
      builder: (context, t, child) => radial
          ? Opacity(opacity: t, child: Transform.scale(scale: 0.92 + 0.08 * t, child: child))
          : ClipRect(clipper: _RevealClipper(t), child: child),
    );
  }
}

class _RevealClipper extends CustomClipper<Rect> {
  _RevealClipper(this.t);
  final double t;
  @override
  Rect getClip(Size size) => Rect.fromLTWH(0, 0, size.width * t, size.height);
  @override
  bool shouldReclip(_RevealClipper old) => old.t != t;
}

/// Counts a number up to its value (hero temperature).
class CountUp extends StatelessWidget {
  const CountUp({super.key, required this.value, required this.style, this.suffix = ''});
  final num value;
  final TextStyle style;
  final String suffix;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: value - 6.0, end: value.toDouble()),
        duration: motion(context, 700),
        curve: Curves.easeOutCubic,
        builder: (context, v, _) => Text('${v.round()}$suffix', style: style),
      );
}

/// Page transitions: tabs cross-fade, detail pages slide up slightly and fade.
Widget fadeThrough(Animation<double> a, Widget child) =>
    FadeTransition(opacity: CurvedAnimation(parent: a, curve: Curves.easeOut), child: child);

Widget slideUpFade(Animation<double> a, Widget child) {
  final c = CurvedAnimation(parent: a, curve: Curves.easeOutCubic);
  return FadeTransition(
    opacity: c,
    child: SlideTransition(position: Tween(begin: const Offset(0, 0.04), end: Offset.zero).animate(c), child: child),
  );
}
