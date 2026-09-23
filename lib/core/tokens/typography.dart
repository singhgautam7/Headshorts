import 'package:flutter/widgets.dart';
import 'package:headshorts/core/util/language.dart';

/// Source Serif 4 for editorial voice; Archivo for UI, labels and chrome.
///
/// Both families ship as variable fonts, so every weight below is set through
/// a `wght` axis variation as well as [FontWeight] — the axis is what actually
/// renders, the weight keeps fallback fonts sensible.
abstract final class HsType {
  static const serif = 'SourceSerif4';
  static const sans = 'Archivo';

  /// The script fallbacks behind every role.
  ///
  /// Source Serif 4 and Archivo carry no Indic glyphs, so a Hindi headline in
  /// either would come back as tofu — or, worse, as whatever the platform
  /// happened to substitute, at the wrong weight and the wrong colour. Noto
  /// Devanagari ships **with the app**, in both voices, because Devanagari is
  /// the second script of the catalog and must look designed rather than
  /// found. The rest name Android's own Noto families: they are present on
  /// every device the app targets, and bundling nine more scripts would add
  /// megabytes for feeds most readers will never take up.
  ///
  /// Fallback is per-glyph, so a headline mixing Latin and Devanagari sets
  /// each run in the right family without anything having to detect a script.
  static const serifFallback = [
    'NotoSerifDevanagari',
    'Noto Serif Devanagari',
    'Noto Serif Bengali',
    'Noto Serif Tamil',
    'Noto Serif Telugu',
    'Noto Serif Kannada',
    'Noto Serif Malayalam',
    'Noto Serif Gujarati',
    'Noto Serif Gurmukhi',
    'Noto Nastaliq Urdu',
  ];

  static const sansFallback = [
    'NotoSansDevanagari',
    'Noto Sans Devanagari',
    'Noto Sans Bengali',
    'Noto Sans Tamil',
    'Noto Sans Telugu',
    'Noto Sans Kannada',
    'Noto Sans Malayalam',
    'Noto Sans Gujarati',
    'Noto Sans Gurmukhi',
    'Noto Nastaliq Urdu',
  ];

  static TextStyle _serif(
    double size,
    double height,
    int weight, {
    double tracking = 0,
  }) => TextStyle(
    fontFamily: serif,
    fontFamilyFallback: serifFallback,
    fontSize: size,
    height: height,
    fontWeight: FontWeight.values[weight ~/ 100 - 1],
    fontVariations: [FontVariation('wght', weight.toDouble())],
    letterSpacing: tracking * size,
  );

  static TextStyle _sans(
    double size,
    double height,
    int weight, {
    double tracking = 0,
  }) => TextStyle(
    fontFamily: sans,
    fontFamilyFallback: sansFallback,
    fontSize: size,
    height: height,
    fontWeight: FontWeight.values[weight ~/ 100 - 1],
    fontVariations: [FontVariation('wght', weight.toDouble())],
    letterSpacing: tracking * size,
  );

  // ---- Named scale from the token panel -----------------------------------

  /// display · serif 34/1.14 — "You're caught up".
  static TextStyle get display => _serif(34, 1.14, 600, tracking: -0.015);

  /// headline · serif 22/1.26.
  static TextStyle get headline => _serif(22, 1.26, 600);

  /// title · sans 16/1.35 · 500.
  static TextStyle get title => _sans(16, 1.35, 500);

  /// body · serif 17/1.7, the Reader's measure.
  static TextStyle get bodySerif => _serif(17, 1.7, 400);

  /// body · sans 14/1.6, everywhere else.
  static TextStyle get bodySans => _sans(14, 1.6, 400);

  /// caption · sans 12/1.4 — "2 hours ago".
  static TextStyle get caption => _sans(12, 1.4, 400);

  /// label · sans 12/1 · 600 · .06em — "THE HINDU".
  static TextStyle get label => _sans(12, 1, 600, tracking: 0.06);

  // ---- Screen-specific steps, all drawn from the same two families --------

  /// The serif screen title on Today, Sources and More.
  static TextStyle get screenTitle => _serif(26, 1.2, 600);

  /// Onboarding's opening statement.
  static TextStyle get welcome => _serif(40, 1.1, 600, tracking: -0.02);

  /// Onboarding's step heading.
  static TextStyle get stepTitle => _serif(24, 1.2, 600);

  /// Onboarding and caught-up prose.
  static TextStyle get lead => _serif(17, 1.65, 400);

  /// A headline in the Today list.
  static TextStyle get cardHeadline => _serif(19, 1.32, 600);

  /// The same headline in the medium list — a step down, clamped to three
  /// lines, so about seven fit a screen instead of three.
  static TextStyle get cardHeadlineMedium => _serif(16, 1.3, 600);

  /// The small list's whole row: two lines, with the source run in.
  static TextStyle get cardHeadlineSmall => _serif(14, 1.36, 500);

  /// The one-line summary under a Today headline.
  static TextStyle get cardSummary => _sans(13, 1.55, 400);

  /// The uppercase source label above a Today headline.
  static TextStyle get sourceLabel => _sans(11, 1, 600, tracking: 0.08);

  /// The timestamp under a Today headline.
  static TextStyle get timestamp => _sans(12, 1, 400);

  /// The timestamp in the medium and small lists.
  static TextStyle get timestampSmall => _sans(11, 1, 400);

  /// A category sub-tab.
  static TextStyle get subTab => _sans(14, 1, 400);
  static TextStyle get subTabActive => _sans(14, 1, 500);

  /// The two-letter language code on a source row: 9/600, tracked, on a
  /// stroke hairline.
  static TextStyle get languageTag => _sans(9, 1, 600, tracking: 0.06);

  /// The uppercase group label above a list section.
  static TextStyle get sectionLabel => _sans(11, 1, 600, tracking: 0.12);

  /// A Linger headline.
  static TextStyle get lingerHeadline =>
      _serif(32, 1.16, 600, tracking: -0.015);

  /// A Linger body extract.
  static TextStyle get lingerBody => _serif(16, 1.72, 400);

  /// The uppercase source label on a Linger card and in the Reader bar.
  static TextStyle get lingerLabel => _sans(12, 1, 600, tracking: 0.09);

  /// The Reader's own headline.
  static TextStyle get readerTitle => _serif(27, 1.22, 700, tracking: -0.015);

  /// The standfirst under the headline: the feed's own summary, one step
  /// larger than the byline and a step under the body.
  static TextStyle get readerStandfirst => _serif(18, 1.5, 400);
  static TextStyle get readerByline => _sans(13, 1.4, 500);
  static TextStyle get readerMeta => _sans(12, 1.4, 400);

  /// Reader body at a given step of the size scale.
  static TextStyle readerBody(double size) => _serif(size, 1.72, 400);

  /// The caught-up display, one step down from [display] inside Today.
  static TextStyle get caughtUp => _serif(30, 1.2, 600);
  static TextStyle get caughtUpLinger => _serif(32, 1.18, 600);
  static TextStyle get caughtUpBody => _sans(14, 1.65, 400);

  static TextStyle get buttonLarge => _sans(15, 1, 500);
  static TextStyle get buttonMedium => _sans(14, 1, 500);
  static TextStyle get buttonSmall => _sans(13, 1, 500);

  /// A settings or source row.
  static TextStyle get row => _sans(15, 1, 400);
  static TextStyle get rowValue => _sans(13, 1, 400);
  static TextStyle get rowSub => _sans(12, 1, 400);

  /// The title in a pushed screen's bar.
  static TextStyle get appBarTitle => _sans(16, 1, 500);

  static TextStyle get chip => _sans(13, 1, 400);
  static TextStyle get chipSelected => _sans(13, 1, 500);

  static TextStyle get statLabel => _sans(13, 1, 400);
  static TextStyle get statValue => _sans(13, 1, 500);
  static TextStyle get statTitle => _sans(14, 1, 500);
  static TextStyle get note => _sans(12, 1.5, 400);
  static TextStyle get noteTight => _sans(12, 1.55, 400);

  /// The same role, set for an Indic script.
  ///
  /// Two changes, both from the board's type table: the line opens up so
  /// matras and conjuncts clear the line above (19/1.32 becomes 19/1.50,
  /// 17/1.72 becomes 17/1.85), and letter-spacing goes to zero, because
  /// tracking pulls a conjunct apart into its halants.
  ///
  /// The size never changes. A Devanagari headline is the same headline.
  static TextStyle indic(TextStyle style) => style.copyWith(
    height: style.height == null ? null : style.height! * _indicLeading,
    letterSpacing: 0,
  );

  /// How much further apart the lines sit. 1.50 / 1.32 from the board's own
  /// headline row, and it lands on 1.85 for the reader body as well.
  static const _indicLeading = 1.135;

  /// A role set for whichever script [text] is actually in.
  static TextStyle forText(TextStyle style, String text) =>
      isIndicText(text) ? indic(style) : style;

  /// The source label, which changes more than its leading in Devanagari:
  /// the board drops the caps and the tracking and goes up a step, because
  /// there is no case to raise and the tracking breaks the clusters.
  static TextStyle sourceLabelFor(String name) =>
      isIndicText(name) ? _sans(12, 1.2, 600) : sourceLabel;

  /// The source label's text: uppercased in Latin, left alone otherwise.
  static String sourceLabelText(String name) =>
      isIndicText(name) ? name : name.toUpperCase();
}
