import 'package:headshorts/core/util/canonical_url.dart';
import 'package:headshorts/data/readability/cleaning_rules.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

/// Turns whatever a publisher served into the small, safe subset of HTML the
/// Reader renders.
///
/// One pipeline, whatever the input — a full-content feed body or on-device
/// extraction both arrive here as an HTML string and leave in the same shape.
/// The order matters: boilerplate goes before sanitising, because the rules
/// that recognise it read the very `class` and `data-*` attributes that
/// sanitising throws away.
abstract final class ArticleCleaner {
  /// Attributes publishers hide the real image behind while a spacer sits in
  /// `src`.
  static const _lazyAttributes = [
    'data-src',
    'data-original',
    'data-lazy-src',
    'data-original-src',
    'data-hi-res-src',
  ];

  static const _lazySrcsets = ['srcset', 'data-srcset', 'data-lazy-srcset'];

  /// Longest a run of text can be and still be a boilerplate label rather
  /// than prose.
  static const _labelLength = 200;

  /// Whether [element] is still part of the document.
  ///
  /// A fragment's own top-level children report a null parent, so `parent ==
  /// null` cannot be used to mean "already removed" — doing so silently skips
  /// every root element, which is most of an extracted article.
  static bool _attached(dom.DocumentFragment fragment, dom.Element element) =>
      element.parent != null || fragment.nodes.contains(element);

  /// Cleans [html], resolving addresses against [base].
  static String clean(String html, {required Uri base}) {
    final rules = rulesFor(base.host);
    final fragment = html_parser.parseFragment(html);

    _resolveImages(fragment, base);
    _removeBoilerplate(fragment, rules);
    _removeSkipAndAriaJunk(fragment, rules);
    _resolveLinks(fragment, base);
    _sanitise(fragment);
    _prune(fragment);

    return _serialise(fragment);
  }

  // ---- a. Images ----------------------------------------------------------

  static void _resolveImages(dom.DocumentFragment fragment, Uri base) {
    for (final picture in fragment.querySelectorAll('picture')) {
      final image = picture.querySelector('img');
      if (image == null) {
        picture.remove();
        continue;
      }
      // The <img> is the fallback every browser can decode, so it wins. Only
      // when it turns out to be a spacer do we reach for a <source>.
      if (_realSource(image, base) == null) {
        final source = picture
            .querySelectorAll('source')
            .map((e) => e.attributes['srcset'])
            .firstWhere(
              (value) => value != null && value.isNotEmpty,
              orElse: () => null,
            );
        if (source != null) image.attributes['srcset'] = source;
      }
      picture.replaceWith(image);
    }

    for (final image in fragment.querySelectorAll('img')) {
      final resolved = _realSource(image, base);
      if (resolved == null) {
        // A spacer carries no information, and laying it out costs a screen.
        image.remove();
        continue;
      }
      image.attributes['src'] = resolved;
    }
  }

  static String? _realSource(dom.Element image, Uri base) {
    for (final attribute in _lazyAttributes) {
      final candidate = absolutise(image.attributes[attribute], base);
      if (candidate != null && !_isSpacer(candidate)) return candidate;
    }
    for (final attribute in _lazySrcsets) {
      final candidate = absolutise(_widest(image.attributes[attribute]), base);
      if (candidate != null && !_isSpacer(candidate)) return candidate;
    }
    final src = absolutise(image.attributes['src'], base);
    return (src == null || _isSpacer(src)) ? null : src;
  }

  /// Picks the largest candidate out of a `srcset` — the one worth
  /// downloading for a full-column-width image on a phone.
  static String? _widest(String? srcset) {
    if (srcset == null || srcset.trim().isEmpty) return null;

    var best = '';
    var bestWidth = -1.0;
    for (final entry in srcset.split(',')) {
      final parts = entry.trim().split(RegExp(r'\s+'));
      if (parts.isEmpty || parts.first.isEmpty) continue;
      final descriptor = parts.length > 1 ? parts[1] : '';
      final width =
          double.tryParse(descriptor.replaceAll(RegExp(r'[wx]$'), '')) ?? 1;
      if (width > bestWidth) {
        bestWidth = width;
        best = parts.first;
      }
    }
    return best.isEmpty ? null : best;
  }

  static bool _isSpacer(String url) {
    final lower = url.toLowerCase();
    return lower.startsWith('data:') ||
        lower.contains('spacer') ||
        lower.contains('1x1') ||
        lower.contains('blank.gif') ||
        lower.contains('transparent.png') ||
        lower.contains('placeholder');
  }

  // ---- b. Boilerplate containers -----------------------------------------

  static void _removeBoilerplate(
    dom.DocumentFragment fragment,
    CleaningRules rules,
  ) {
    for (final selector in rules.selectors) {
      for (final element in fragment.querySelectorAll(selector)) {
        if (_holdsRealProse(element)) continue;
        element.remove();
      }
    }

    for (final tag in droppedTags) {
      for (final element in fragment.querySelectorAll(tag)) {
        element.remove();
      }
    }

    final pattern = RegExp(
      rules.containerPatterns.join('|'),
      caseSensitive: false,
    );
    for (final element in fragment.querySelectorAll('*').toList()) {
      if (!_attached(fragment, element)) continue;
      final haystack = [
        element.className,
        element.id,
        ...element.attributes.entries
            .where((e) => e.key.toString().startsWith('data-'))
            .map((e) => e.value),
      ].join(' ');
      if (haystack.trim().isEmpty) continue;
      if (pattern.hasMatch(haystack)) element.remove();
    }
  }

  /// A container can carry a boilerplate class and still be the article — the
  /// Guardian's body wrapper mentions "content". Anything with several real
  /// paragraphs is kept.
  static bool _holdsRealProse(dom.Element element) =>
      element.querySelectorAll('p').length > 2 && element.text.length > 400;

  // ---- c. Skip links, aria junk, orphan captions --------------------------

  static void _removeSkipAndAriaJunk(
    dom.DocumentFragment fragment,
    CleaningRules rules,
  ) {
    for (final anchor in fragment.querySelectorAll('a[href^="#"]')) {
      if (anchor.text.trim().toLowerCase().startsWith('skip')) {
        anchor.remove();
      }
    }

    for (final hidden in fragment.querySelectorAll('[aria-hidden="true"]')) {
      hidden.remove();
    }

    final exact = rules.exactText.map((t) => t.toLowerCase()).toSet();
    for (final element in fragment.querySelectorAll('*').toList()) {
      if (!_attached(fragment, element)) continue;
      final text = element.text.replaceAll(RegExp(r'\s+'), ' ').trim();
      if (text.isEmpty) continue;

      final normalised = text.toLowerCase().replaceAll(RegExp(r'[.:…]+$'), '');

      // A prefix match may catch a whole promo block — the Guardian wraps the
      // skip link and its caption in one figure — so it is guarded by length.
      // Boilerplate labels are short; an article body that happens to open
      // with one of these words is not.
      final isLabel = text.length < _labelLength;
      final matches =
          exact.contains(normalised) ||
          (isLabel &&
              (normalised.startsWith('sign up to ') ||
                  normalised.startsWith('skip past ') ||
                  normalised.startsWith('skip to ')));

      // Remove the container, not just the text, so no orphan caption is left
      // sitting in the middle of the article.
      if (matches) element.remove();
    }
  }

  // ---- e. Links -----------------------------------------------------------

  static void _resolveLinks(dom.DocumentFragment fragment, Uri base) {
    for (final anchor in fragment.querySelectorAll('a[href]')) {
      final resolved = absolutise(anchor.attributes['href'], base);
      if (resolved == null) {
        anchor.attributes.remove('href');
        continue;
      }
      anchor.attributes['href'] = stripTracking(resolved);
    }
  }

  // ---- d. Allowlist -------------------------------------------------------

  static void _sanitise(dom.DocumentFragment fragment) {
    for (final element in fragment.querySelectorAll('*').toList()) {
      if (!_attached(fragment, element)) continue;
      final tag = element.localName ?? '';

      if (!allowedTags.contains(tag)) {
        // Unwrap rather than remove: an unknown wrapper is usually layout
        // around prose we want to keep. A root-level element is reparented
        // onto the fragment itself, which is its real parent.
        final siblings = element.parent?.nodes ?? fragment.nodes;
        final at = siblings.indexOf(element);
        final children = [...element.nodes];
        element.remove();
        for (var i = 0; i < children.length; i++) {
          siblings.insert(at + i, children[i]);
        }
        continue;
      }

      final keep = allowedAttributes[tag] ?? const <String>{};
      element.attributes.removeWhere(
        (name, _) => !keep.contains(name.toString()),
      );
    }
  }

  // ---- f. Prune -----------------------------------------------------------

  static void _prune(dom.DocumentFragment fragment) {
    // Empty elements can nest, so collapse repeatedly until nothing changes.
    var changed = true;
    while (changed) {
      changed = false;
      for (final element in fragment.querySelectorAll('*').toList()) {
        if (!_attached(fragment, element)) continue;
        final tag = element.localName ?? '';
        if (const {'img', 'br', 'hr', 'td', 'th'}.contains(tag)) continue;
        if (element.text.trim().isEmpty &&
            element.querySelector('img') == null) {
          element.remove();
          changed = true;
        }
      }
    }

    // A run of <br> is a paragraph break a publisher wrote by hand.
    for (final br in fragment.querySelectorAll('br')) {
      final next = br.nextElementSibling;
      if (next != null && next.localName == 'br') br.remove();
    }

    while (fragment.nodes.isNotEmpty && _isBlank(fragment.nodes.first)) {
      fragment.nodes.first.remove();
    }
    while (fragment.nodes.isNotEmpty && _isBlank(fragment.nodes.last)) {
      fragment.nodes.last.remove();
    }
  }

  /// An element is blank when it carries neither text nor a picture.
  ///
  /// `querySelector` only searches descendants, so an image has to be checked
  /// for by name as well — otherwise an article that opens or closes with a
  /// photograph loses it.
  static bool _isBlank(dom.Node node) => node is dom.Element
      ? node.localName != 'img' &&
            node.text.trim().isEmpty &&
            node.querySelector('img') == null
      : (node.text ?? '').trim().isEmpty;

  // ---- Shared helpers -----------------------------------------------------

  /// Resolves a URL against the article, handling the protocol-relative form
  /// and preferring `https` — an `http` resource is blocked outright on
  /// Android.
  static String? absolutise(String? value, Uri base) {
    final raw = value?.trim();
    if (raw == null || raw.isEmpty || raw.startsWith('data:')) return null;
    if (raw.startsWith('#') || raw.startsWith('javascript:')) return null;

    final resolved = raw.startsWith('//')
        ? '${base.scheme == 'http' ? 'https' : base.scheme}:$raw'
        : base.resolve(raw).toString();

    return resolved.startsWith('http://')
        ? resolved.replaceFirst('http://', 'https://')
        : resolved;
  }

  /// Drops campaign parameters from a link, keeping the ones that choose the
  /// page. Shares its notion of "tracking" with cross-feed de-duplication.
  static String stripTracking(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.queryParameters.isEmpty) return url;

    final kept = Map<String, String>.fromEntries(
      uri.queryParameters.entries.where((e) => !isTrackingParameter(e.key)),
    );
    return uri.replace(queryParameters: kept.isEmpty ? null : kept).toString();
  }

  static String _serialise(dom.DocumentFragment fragment) => fragment.nodes
      .map((n) => n is dom.Element ? n.outerHtml : n.text ?? '')
      .join();
}
