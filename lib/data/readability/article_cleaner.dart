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

    _stripComments(fragment);
    _resolveImages(fragment, base);
    _preserveCaptions(fragment);
    _removeBoilerplate(fragment, rules);
    _removeSkipAndAriaJunk(fragment, rules);
    _resolveLinks(fragment, base);
    _sanitise(fragment);
    _stitchInlineNodes(fragment);
    _prune(fragment);

    return _serialise(fragment);
  }

  /// Comments are not prose. Serialising a fragment writes a comment's text
  /// out as text, and unwrapping a wrapper reparents its comments onto the
  /// fragment, so an ad-slot marker like `<!--MIDTABOOLA-->` was landing in
  /// the article as the word "MIDTABOOLA".
  static void _stripComments(dom.Node node) {
    for (final child in node.nodes.toList()) {
      if (child is dom.Comment) {
        child.remove();
      } else {
        _stripComments(child);
      }
    }
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
        lower.contains('placeholder') ||
        lower.contains('avatar') ||
        lower.contains('default-ie');
  }

  // ---- b. Captions --------------------------------------------------------

  static final _captionPattern = RegExp(
    r'\b(caption|img[-_]?cptn|image[-_]?caption|photo[-_]?caption|media[-_]?caption|wp-caption-text|art[-_]?caption|lead[-_]?cptn|caption[-_]?text|img[-_]?desc|custom[-_]?caption)\b',
    caseSensitive: false,
  );

  static final _promoOrSocialPattern = RegExp(
    r'\b(promo|newsletter|share|social|advert|sponsor|ad|cta)\b',
    caseSensitive: false,
  );

  /// Recognises photo captions and credits across publishers and normalises
  /// them to `<figcaption>` before unwrapping and sanitising.
  ///
  /// Publishers often wrap image captions in ad-hoc `<div>`, `<p>` or `<span>`
  /// elements with classes like `img_cptn`, `image-caption`, or `wp-caption-text`.
  /// Without this normalization, unwrapping unknown tags converts the caption
  /// into indistinguishable body prose. Normalising to `<figcaption>` ensures
  /// the Reader styles it in the dedicated muted, smaller sans-serif caption token.
  static void _preserveCaptions(dom.DocumentFragment fragment) {
    for (final element in fragment.querySelectorAll('*').toList()) {
      if (!_attached(fragment, element)) continue;
      if (element.localName == 'figcaption') continue;

      final haystack = [
        element.className,
        element.id,
        ...element.attributes.entries
            .where((e) => e.key.toString().startsWith('data-'))
            .map((e) => e.value),
      ].join(' ');

      if (haystack.trim().isEmpty) continue;
      if (!_captionPattern.hasMatch(haystack)) continue;
      if (_promoOrSocialPattern.hasMatch(haystack)) continue;

      // Ensure it is a genuine caption: short prose, not a multi-paragraph
      // story block or form.
      final text = element.text.replaceAll(RegExp(r'\s+'), ' ').trim();
      if (text.isEmpty || text.length > 400) continue;
      if (element.querySelectorAll('p').length > 1) continue;

      final figcaption = dom.Element.tag('figcaption')..text = text;
      // The caption class is often on the wrapper that holds the picture
      // too — Indian Express's `span.custom-caption` is image then text.
      // Replacing the wrapper with its text alone loses every photograph.
      final images = element.querySelectorAll('img');
      if (images.isEmpty) {
        element.replaceWith(figcaption);
        continue;
      }
      final figure = dom.Element.tag('figure');
      images.forEach(figure.append);
      figure.append(figcaption);
      element.replaceWith(figure);
    }

    for (final figure in fragment.querySelectorAll('figure').toList()) {
      if (!_attached(fragment, figure)) continue;
      if (figure.querySelector('figcaption') != null) continue;
      for (final child in figure.children) {
        if (child.localName == 'img' || child.querySelector('img') != null) {
          continue;
        }
        final text = child.text.replaceAll(RegExp(r'\s+'), ' ').trim();
        if (text.isNotEmpty &&
            text.length <= 400 &&
            child.querySelectorAll('p').length <= 1) {
          final figcaption = dom.Element.tag('figcaption')..text = text;
          child.replaceWith(figcaption);
          break;
        }
      }
    }
  }

  // ---- c. Boilerplate containers -----------------------------------------

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
      if (!pattern.hasMatch(haystack)) continue;
      // A wrapper can carry an ad-ish class and still be the article: NDTV's
      // story body sits in `sp-cn pg-str-com js-ad-section`, and Indian
      // Express gates the second half of a story — figures included — in
      // `paywall container-wall-exclusive`. Several real paragraphs is the
      // article, whatever the class says.
      if (_holdsRealProse(element)) continue;
      element.remove();
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

      // A pattern match may catch a whole promo block — the Guardian wraps
      // the skip link and its caption in one figure — so it is guarded by
      // length. Boilerplate labels are short; an article body that happens to
      // open with one of these words is not.
      final isLabel = text.length < _labelLength;
      final matches =
          exact.contains(normalised) ||
          (isLabel && rules.textPatterns.any((p) => p.hasMatch(normalised)));

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

  // ---- e. Stitch inline elements & split paragraphs ----------------------

  static const _inlineTags = {
    'a',
    'strong',
    'b',
    'em',
    'i',
    'u',
    's',
    'code',
    'sub',
    'sup',
    'span',
    'br',
    'small',
    'mark',
  };

  static bool _isInline(dom.Node node) {
    if (node is dom.Text) return true;
    if (node is dom.Element) return _inlineTags.contains(node.localName);
    return false;
  }

  static bool _isWhitespace(dom.Node node) {
    if (node is dom.Text) return node.text.trim().isEmpty;
    return false;
  }

  static bool _endsWithTerminalPunctuation(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return false;
    final lastChar = trimmed.substring(trimmed.length - 1);
    return const [
      '.',
      '!',
      '?',
      ':',
      '—',
      '"',
      "'",
      '”',
      '’',
    ].contains(lastChar);
  }

  static bool _startsWithContinuation(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return false;
    final firstChar = trimmed.substring(0, 1);
    if (firstChar.toLowerCase() == firstChar &&
        firstChar.toUpperCase() != firstChar) {
      return true;
    }
    return const [',', ';', ')', ']', '}', '-', '—'].contains(firstChar);
  }

  static bool _endsWithSpacingOrOpenQuote(String text) {
    if (text.isEmpty) return true;
    final lastChar = text.substring(text.length - 1);
    return RegExp(r'\s').hasMatch(lastChar) ||
        const ['(', '[', '"', "'", '“', '‘'].contains(lastChar);
  }

  static bool _startsWithSpacingOrPunctuation(String text) {
    if (text.isEmpty) return true;
    final firstChar = text.substring(0, 1);
    return RegExp(r'\s').hasMatch(firstChar) ||
        const [
          ',',
          '.',
          '!',
          '?',
          ';',
          ':',
          ')',
          ']',
          '"',
          "'",
          '”',
          '’',
          '-',
          '—',
        ].contains(firstChar);
  }

  /// Stitches inline elements (like `<a>` or formatting tags) and unwrapped
  /// runs of text back into their enclosing or adjacent `<p>` elements.
  ///
  /// Readability and DOM unwrapping often split a single prose sentence around
  /// inline links into `<p>Prefix </p><a ...>Link</a><p> suffix</p>`, creating
  /// disjointed paragraphs with jarring newlines before and after the link.
  /// This merges them into a cohesive paragraph `<p>Prefix <a ...>Link</a> suffix</p>`.
  static void _stitchInlineNodes(dom.DocumentFragment fragment) {
    void processContainer(dom.Node container) {
      var i = 0;
      while (i < container.nodes.length) {
        final node = container.nodes[i];

        if (_isInline(node)) {
          final inlineRun = <dom.Node>[];
          var j = i;
          while (j < container.nodes.length && _isInline(container.nodes[j])) {
            inlineRun.add(container.nodes[j]);
            j++;
          }

          final hasContent = inlineRun.any((n) => !_isWhitespace(n));
          if (!hasContent) {
            i = j;
            continue;
          }

          dom.Node? prev;
          for (var k = i - 1; k >= 0; k--) {
            if (!_isWhitespace(container.nodes[k])) {
              prev = container.nodes[k];
              break;
            }
          }

          dom.Node? next;
          for (var k = j; k < container.nodes.length; k++) {
            if (!_isWhitespace(container.nodes[k])) {
              next = container.nodes[k];
              break;
            }
          }

          final prevIsP = prev is dom.Element && prev.localName == 'p';
          final nextIsP = next is dom.Element && next.localName == 'p';

          final prevComplete =
              prevIsP && _endsWithTerminalPunctuation(prev.text);
          final inlineStartsContinuation = _startsWithContinuation(
            inlineRun.first.text ?? '',
          );
          final nextStartsContinuation =
              next != null && _startsWithContinuation(next.text ?? '');

          final belongsToPrev =
              prevIsP &&
              (!prevComplete ||
                  inlineStartsContinuation ||
                  (!nextIsP && next == null));

          if (belongsToPrev) {
            for (final n in inlineRun) {
              if (!_endsWithSpacingOrOpenQuote(prev.text) &&
                  !_startsWithSpacingOrPunctuation(n.text ?? '')) {
                prev.append(dom.Text(' '));
              }
              prev.append(n);
            }

            if (nextIsP) {
              final prevText = prev.text;
              final nextText = next.text;
              final shouldMerge =
                  !_endsWithTerminalPunctuation(prevText) ||
                  _startsWithContinuation(nextText);

              if (shouldMerge) {
                if (!_endsWithSpacingOrOpenQuote(prev.text) &&
                    !_startsWithSpacingOrPunctuation(next.text)) {
                  prev.append(dom.Text(' '));
                }
                next.nodes.toList().forEach(prev.append);
                next.remove();
              }
            }
            i = j;
            continue;
          } else if (nextIsP && (nextStartsContinuation || !prevIsP)) {
            for (var idx = inlineRun.length - 1; idx >= 0; idx--) {
              final n = inlineRun[idx];
              next.nodes.insert(0, n);
              if (idx == inlineRun.length - 1 &&
                  !_endsWithSpacingOrOpenQuote(n.text ?? '') &&
                  !_startsWithSpacingOrPunctuation(
                    next.text.substring(n.text?.length ?? 0),
                  )) {
                next.nodes.insert(1, dom.Text(' '));
              }
            }
            i = j;
            continue;
          } else {
            final p = dom.Element.tag('p');
            container.nodes.insert(i, p);
            inlineRun.forEach(p.append);
            i = i + 1;
            continue;
          }
        }

        if (node is dom.Element && node.localName == 'p') {
          dom.Node? next;
          for (var k = i + 1; k < container.nodes.length; k++) {
            if (!_isWhitespace(container.nodes[k])) {
              next = container.nodes[k];
              break;
            }
          }

          if (next is dom.Element && next.localName == 'p') {
            final prevText = node.text;
            final nextText = next.text;
            if (!_endsWithTerminalPunctuation(prevText) &&
                _startsWithContinuation(nextText)) {
              if (!_endsWithSpacingOrOpenQuote(node.text) &&
                  !_startsWithSpacingOrPunctuation(next.text)) {
                node.append(dom.Text(' '));
              }
              next.nodes.toList().forEach(node.append);
              next.remove();
              continue;
            }
          }
        }

        if (node is dom.Element &&
            const {
              'blockquote',
              'section',
              'article',
            }.contains(node.localName)) {
          processContainer(node);
        }

        i++;
      }
    }

    processContainer(fragment);
  }

  // ---- f. Prune -----------------------------------------------------------

  static void _prune(dom.DocumentFragment fragment) {
    // A caption with no picture is a label under nothing: the lead video's
    // caption, stranded once the embed is dropped, opened a TOI article.
    for (final caption in fragment.querySelectorAll('figcaption').toList()) {
      final figure = caption.parent;
      final besidePicture = figure?.localName == 'figure'
          ? figure!.querySelector('img') != null
          : caption.previousElementSibling?.localName == 'img';
      if (!besidePicture) caption.remove();
    }

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
