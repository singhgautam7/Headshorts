import 'package:flutter/widgets.dart';
import 'package:headshorts/core/motion/motion_level.dart';
import 'package:headshorts/core/motion/spring_curve.dart';
import 'package:headshorts/core/tokens/motion.dart';

/// `sheetAnimationStyle:` for showModalBottomSheet at the current level.
///
/// Expressive: in on springSlow (clamped, so no overshoot gap shows), out on
/// springStandard (clamped). Subtle: springSubtle both ways. Off: 90 ms
/// (Flutter's sheet route slides, it cannot fade in place).
AnimationStyle sheetStyle(BuildContext context) => _style(
  HsMotion.levelOf(context),
  HsMotion.slowCurve,
  reverse: HsMotion.standardCurve,
);

AnimationStyle _style(
  MotionLevel level,
  SpringCurve spring, {
  SpringCurve? reverse,
}) {
  if (level == MotionLevel.off) {
    return const AnimationStyle(
      curve: Curves.linear,
      duration: HsMotion.fxInstant,
      reverseCurve: Curves.linear,
      reverseDuration: HsMotion.fxInstant,
    );
  }
  final inC = HsMotion.spatialCurve(level, spring);
  final outC = level == MotionLevel.subtle
      ? HsMotion.subtleCurve
      : (reverse ?? spring);
  return AnimationStyle(
    curve: inC.clamped,
    duration: inC.settle,
    reverseCurve: outC.clamped,
    reverseDuration: outC.settle,
  );
}
