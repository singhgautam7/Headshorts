import 'dart:ui' show TextDirection;

/// Hebrew, Arabic (and the Syriac, Thaana and N'Ko blocks beside it), plus
/// their presentation forms.
final _rtl = RegExp('[֐-ࣿיִ-﷿ﹰ-﻿]');
final _ltr = RegExp(r'\p{L}', unicode: true);

/// The direction of [text], from its first strong character — the rule
/// browsers use for `dir=auto`. Left to right when nothing decides it.
///
/// Reads the text with markup stripped crudely (tags dropped), because the
/// Reader passes HTML and `<p>` is not Latin prose.
TextDirection textDirectionOf(String text) {
  final plain = text.replaceAll(RegExp('<[^>]*>'), ' ');
  for (final rune in plain.runes) {
    final char = String.fromCharCode(rune);
    if (_rtl.hasMatch(char)) return TextDirection.rtl;
    if (_ltr.hasMatch(char)) return TextDirection.ltr;
  }
  return TextDirection.ltr;
}
