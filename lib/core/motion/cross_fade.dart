import 'package:flutter/material.dart';
import 'package:headshorts/core/motion/motion_level.dart';
import 'package:headshorts/core/tokens/motion.dart';

/// Skeleton (or loader) to content cross-fade: fx.default on curve.effects
/// (Off: 90 ms). With [shrinkOut] the outgoing [placeholder] also shrinks to
/// .8 and fades in fx.instant, which is the loader's exit (Expressive only).
/// Never blocks input: the placeholder ignores pointers once it is leaving.
///
/// [child] is only built once [loading] is false, so it can read data that
/// is not there yet. Its state survives the end of the fade.
class SkeletonCrossFade extends StatefulWidget {
  const new({
    required this.loading,
    required this.placeholder,
    required this.child,
    super.key,
    this.shrinkOut = false,
  });

  final bool loading;
  final Widget placeholder;
  final Widget child;
  final bool shrinkOut;

  @override
  State<SkeletonCrossFade> createState() => _SkeletonCrossFadeState();
}

class _SkeletonCrossFadeState extends State<SkeletonCrossFade>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    value: widget.loading ? 0 : 1,
  )..addStatusListener((_) => setState(() {}));

  @override
  void didUpdateWidget(SkeletonCrossFade old) {
    super.didUpdateWidget(old);
    if (old.loading == widget.loading) return;
    final off = HsMotion.levelOf(context) == MotionLevel.off;
    _c.animateTo(
      widget.loading ? 0 : 1,
      duration: off ? HsMotion.fxInstant : HsMotion.fxDefault,
      curve: HsMotion.curveEffects,
    );
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shrink =
        widget.shrinkOut && HsMotion.levelOf(context) == MotionLevel.expressive;
    final showChild = !widget.loading || _c.value > 0;
    final showHolder = widget.loading || _c.value < 1;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value;
        // The loader leaves faster than the content arrives.
        final out = shrink
            ? (1 -
                      t *
                          (HsMotion.fxDefault.inMilliseconds /
                              HsMotion.fxInstant.inMilliseconds))
                  .clamp(0.0, 1.0)
            : 1 - t;
        return Stack(
          alignment: Alignment.topCenter,
          children: [
            if (showHolder)
              KeyedSubtree(
                key: const ValueKey('placeholder'),
                child: IgnorePointer(
                  ignoring: !widget.loading,
                  child: Opacity(
                    opacity: out,
                    child: shrink
                        ? Transform.scale(
                            scale: .8 + .2 * out,
                            child: widget.placeholder,
                          )
                        : widget.placeholder,
                  ),
                ),
              ),
            if (showChild)
              KeyedSubtree(
                key: const ValueKey('content'),
                child: Opacity(opacity: t, child: widget.child),
              ),
          ],
        );
      },
    );
  }
}
