/// Reduces a link to the identity of the story behind it, so the same article
/// syndicated through two feeds is recognised as one item.
///
/// Deliberately conservative: it strips the things publishers add for
/// tracking, and nothing that could change which page you land on.
String canonicalUrl(String link) {
  final uri = Uri.tryParse(link.trim());
  if (uri == null || uri.host.isEmpty) return link.trim().toLowerCase();

  final host = uri.host.toLowerCase().replaceFirst(
    RegExp(r'^(www|m|amp)\.'),
    '',
  );

  // Aggregators wrap the publisher's address in a redirect. When the real one
  // is right there in a query parameter, use it instead.
  final wrapped = _unwrap(uri);
  if (wrapped != null) return canonicalUrl(wrapped);

  final query = Map<String, String>.fromEntries(
    uri.queryParameters.entries.where((e) => !isTrackingParameter(e.key)),
  );

  var path = uri.path;
  // Trailing slashes and AMP suffixes name the same page.
  if (path.endsWith('/amp')) path = path.substring(0, path.length - 4);
  if (path.endsWith('/amp/')) path = path.substring(0, path.length - 5);
  if (path.length > 1 && path.endsWith('/')) {
    path = path.substring(0, path.length - 1);
  }

  final canonical = StringBuffer('$host${path.toLowerCase()}');
  if (query.isNotEmpty) {
    final keys = query.keys.toList()..sort();
    canonical.write('?${keys.map((k) => '$k=${query[k]}').join('&')}');
  }
  return canonical.toString();
}

/// Query parameters that identify a campaign rather than a page.
///
/// Shared with the Reader's link cleaning: the same parameters that must not
/// change a story's identity must not survive into a tapped link either.
bool isTrackingParameter(String key) {
  final lower = key.toLowerCase();
  return lower.startsWith('utm_') ||
      lower.startsWith('at_') ||
      const {
        'fbclid',
        'gclid',
        'igshid',
        'mc_cid',
        'mc_eid',
        'ref',
        'referrer',
        'source',
        'cmpid',
        'ns_campaign',
        'ns_mchannel',
        'ns_source',
        'smid',
        'guccounter',
        'ito',
        'ocid',
        'sh',
      }.contains(lower);
}

/// Parameters aggregators use to carry the real address.
const _redirectParameters = ['url', 'u', 'q', 'target', 'redirect'];

String? _unwrap(Uri uri) {
  for (final key in _redirectParameters) {
    final value = uri.queryParameters[key];
    if (value == null) continue;
    final inner = Uri.tryParse(value);
    if (inner != null && inner.hasScheme && inner.host.isNotEmpty) return value;
  }
  return null;
}

/// A loose fingerprint of a headline, for catching the same story filed under
/// two slightly different titles.
///
/// Lower-cased, punctuation dropped, common words dropped, each remaining word
/// reduced to its stem, and the result sorted — so "Rail operators trial a
/// fare cap" and "Fare cap trialled by rail operators" collapse together,
/// while unrelated headlines do not.
String titleFingerprint(String title) {
  final words =
      title
          .toLowerCase()
          .replaceAll(RegExp('[^a-z0-9 ]'), ' ')
          .split(RegExp(r'\s+'))
          .where((w) => w.length > 3 && !_stopWords.contains(w))
          .map(_stem)
          .toSet()
          .toList()
        ..sort();
  // Too few distinctive words to be sure; refuse to fingerprint rather than
  // risk collapsing two different stories.
  if (words.length < 4) return '';
  return words.take(10).join(' ');
}

/// A crude stem, enough to see past the tense and number a sub-editor chose.
///
/// Not a real stemmer: it only has to make two renderings of the same headline
/// agree, and over-stemming would risk merging different stories.
String _stem(String word) {
  var stem = word;
  for (final suffix in const ['ing', 'ed', 'es', 's']) {
    if (stem.length > suffix.length + 3 && stem.endsWith(suffix)) {
      stem = stem.substring(0, stem.length - suffix.length);
      break;
    }
  }
  // "trialled" -> "trial", "planned" -> "plan": a doubled final consonant is
  // an artefact of the suffix, not part of the word.
  if (stem.length > 3 && stem[stem.length - 1] == stem[stem.length - 2]) {
    stem = stem.substring(0, stem.length - 1);
  }
  return stem;
}

const _stopWords = {
  'after',
  'about',
  'from',
  'into',
  'over',
  'that',
  'this',
  'their',
  'they',
  'says',
  'said',
  'with',
  'will',
  'have',
  'been',
  'were',
  'what',
  'when',
  'which',
  'while',
  'your',
};
