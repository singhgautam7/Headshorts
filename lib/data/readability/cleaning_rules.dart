/// What to strip out of an extracted article, as data rather than code.
///
/// Global rules cover the patterns every publisher shares; per-domain rules
/// cover one publisher's quirk. Adding a publisher is a single entry in
/// [perDomainCleaningRules] — the pipeline itself never changes. Same idea as
/// `SourceAdapter`: the extension point is a registration, not an edit.
class CleaningRules {
  const new({
    this.containerPatterns = const [],
    this.exactText = const [],
    this.textPatterns = const [],
    this.selectors = const [],
  });

  /// Matched case-insensitively against an element's `class`, `id` and
  /// `data-*` values. A hit removes the whole element.
  final List<String> containerPatterns;

  /// An element whose *entire* text is one of these goes, container and all.
  /// Removing only the text leaves an orphan caption behind, which is exactly
  /// the "after newsletter promotion" symptom.
  final List<String> exactText;

  /// Like [exactText], but a pattern over the element's whole text, lower-
  /// cased and without trailing punctuation — for labels that carry a
  /// number or a variable tail: "3 min read", "Catch the latest World News…".
  /// Still guarded by the label length, so a paragraph never matches.
  final List<RegExp> textPatterns;

  /// CSS selectors to remove outright, for a publisher-specific structure.
  final List<String> selectors;

  CleaningRules merge(CleaningRules other) => CleaningRules(
    containerPatterns: [...containerPatterns, ...other.containerPatterns],
    exactText: [...exactText, ...other.exactText],
    textPatterns: [...textPatterns, ...other.textPatterns],
    selectors: [...selectors, ...other.selectors],
  );
}

/// Rules that apply to every article.
final globalCleaningRules = CleaningRules(
  containerPatterns: [
    'newsletter',
    'promo',
    'sign[-_]?up',
    'subscribe',
    'related',
    'read[-_]?more',
    'share',
    'social',
    'advert',
    r'\bads?\b',
    'sponsor',
    'cta',
    'call[-_]?to[-_]?action',
    'marketing',
    'contribution',
    'support-the-guardian',
    'paywall',
    'metered',
    'comments',
    'trending',
    'most-popular',
    'outbrain',
    'taboola',
  ],
  exactText: [
    'advertisement',
    'advertisements',
    'promoted stories',
    'sponsored content',
    'related stories',
    'related articles',
    'read more',
    'share this article',
    'most read',
    'follow us',
    'subscribe',
    'newsletter',
  ],
  textPatterns: [
    RegExp('^sign up to '),
    RegExp('^skip (past|to) '),
    RegExp('^story continues below'),
    // Indian Express runs its byline strip together: "3 min readJaipur…".
    RegExp(r'^\d+ min read'),
    // The SEO tail after a Times of India story.
    RegExp('^(catch|get) the latest '),
    RegExp(r'^(also|read) (read|more):?$'),
    // A tag list at the foot: "Tags: Jaipur, Rajasthan".
    RegExp('^(tags?|topics?):'),
  ],
);

/// One publisher's quirks, keyed on the article's host without `www.`.
///
/// Keep these small and specific. Anything that generalises belongs in
/// [globalCleaningRules] instead.
final perDomainCleaningRules = <String, CleaningRules>{
  'theguardian.com': const CleaningRules(
    exactText: [
      'skip past newsletter promotion',
      'after newsletter promotion',
      'sign up to first edition',
      'sign up to headlines uk',
      'sign up to this is europe',
      'privacy notice',
    ],
    selectors: ['[data-component]', '.atom--snippet'],
  ),
  'bbc.co.uk': const CleaningRules(
    exactText: ['getty images', 'watch:', 'listen:'],
  ),
  // The byline strip ("3 min read · Jaipur · Updated: …"), the ad-slot
  // labels between paragraphs, and the author box with its avatar at the
  // foot.
  'indianexpress.com': const CleaningRules(
    containerPatterns: [
      'post-info',
      'article-publish-date',
      'ie-adtext',
      'adbox',
      'author-block',
      'author-img',
      'author-bio',
      'more-abt-author',
      r'\btags\b',
    ],
  ),
  // The lead video's embed, whose caption would otherwise open the story.
  'timesofindia.indiatimes.com': const CleaningRules(
    containerPatterns: ['vdo_embedd', 'leadmedia'],
  ),
  // The story is in `.Art-exp_wr`, collapsed behind a "Show full article"
  // toggle by CSS alone — the paragraphs are all in the initial HTML — and
  // interleaved with ad slots, an AI "Quick Read" box, an "Ask NDTV" widget,
  // share bars and an SEO footer. Everything here names one of those.
  'ndtv.com': const CleaningRules(
    containerPatterns: [
      'AskWg1',
      'ASum_',
      'Art-exp_bt',
      'SoFl_',
      'ins_instory',
      'pst-by',
      'read-tim',
      'CpyLk',
      'SSR_',
      'vuukle',
      'QukLnk',
      'LsWg',
      's-ls_',
      'stk_cnt',
      'passbackpixel',
      '_whtvr',
      'v-ndtv',
      'kwry',
    ],
    exactText: ['show full article', 'read time:', 'follow us:'],
  ),
  'nytimes.com': const CleaningRules(
    exactText: ['thank you for your patience'],
  ),
  'washingtonpost.com': const CleaningRules(exactText: ['end of carousel']),
};

/// The rules in force for [host] — the global set plus anything registered
/// for that publisher or a parent domain.
CleaningRules rulesFor(String host) {
  final normalised = host.toLowerCase().replaceFirst(RegExp(r'^www\.'), '');
  var rules = globalCleaningRules;

  for (final entry in perDomainCleaningRules.entries) {
    if (normalised == entry.key || normalised.endsWith('.${entry.key}')) {
      rules = rules.merge(entry.value);
    }
  }
  return rules;
}

/// The only tags that reach the renderer. Everything else is unwrapped or
/// dropped.
///
/// An allowlist rather than a blocklist because the junk that matters is the
/// junk nobody has seen yet: a publisher's new widget arrives as an unknown
/// `<div class="thing">` and is gone by default.
const allowedTags = {
  'p',
  'h1',
  'h2',
  'h3',
  'h4',
  'h5',
  'h6',
  'strong',
  'b',
  'em',
  'i',
  'u',
  's',
  'blockquote',
  'ul',
  'ol',
  'li',
  'a',
  'img',
  'figure',
  'figcaption',
  'pre',
  'code',
  'br',
  'hr',
  'sub',
  'sup',
  'table',
  'thead',
  'tbody',
  'tr',
  'th',
  'td',
};

/// Tags removed outright rather than unwrapped: whatever they contain is
/// chrome, not article.
const droppedTags = {
  'aside',
  'iframe',
  'script',
  'style',
  'noscript',
  'form',
  'button',
  'input',
  'select',
  'textarea',
  'nav',
  'header',
  'footer',
  'video',
  'audio',
  'object',
  'embed',
  'svg',
  'canvas',
};

/// Attributes that survive sanitising, per tag. Everything else — `class`,
/// `style`, `id`, `data-*`, every `on*` handler — is stripped.
const allowedAttributes = <String, Set<String>>{
  'a': {'href'},
  'img': {'src', 'alt'},
  'td': {'colspan', 'rowspan'},
  'th': {'colspan', 'rowspan'},
};
