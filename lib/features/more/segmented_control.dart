import 'package:flutter/material.dart';
import 'package:headshorts/core/motion/animated_weight.dart';
import 'package:headshorts/core/motion/motion_level.dart';
import 'package:headshorts/core/motion/pressable.dart';
import 'package:headshorts/core/theme/hs_theme.dart';
import 'package:headshorts/core/tokens/dimensions.dart';
import 'package:headshorts/core/tokens/motion.dart';
import 'package:headshorts/core/tokens/palette.dart';
import 'package:headshorts/core/tokens/typography.dart';

/// Kuber's button group: separate items 8 dp apart. The one in effect is a
/// 12 dp squircle in the primary colours, the rest are pills on the variant
/// surface. Corner and fill ease on the fast spring; while a finger is down
/// the item widens by 15% and its neighbours give way (Expressive only).
///
/// Items are at least 40 dp tall inside a 48 dp target and grow, and wrap,
/// with the system text size.
class SegmentedControl<T> extends StatefulWidget {
  const new({
    required this.value,
    required this.options,
    required this.onChanged,
    super.key,
  });

  final T value;
  final Map<T, String> options;
  final ValueChanged<T> onChanged;

  @override
  State<SegmentedControl<T>> createState() => _SegmentedControlState<T>();
}

class _SegmentedControlState<T> extends State<SegmentedControl<T>> {
  int? _down;

  void _set(int? i) {
    if (_down != i) setState(() => _down = i);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.hs;
    final level = HsMotion.levelOf(context);
    final off = level == MotionLevel.off;
    final shape = HsMotion.spatialCurve(level, HsMotion.fastCurve);
    final widen = level == MotionLevel.expressive;
    final entries = widget.options.entries.toList();
    final n = entries.length;
    const grow = HsMotion.buttonGroupWiden;

    double weight(int i) {
      final d = _down;
      if (!widen || d == null || n < 2) return 1;
      return i == d ? 1 + grow : 1 - grow / (n - 1);
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < n; i++) ...[
            if (i > 0) const SizedBox(width: HsSpace.x2),
            TweenAnimationBuilder<double>(
              tween: Tween(end: weight(i)),
              duration: off ? Duration.zero : shape.settle,
              curve: shape.clamped,
              builder: (context, w, child) => Flexible(
                flex: (w * 1000).round().clamp(1, 4000),
                child: child!,
              ),
              child: _Item(
                label: entries[i].value,
                selected: entries[i].key == widget.value,
                off: off,
                palette: palette,
                onTap: () => widget.onChanged(entries[i].key),
                onDown: () => _set(i),
                onUp: () => _set(null),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Item extends StatelessWidget {
  const new({
    required this.label,
    required this.selected,
    required this.off,
    required this.palette,
    required this.onTap,
    required this.onDown,
    required this.onUp,
  });

  final String label;
  final bool selected;
  final bool off;
  final HsPalette palette;
  final VoidCallback onTap;
  final VoidCallback onDown;
  final VoidCallback onUp;

  @override
  Widget build(BuildContext context) {
    final sq = HsMotion.spatialCurve(
      HsMotion.levelOf(context),
      HsMotion.fastCurve,
    );
    return Semantics(
      inMutuallyExclusiveGroup: true,
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => onDown(),
        onPointerUp: (_) => onUp(),
        onPointerCancel: (_) => onUp(),
        child: Pressable(
          kind: PressKind.iconButton,
          morphCorners: false,
          haptic: true,
          onTap: onTap,
          selected: selected,
          semanticLabel: label,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: HsSize.tapTarget),
            child: Center(
              child: TweenAnimationBuilder<double>(
                tween: Tween(end: selected ? 1 : 0),
                duration: off ? Duration.zero : sq.settle,
                curve: sq.clamped,
                builder: (context, t, child) => TweenAnimationBuilder<Color?>(
                  tween: ColorTween(
                    end: selected ? palette.primary : palette.surfaceVariant,
                  ),
                  duration: off ? HsMotion.fxInstant : HsMotion.fxFast,
                  curve: HsMotion.curveEffects,
                  builder: (context, fill, child) => Material(
                    color: fill,
                    animationDuration: Duration.zero,
                    shape: t >= 1
                        ? const RoundedRectangleBorder(
                            borderRadius: BorderRadius.all(
                              Radius.circular(HsRadius.squircle),
                            ),
                          )
                        : ShapeBorder.lerp(
                            const StadiumBorder(),
                            const RoundedRectangleBorder(
                              borderRadius: BorderRadius.all(
                                Radius.circular(HsRadius.squircle),
                              ),
                            ),
                            t,
                          ),
                    clipBehavior: Clip.antiAlias,
                    child: child,
                  ),
                  child: child,
                ),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 40),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(
                    horizontal: HsSpace.x3,
                    vertical: HsSpace.x2,
                  ),
                  // Shrinks before it would break a word in two.
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: AnimatedWeight(
                      label,
                      isActive: selected,
                      active: 650,
                      textAlign: TextAlign.center,
                      style: HsType.chipSelected.copyWith(
                        color: palette.onPrimary,
                      ),
                      restColor: palette.textPrimary,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
