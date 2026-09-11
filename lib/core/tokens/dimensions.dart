import 'package:flutter/widgets.dart';

/// 4-based spacing scale. Page margin and card gap sit deliberately high.
abstract final class HsSpace {
  static const x1 = 4.0;
  static const x2 = 8.0;
  static const x3 = 12.0;
  static const x4 = 16.0;

  /// space-5 — the page margin used by every screen.
  static const x5 = 24.0;

  /// space-6 — the gap between headline cards in Today.
  static const x6 = 32.0;
  static const x7 = 48.0;
  static const x8 = 64.0;

  /// Bottom padding that keeps scrolling content clear of the floating pill.
  static const navClearance = 104.0;
}

abstract final class HsRadius {
  static const chip = Radius.circular(6);
  static const button = Radius.circular(12);
  static const card = Radius.circular(18);
  static const sheet = Radius.circular(26);
  static const pill = Radius.circular(999);

  static const chipBorder = BorderRadius.all(chip);
  static const buttonBorder = BorderRadius.all(button);
  static const cardBorder = BorderRadius.all(card);
  static const sheetTop = BorderRadius.vertical(top: sheet);
  static const pillBorder = BorderRadius.all(pill);
}

/// Fixed sizes the design board calls out by number.
abstract final class HsSize {
  /// Floating nav pill: 60 tall, 22 from the bottom, hugging its four items.
  static const navPillHeight = 60.0;
  static const navPillInset = 22.0;
  static const navItem = 44.0;
  static const navPillPadding = 8.0;

  /// The hairline accent bar down the left of a headline.
  static const accentBar = 3.0;

  static const buttonLarge = 52.0;
  static const buttonMedium = 48.0;
  static const buttonSmall = 46.0;
  static const buttonCompact = 44.0;

  static const rowHeight = 56.0;
  static const sourceRowHeight = 60.0;
  static const settingsRowHeight = 58.0;

  static const toggleWidth = 44.0;
  static const toggleHeight = 26.0;
  static const toggleKnob = 20.0;
  static const checkbox = 20.0;

  static const thumbnail = 76.0;
  static const appBarHeight = 52.0;

  static const hairline = 1.0;
  static const glyphStroke = 1.6;
}
