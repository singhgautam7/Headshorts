import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';

/// A [Curve] that plays a real spring simulation, so a token written as
/// "spring · damping .78, stiffness 380" animates as a spring rather than as
/// an eased approximation of one.
@immutable
class SpringCurve extends Curve {
  new({required double damping, required double stiffness})
    : _simulation = SpringSimulation(
        SpringDescription.withDampingRatio(
          mass: 1,
          stiffness: stiffness,
          ratio: damping,
        ),
        0,
        1,
        0,
      );

  final SpringSimulation _simulation;

  @override
  double transformInternal(double t) =>
      _simulation.x(t) + t * _simulation.dx(t);
}

/// Every duration here fires only from a gesture or a tap. Nothing animates on
/// its own; nothing loops.
abstract final class HsMotion {
  /// Active tab label growing into its pill.
  static const navMorph = Duration(milliseconds: 420);
  static final navMorphCurve = SpringCurve(damping: 0.78, stiffness: 380);

  /// Tab switches, push to Reader and Stats.
  static const page = Duration(milliseconds: 300);
  static const pageCurve = Cubic(0.2, 0, 0, 1);

  /// A Linger card settling after a deliberate vertical swipe.
  static const lingerSettle = Duration(milliseconds: 380);
  static final lingerSettleCurve = SpringCurve(damping: 0.9, stiffness: 260);

  /// Category sub-tab underline and content cross-fade.
  static const tabSlide = Duration(milliseconds: 240);
  static const tabSlideCurve = Cubic(0.4, 0, 0.2, 1);

  /// Toggles, chip selection, press states.
  static const micro = Duration(milliseconds: 140);
  static const microCurve = Cubic(0.2, 0, 0, 1);

  /// Pull-to-refresh release and return.
  static const refresh = Duration(milliseconds: 520);
  static final refreshCurve = SpringCurve(damping: 0.85, stiffness: 300);
}
