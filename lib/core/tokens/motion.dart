import 'package:flutter/widgets.dart';

/// The one motion set. Perch's M3 Expressive execution: 150–260ms, a spring
/// for anything the finger caused, a decelerate for anything the system did.
///
/// Every duration here fires only from a gesture or a tap. Nothing animates on
/// its own; nothing loops.
abstract final class HsMotion {
  /// Anything the finger caused: the active tab label, a card settling.
  static const spring = Curves.easeOutBack;

  /// Anything the system caused: a page arriving, the pill hiding.
  static const decelerate = Curves.easeOutCubic;

  /// Toggles, chip selection, press states.
  static const micro = Duration(milliseconds: 150);
  static const microCurve = decelerate;

  /// Active tab label growing into its pill.
  static const navMorph = Duration(milliseconds: 220);
  static const navMorphCurve = spring;

  /// The pill sliding out of the way on scroll, and back.
  static const navHide = Duration(milliseconds: 160);

  /// Tab switches, push to Reader and Stats — and the pop back.
  static const page = Duration(milliseconds: 240);
  static const pageCurve = decelerate;

  /// Category sub-tab underline and content cross-fade.
  static const tabSlide = Duration(milliseconds: 230);
  static const tabSlideCurve = decelerate;

  /// A Linger card settling after a deliberate vertical swipe.
  static const lingerSettle = Duration(milliseconds: 260);
  static const lingerSettleCurve = spring;

  /// Under OS reduced motion: transforms become short cross-fades, springs go
  /// linear.
  static const reducedFade = Duration(milliseconds: 90);

  static bool reduced(BuildContext context) {
    final mq = MediaQuery.of(context);
    return mq.disableAnimations || mq.accessibleNavigation;
  }

  /// Duration to actually use, honouring reduced motion.
  static Duration of(BuildContext context, Duration full) =>
      reduced(context) ? reducedFade : full;

  static Curve curveOf(BuildContext context, Curve full) =>
      reduced(context) ? Curves.linear : full;
}
