import 'dart:ui' show Locale;

/// What the app knows about a language tag.
///
/// A source's `language` is a plain BCP-47 tag; this is the lookup that turns
/// it into something to show. Three names, because three places need
/// different ones: the segmented control names a language **in its own
/// script**, the row tag is a two-letter code, and TalkBack is given the full
/// English name — "Hindi", never "H I".
class HsLanguage {
  const new({
    required this.tag,
    required this.endonym,
    required this.englishName,
  });

  /// The entry for [tag], or one that names itself by its own tag. Never
  /// null: an unknown language is still a language, and hiding it would hide
  /// the sources filed under it.
  factory of(String tag) {
    final base = tag.split('-').first.toLowerCase();
    for (final language in known) {
      if (language.tag == base) return language;
    }
    final upper = base.toUpperCase();
    return HsLanguage(tag: base, endonym: upper, englishName: upper);
  }

  final String tag;

  /// The language's name in its own script, which is how the filter labels it.
  final String endonym;

  /// The spoken label, for semantics and for the read-aloud copy.
  final String englishName;

  /// The two-letter tag on a source row.
  String get code => tag.split('-').first.toUpperCase();

  Locale get locale {
    final parts = tag.split('-');
    return parts.length > 1
        ? Locale(parts.first, parts[1])
        : Locale(parts.first);
  }

  static const english = HsLanguage(
    tag: 'en',
    endonym: 'English',
    englishName: 'English',
  );

  /// The languages the bundled catalog carries. Anything outside this list
  /// still works — it simply names itself by its tag.
  static const known = [
    english,
    HsLanguage(tag: 'hi', endonym: 'हिन्दी', englishName: 'Hindi'),
    HsLanguage(tag: 'bn', endonym: 'বাংলা', englishName: 'Bengali'),
    HsLanguage(tag: 'ta', endonym: 'தமிழ்', englishName: 'Tamil'),
    HsLanguage(tag: 'te', endonym: 'తెలుగు', englishName: 'Telugu'),
    HsLanguage(tag: 'mr', endonym: 'मराठी', englishName: 'Marathi'),
    HsLanguage(tag: 'gu', endonym: 'ગુજરાતી', englishName: 'Gujarati'),
    HsLanguage(tag: 'kn', endonym: 'ಕನ್ನಡ', englishName: 'Kannada'),
    HsLanguage(tag: 'ml', endonym: 'മലയാളം', englishName: 'Malayalam'),
    HsLanguage(tag: 'pa', endonym: 'ਪੰਜਾਬੀ', englishName: 'Punjabi'),
    HsLanguage(tag: 'ur', endonym: 'اردو', englishName: 'Urdu'),
  ];
}

/// True when [text] is written in a script that needs the Indic type stack:
/// taller line heights, no letter-spacing, and no uppercasing.
///
/// Letter-spacing breaks conjuncts and there is no case to raise, so a source
/// label in Devanagari sets flat and unspaced while the Latin one stays
/// tracked caps. Checked on the text rather than on the source's tag, because
/// an English-tagged feed still carries the odd Devanagari headline.
bool isIndicText(String text) {
  for (final rune in text.runes) {
    // Devanagari through Malayalam, then Sinhala — the contiguous Indic
    // block of the BMP. One range covers every script the catalog carries.
    if (rune >= 0x0900 && rune <= 0x0DFF) return true;
  }
  return false;
}
