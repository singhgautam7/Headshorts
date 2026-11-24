import 'package:flutter/widgets.dart';
import 'package:headshorts/core/motion/motion_level.dart';
import 'package:headshorts/core/motion/spring_curve.dart';

/// The one motion set: Kuber's springs for anything that moves under the
/// finger (press, shape, sheets, menus, lists), and the page and nav timings
/// the shell runs on.
///
/// Everything here fires from a gesture or a tap. Nothing loops.
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
  static const navHide = Duration(milliseconds: 280);
  static const navHideCurve = Curves.easeInOutCubic;

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

  // ---- Kuber's motion kit (v7.0.0), values unchanged ----

  // ---- Effects (opacity, colour: never springs). Kuber v7.0.0. ----
  static const Duration fxInstant = Duration(milliseconds: 90);
  static const Duration fxFast = micro;
  static const Duration fxDefault = Duration(milliseconds: 200);

  /// Every opacity and colour change.
  static const Curve curveEffects = Cubic(0.33, 1, 0.68, 1);

  // ---- Springs (mass 1). Interruptible: retarget with `springTo`. ----
  /// Small things: press, chips, radios, switch thumb, chevrons, menus.
  static final SpringDescription springFast =
      SpringDescription.withDampingRatio(mass: 1, stiffness: 800, ratio: 0.6);

  /// Medium things: enter, expand, list insert, dialogs, release of cards.
  static final SpringDescription springDefault =
      SpringDescription.withDampingRatio(mass: 1, stiffness: 380, ratio: 0.8);

  /// Large surfaces: sheets opening, container transform.
  static final SpringDescription springSlow =
      SpringDescription.withDampingRatio(mass: 1, stiffness: 200, ratio: 0.8);

  /// Reflow with no visible bounce: heights, widths, closing.
  static final SpringDescription springStandard =
      SpringDescription.withDampingRatio(mass: 1, stiffness: 700, ratio: 0.9);

  /// Every spatial motion at the Subtle level (critically damped).
  static final SpringDescription springSubtle =
      SpringDescription.withDampingRatio(mass: 1, stiffness: 600);

  /// Cached spring curves for implicit animations (use `.settle` as the
  /// duration, `.clamped` for sizes).
  static final SpringCurve fastCurve = SpringCurve(springFast);
  static final SpringCurve defaultCurve = SpringCurve(springDefault);
  static final SpringCurve slowCurve = SpringCurve(springSlow);
  static final SpringCurve standardCurve = SpringCurve(springStandard);
  static final SpringCurve subtleCurve = SpringCurve(springSubtle);

  /// [expressive] at Expressive, [springSubtle] at Subtle. (Off: callers skip.)
  static SpringDescription spatial(
    MotionLevel l,
    SpringDescription expressive,
  ) => l == MotionLevel.subtle ? springSubtle : expressive;

  /// Curve counterpart of [spatial].
  static SpringCurve spatialCurve(MotionLevel l, SpringCurve expressive) =>
      l == MotionLevel.subtle ? subtleCurve : expressive;

  // ---- Stagger (first load only, never while scrolling) ----
  static const Duration staggerStep = Duration(milliseconds: 30);
  static const int staggerLimit = 6;

  /// Delay of item [index]: 30 ms steps, items past the 6th share the 6th's.
  static Duration staggerDelay(int index) =>
      staggerStep *
      (index < 0 ? 0 : (index < staggerLimit ? index : staggerLimit - 1));

  /// Theme change ripple: a timed reveal on an even ease-in-out so the circle
  /// visibly sweeps across the screen. Subtle is shorter.
  static const Duration themeReveal = Duration(milliseconds: 800);
  static const Duration themeRevealSubtle = Duration(milliseconds: 500);
  static const Curve themeRevealCurve = Curves.easeInOutSine;
  static const Curve themeRevealSubtleCurve = Curves.easeInOutSine;

  // ---- Press amounts ----
  static const double pressScaleCard = 0.98; // cards and list rows
  static const double pressScaleSubtle = 0.99;
  static const double pressScaleFab = 0.96;
  static const double pressScaleChip = 0.96;
  static const double buttonGroupWiden = 0.15;

  // ---- Header pill (Kuber v7.0.0-c floating header) ----
  /// The header turns into the pill at this scroll offset (dp)...
  static const double pillAt = 32;

  /// ...and comes back at or under this one: the 24 dp between never flickers.
  static const double headerAt = 8;

  /// Pill hides after this much continuous downward scroll (When scrolling up
  /// / When scrolling stops), and shows again after [pillShowAfter] upward.
  static const double pillHideAfter = 16;
  static const double pillShowAfter = 8;

  /// When scrolling stops: the pill returns this long after the scroll ends.
  static const Duration pillStopDelay = Duration(milliseconds: 300);

  /// The level in force: the reader's choice and the device, unless the phone
  /// asks for no animation. Reads one InheritedWidget.
  static MotionLevel levelOf(BuildContext context) =>
      MotionScope.maybeOf(context)?.level ??
      (systemMotionOff(context) ? MotionLevel.off : MotionLevel.expressive);

  /// [base] at variable weight [wght] (FontVariation 'wght').
  static TextStyle weightStyle(TextStyle base, double wght) => base.copyWith(
    fontWeight: FontWeight.lerp(
      FontWeight.w100,
      FontWeight.w900,
      ((wght - 100) / 800).clamp(0.0, 1.0),
    ),
    fontVariations: <FontVariation>[FontVariation('wght', wght)],
  );

  /// One turn of the pull-to-refresh ring while a fetch runs.
  static const refreshTurn = Duration(milliseconds: 900);

  /// A notice leaving. Kuber's snackbar exit.
  static const snackExit = Duration(milliseconds: 140);

  /// Anything below Expressive: transforms become short fades.
  static bool reduced(BuildContext context) =>
      levelOf(context) != MotionLevel.expressive;

  /// Duration to actually use, honouring the level.
  static Duration of(BuildContext context, Duration full) =>
      reduced(context) ? reducedFade : full;

  static Curve curveOf(BuildContext context, Curve full) =>
      reduced(context) ? Curves.linear : full;
}
