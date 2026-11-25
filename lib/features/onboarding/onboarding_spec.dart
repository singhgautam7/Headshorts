import 'package:flutter/painting.dart';

/// Sizes that belong to the first-run flow only, from Kuber's onboarding.
/// Durations and curves are not here: they are `HsMotion`'s, so the flow runs
/// on the same clock as everything else.
abstract final class OnboardingSpec {
  /// Dots: 8 tall, the active one 24 wide.
  static const double dotHeight = 8;
  static const double dotInactive = 8;
  static const double dotActive = 24;
  static const double dotMargin = 4;

  /// Bottom bar.
  static const double backWidth = 112;
  static const double barRise = 16;
  static const Offset labelSlide = Offset(0, 0.16);

  /// Skip sits top right in a bar this tall on every page, so nothing jumps
  /// when it leaves for the setup page.
  static const double skipHeight = 56;

  /// The soft edge above the bottom bar, where scrolling content fades out.
  static const double fade = 24;

  /// Page content entrance.
  static const Offset entranceSlide = Offset(0, 0.08);
  static const Duration entrance = Duration(milliseconds: 500);
  static const Duration delayArt = Duration(milliseconds: 80);
  static const Duration delayTitle = Duration(milliseconds: 160);
  static const Duration delayBody = Duration(milliseconds: 260);
  static const Duration barEntranceDelay = Duration(milliseconds: 230);
  static const Duration barEntrance = Duration(milliseconds: 250);

  /// The illustration above each page's title: what the words leave, between
  /// these two, acting itself out once over [scene].
  static const double artMin = 96;
  static const double artMax = 380;
  static const Duration scene = Duration(milliseconds: 3200);
}
