import 'dart:math' as math;

/// How far either side of an article another publisher's copy may sit.
const relatedWindow = Duration(hours: 48);

/// The most matches shown.
const relatedMaxResults = 4;

/// Shared significant headline terms (a full name counts once) needed.
const relatedMinShared = 3;

/// Two shared terms are enough when the headlines are near-twins.
const relatedPairScore = 0.6;

/// With fewer than [relatedMinShared] but at least this many.
const relatedPairShared = 2;

/// Weighted cosine over headline terms needed on top of the shared count.
const relatedMinScore = 0.30;

/// A term is "significant" when it is rare in the window: it appears in no
/// more than this share of candidates (but always up to [_dfFloor] of them,
/// so a small cache is not starved).
const _dfShare = 0.03;
const _dfFloor = 12;

/// What the matcher knows about one article. Plain fields only: it crosses an
/// isolate boundary, and carries no bodies.
class RelatedCandidate {
  const new({
    required this.id,
    required this.title,
    required this.sourceId,
    required this.publishedAtMs,
    this.summary = '',
    this.canonicalUrl = '',
    this.titleKey = '',
    this.sourceTitle = '',
    this.accentDark = 0,
    this.accentLight = 0,
  });

  final int id;
  final String title;
  final String summary;
  final int sourceId;
  final String canonicalUrl;
  final String titleKey;
  final int publishedAtMs;
  final String sourceTitle;
  final int accentDark;
  final int accentLight;
}

class RelatedInput {
  const new({
    required this.article,
    required this.candidates,
    this.minShared = relatedMinShared,
    this.minScore = relatedMinScore,
  });

  final RelatedCandidate article;
  final List<RelatedCandidate> candidates;
  final int minShared;
  final double minScore;
}

/// One match, as the Reader shows it.
class RelatedStory {
  const new({
    required this.articleId,
    required this.title,
    required this.sourceTitle,
    required this.accentDark,
    required this.accentLight,
    required this.publishedAt,
  });

  final int articleId;
  final String title;
  final String sourceTitle;
  final int accentDark;
  final int accentLight;
  final DateTime publishedAt;
}

/// Other publishers' coverage of the same story, found by keywords alone.
///
/// Pure and top-level so it runs through `compute`. Precision over recall:
/// two headlines must share at least [RelatedInput.minShared] terms that are
/// rare in the window, and clear a weighted cosine, before they count. Words
/// everyone is using today ("court", "india") cannot match on their own.
List<RelatedCandidate> relatedMatches(RelatedInput input) => [
  for (final r in relatedScored(input)) r.c,
];

/// [relatedMatches] with each match's score, in the same order. For tuning.
List<({RelatedCandidate c, double score})> relatedScored(RelatedInput input) {
  final a = input.article;
  final windowMs = relatedWindow.inMilliseconds;
  final pool = [
    for (final c in input.candidates)
      if (c.id != a.id) c,
  ];

  final docs = <int, _Doc>{a.id: _Doc.of(a)};
  for (final c in pool) {
    docs[c.id] = _Doc.of(c);
  }

  // Document frequency over the headlines in the window, the article included.
  final df = <String, int>{};
  for (final d in docs.values) {
    for (final t in d.terms.keys) {
      df[t] = (df[t] ?? 0) + 1;
    }
  }
  final n = docs.length;
  final maxDf = math.max(_dfFloor, (n * _dfShare).floor());
  // df includes the article itself; "others holding the term" is df - 1.
  double idf(String t) => math.log((n + 1) / math.max(1, (df[t] ?? 1) - 1));
  double weight(String t, _Doc d) =>
      idf(t) * (d.terms[t] ?? 1) * ((df[t] ?? 1) <= maxDf ? 1 : 0.3);

  final da = docs[a.id]!;
  final normA = math.sqrt(
    da.terms.keys.fold<double>(0, (s, t) => s + math.pow(weight(t, da), 2)),
  );

  final best = <int, ({RelatedCandidate c, double score})>{};
  for (final c in pool) {
    if (c.sourceId == a.sourceId) continue;
    if ((c.publishedAtMs - a.publishedAtMs).abs() > windowMs) continue;
    if (a.canonicalUrl.isNotEmpty && c.canonicalUrl == a.canonicalUrl) continue;

    final dc = docs[c.id]!;
    double score;
    if (a.titleKey.isNotEmpty && a.titleKey == c.titleKey) {
      score = 1;
    } else {
      final units = <Object>{};
      var dot = 0.0;
      for (final t in da.terms.keys) {
        if (!dc.terms.containsKey(t)) continue;
        dot += weight(t, da) * weight(t, dc);
        // A full name is one thing, not two: "Elon Musk" alone is not a story.
        if ((df[t] ?? 1) <= maxDf) {
          units.add(da.runOf[t] ?? dc.runOf[t] ?? t);
        }
      }
      if (units.length < relatedPairShared) continue;
      final normC = math.sqrt(
        dc.terms.keys.fold<double>(0, (s, t) => s + math.pow(weight(t, dc), 2)),
      );
      if (normA == 0 || normC == 0) continue;
      score = dot / (normA * normC);
      if (score < input.minScore) continue;
      if (units.length < input.minShared && score < relatedPairScore) continue;
    }
    final prev = best[c.sourceId];
    if (prev == null ||
        score > prev.score ||
        (score == prev.score && c.publishedAtMs > prev.c.publishedAtMs)) {
      best[c.sourceId] = (c: c, score: score);
    }
  }

  // Strongest few, then collapse copies of one address, then newest first.
  final ranked = best.values.toList()
    ..sort((x, y) => y.score.compareTo(x.score));
  final seen = <String>{};
  final out = <({RelatedCandidate c, double score})>[];
  for (final r in ranked) {
    if (r.c.canonicalUrl.isNotEmpty && !seen.add(r.c.canonicalUrl)) continue;
    out.add(r);
    if (out.length == relatedMaxResults) break;
  }
  return out..sort((x, y) => y.c.publishedAtMs.compareTo(x.c.publishedAtMs));
}

/// Headline terms with a weight multiplier: proper nouns count more.
class _Doc {
  const new(this.terms, this.runOf);

  factory of(RelatedCandidate c) => _terms(c.title);

  final Map<String, double> terms;

  /// Terms that sit in one run of capitalised words (a name) share an id.
  final Map<String, int> runOf;
}

final _word = RegExp(r'[\p{L}\p{N}\p{M}]+', unicode: true);
final _latin = RegExp(r'^[a-z0-9]+$');

_Doc _terms(String title) {
  final words = _word.allMatches(title).map((m) => m.group(0)!).toList();
  // Title Case headlines capitalise everything; only trust capitals when most
  // words are lower case.
  final long = words.where((w) => w.length > 3).toList();
  final capped = long.where(_isCapital).length;
  final trustCaps = long.isNotEmpty && capped / long.length < 0.6;

  final out = <String, double>{};
  final runOf = <String, int>{};
  var run = 0;
  for (var i = 0; i < words.length; i++) {
    final raw = words[i];
    final lower = raw.toLowerCase();
    if (_stop.contains(lower)) continue;
    final term = _stem(lower);
    if (_stop.contains(term)) continue;
    final isNum = RegExp(r'^\p{N}+$', unicode: true).hasMatch(term);
    if (isNum ? term.length < 2 : term.length < 3) continue;
    final nextCap = i + 1 < words.length && _isCapital(words[i + 1]);
    final prevCap = i > 0 && _isCapital(words[i - 1]);
    final proper = trustCaps && _isCapital(raw) && (i > 0 || nextCap);
    if (proper) {
      if (!prevCap) run++;
      if (prevCap || nextCap) runOf[term] = run;
    }
    final w = proper || (isNum && term.length >= 3) ? 1.5 : 1.0;
    if (w > (out[term] ?? 0)) out[term] = w;
  }
  return _Doc(out, runOf);
}

bool _isCapital(String w) {
  final c = w.codeUnitAt(0);
  return c >= 65 && c <= 90;
}

String _stem(String w) {
  if (!_latin.hasMatch(w)) return w;
  if (w.length > 4 && w.endsWith('ies')) {
    return '${w.substring(0, w.length - 3)}y';
  }
  if (w.length > 5 && w.endsWith('ing')) return w.substring(0, w.length - 3);
  if (w.length > 4 && w.endsWith('es')) return w.substring(0, w.length - 2);
  if (w.length > 4 && w.endsWith('ed')) return w.substring(0, w.length - 2);
  if (w.length > 3 && w.endsWith('s') && !w.endsWith('ss')) {
    return w.substring(0, w.length - 1);
  }
  return w;
}

const _stopText =
    'the and for with from that this than then into onto over under '
    'after before about against between during while when what which '
    'who whom whose why how where are was were been being has have had '
    'will would could should can may might must not but its his her '
    'their our your they them she you out off all any one two new now '
    'also more most less just only very too per via amid says say said '
    'get gets got make makes made take takes took set sets sees seen '
    'goes went come comes came here there these those such each every '
    'some many much other another next last first second year years '
    'day days week weeks month months today tonight yesterday tomorrow '
    'monday tuesday wednesday thursday friday saturday sunday news '
    'live updates update latest breaking top big watch video photos '
    'photo explained explainer analysis opinion editorial report '
    'reports reported reportedly exclusive full story stories know '
    'things thing check details read see want wants needs need back '
    'ahead announces announced claims claim hits hit ups down plans '
    'plan demand demands के की का को में से पर है हैं था थे थी और या '
    'ने एक यह वह इस उस भी तो ही कि लिए साथ बाद कर करें किया करने होगा '
    'होंगे अब जब कब क्या कैसे खबर समाचार लाइव वीडियो देखें जानें जानिए '
    'बड़ी बड़ा आज कल सबसे रहे रही रहा गया गई गए दिया दी दिए लेकर बारे ';

final _stop = _stopText.split(' ').where((w) => w.isNotEmpty).toSet();
