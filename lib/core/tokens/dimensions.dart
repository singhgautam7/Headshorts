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
  static const menu = Radius.circular(20);
  static const pill = Radius.circular(999);

  static const chipBorder = BorderRadius.all(chip);
  static const buttonBorder = BorderRadius.all(button);
  static const cardBorder = BorderRadius.all(card);

  /// A photograph in the Reader column.
  static const imageBorder = BorderRadius.all(Radius.circular(14));
  static const sheetTop = BorderRadius.vertical(top: sheet);
  static const menuBorder = BorderRadius.all(menu);
  static const pillBorder = BorderRadius.all(pill);
}

/// Fixed sizes the design board calls out by number.
abstract final class HsSize {
  /// Floating nav pill: 60 tall, hugging its four items, and resting just
  /// clear of the gesture inset.
  ///
  /// The board draws it 22 above the frame's edge; on a real phone that inset
  /// sits *on top of* the system's own gesture area, and the pill ends up
  /// floating in the middle of the screen's bottom margin — most visible in
  /// Linger, where it eats into the card. The SafeArea already provides the
  /// distance the mock was drawing.
  static const navPillHeight = 60.0;
  static const navPillInset = 8.0;
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

  /// The medium list's thumbnail, and the one on a bookmark row.
  static const thumbnailMedium = 60.0;
  static const appBarHeight = 52.0;

  static const hairline = 1.0;
  static const glyphStroke = 1.6;
}
