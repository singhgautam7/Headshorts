import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:headshorts/core/util/canonical_url.dart';
import 'package:headshorts/data/feed/feed_parser.dart';
import 'package:headshorts/data/feed/http_client.dart';
import 'package:headshorts/data/readability/article_cleaner.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:html_readability/html_readability.dart';
import 'package:markdown/markdown.dart' as markdown;

/// What the Reader has to work with.
sealed class Extraction {
  const new();
}

/// A body worth reading, either from a full-content feed or from on-device
/// extraction.
class ExtractedArticle extends Extraction {
  const new({
    required this.html,
    required this.byline,
    required this.wordCount,
  });

  final String html;
  final String? byline;
  final int wordCount;

  /// Reading time, at the pace the Reader's meta line quotes.
  int get minutes => (wordCount / 220).ceil().clamp(1, 999);
}

/// Extraction came back thin or empty. The Reader keeps whatever the feed gave
/// and hands off to the publisher — plainly, with no error styling.
class ThinExtraction extends Extraction {
  const new(this.reason);

  final String reason;
}

/// Reader-view parity with a browser, entirely on the device.
///
/// Nothing here is routed through a server: the page is fetched directly and
/// Mozilla's Readability heuristics run in-process.
class ExtractionService {
  const new(this._dio);

  final Dio _dio;

  /// Below this many words a heuristic result is not an article — it is a
  /// teaser, a paywall notice, or a consent page.
  static const _minimumWords = 120;

  /// A body the publisher marked as the article is held to a lower floor: a
  /// news brief is 60–90 words and complete, and calling it thin sends the
  /// reader to the page for a "rest" that does not exist.
  static const _minimumDeclaredWords = 40;

  /// Extracts [link], preferring [feedHtml] when the feed already carried the
  /// whole article.
  Future<Extraction> extract({
    required String link,
    String? feedHtml,
    String? imageUrl,
  }) async {
    if (feedHtml != null && feedHtml.trim().isNotEmpty) {
      final fromFeed = assess(normaliseToHtml(feedHtml), sourceUrl: link);
      if (fromFeed is ExtractedArticle) return fromFeed;
    }

    final String page;
    try {
      final response = await _dio.get<String>(
        link,
        options: Options(headers: pageHeaders),
      );
      if (response.statusCode != 200 || response.data == null) {
        return const ThinExtraction('The publisher did not return the page.');
      }
      page = response.data!;
    } on DioException {
      return const ThinExtraction('The publisher could not be reached.');
    }

    // Parsing a publisher's page costs hundreds of milliseconds, and it is
    // parsed twice — once to look for a declared body, once by readability.
    // Neither belongs on the thread that is animating the Reader in.
    return await compute(_extractPage, (
      page: page,
      link: link,
      imageUrl: imageUrl,
    ));
  }

  /// Extracts an already-fetched [page].
  ///
  /// [imageUrl] is the feed's picture for this story. When the body carries
  /// no copy of it but the page does — The Hindu's top picture sits outside
  /// its declared `articleBody` — the picture is put at the head of the body
  /// with the caption the page gave it, so the caption reaches the Reader
  /// and survives the cache like the rest of the body.
  static Extraction extractPage(
    String page, {
    required String link,
    String? imageUrl,
  }) {
    final doc = html_parser.parse(page);
    final extracted = _extractBody(doc, page, link: link);
    if (extracted is! ExtractedArticle || imageUrl == null) return extracted;
    if (bodyHasImage(extracted.html, imageUrl)) return extracted;

    final caption = _captionFor(doc, imageUrl);
    if (caption == null) return extracted;
    final figure = dom.Element.tag('figure')
      ..append(dom.Element.tag('img')..attributes['src'] = imageUrl)
      ..append(dom.Element.tag('figcaption')..text = caption);
    return ExtractedArticle(
      html: '${figure.outerHtml}${extracted.html}',
      byline: extracted.byline,
      wordCount: extracted.wordCount,
    );
  }

  /// A declared body first, the heuristic second.
  ///
  /// Readability is a heuristic, and a heuristic can be fooled: NDTV wraps
  /// its story in a `js-ad-section` class, which Mozilla's unlikely-candidate
  /// rule strips before scoring begins, so the page's footer wins. A
  /// schema.org `articleBody` is the publisher saying where the article is,
  /// so it is tried first and only kept if it reads as a whole article.
  static Extraction _extractBody(
    dom.Document doc,
    String page, {
    required String link,
  }) {
    final declared = doc.querySelector('[itemprop="articleBody"]')?.innerHtml;
    if (declared != null) {
      final fromDeclaration = assess(
        declared,
        sourceUrl: link,
        minimumWords: _minimumDeclaredWords,
      );
      if (fromDeclaration is ExtractedArticle) return fromDeclaration;
    }

    try {
      final result = readability(page);
      return assess(
        result.htmlContent,
        sourceUrl: link,
        plainText: result.textContent,
      );
    } on Exception {
      return const ThinExtraction(
        'On-device extraction did not find a clean body.',
      );
    }
  }

  /// The caption the page gives the picture at [imageUrl], if it shows it.
  ///
  /// The page's copy is found by identity rather than address — the feed
  /// names one size, the page another, and a lazy-loaded `<img>` may hold a
  /// spacer in `src` with the real picture in `srcset` or a `<source>`. The
  /// caption is the nearest `figcaption` or caption-classed element around
  /// it, else the picture's own `alt`.
  static String? _captionFor(dom.Document doc, String imageUrl) {
    for (final img in doc.querySelectorAll('img')) {
      final candidates = [
        img.attributes['src'],
        img.attributes['data-src'],
        img.attributes['data-original'],
        img.attributes['data-lazy-src'],
        ...?img.attributes['srcset']?.split(','),
        if (img.parent?.localName == 'picture')
          for (final source in img.parent!.querySelectorAll('source'))
            ...?source.attributes['srcset']?.split(','),
      ].map((c) => c?.trim().split(RegExp(r'\s+')).first);
      if (!candidates.any((c) => sameImage(c, imageUrl))) continue;

      var scope = img.parent;
      for (var up = 0; up < 4 && scope != null; up++, scope = scope.parent) {
        final caption = scope
            .querySelectorAll('*')
            .where(
              (e) =>
                  e.localName == 'figcaption' ||
                  RegExp(
                    'caption|cptn',
                    caseSensitive: false,
                  ).hasMatch(e.className),
            )
            .map((e) => FeedParser.plainText(e.innerHtml).trim())
            .where((t) => t.isNotEmpty && t.length < 400)
            .firstOrNull;
        if (caption != null) return caption;
      }
      final alt = img.attributes['alt']?.trim();
      return alt != null && alt.length > 20 ? alt : null;
    }
    return null;
  }

  /// Cleans [html] and decides whether what is left is an article.
  static Extraction assess(
    String html, {
    required String sourceUrl,
    String? plainText,
    int minimumWords = _minimumWords,
  }) {
    final cleaned = ArticleCleaner.clean(html, base: Uri.parse(sourceUrl));
    final text = plainText ?? FeedParser.plainText(cleaned);
    final words = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    if (words < minimumWords || cleaned.trim().isEmpty) {
      return const ThinExtraction(
        'On-device extraction did not find a clean body.',
      );
    }
    return ExtractedArticle(html: cleaned, byline: null, wordCount: words);
  }

  /// The same user agent the feed client sends, so a publisher sees one
  /// consistent visitor rather than two.
  static const userAgent = browserUserAgent;

  /// What a browser sends when a person navigates to a page.
  ///
  /// Several publishers serve a stripped, image-free document to anything
  /// that looks like a crawler, and NDTV's edge refuses the request outright
  /// unless the `Sec-Fetch-*` set, a language and an `Accept-Encoding` that
  /// names `br` are all present. Each was bisected against the live site;
  /// drop one and the answer is 403. The client inflates both encodings.
  static const pageHeaders = {
    'User-Agent': userAgent,
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
    'Accept-Language': 'en-US,en;q=0.9',
    'Accept-Encoding': 'gzip, br',
    'Sec-Fetch-Site': 'none',
    'Sec-Fetch-Mode': 'navigate',
    'Sec-Fetch-User': '?1',
    'Sec-Fetch-Dest': 'document',
  };

  /// Headers an article image has to be asked for with. Publishers routinely
  /// refuse an image whose request carries no `Referer` from their own page.
  static Map<String, String> imageHeaders(String articleUrl) => {
    'Referer': articleUrl,
    'User-Agent': userAgent,
    'Accept': 'image/webp,image/png,image/svg+xml,image/*;q=0.8,*/*;q=0.5',
  };

  /// Normalises whatever a source gave us into one HTML string.
  ///
  /// Feeds are overwhelmingly HTML, but a handful carry Markdown. Converting
  /// it up front means there is exactly one pipeline after this point rather
  /// than a second path that drifts.
  static String normaliseToHtml(String content) =>
      _looksLikeMarkdown(content) ? markdown.markdownToHtml(content) : content;

  static bool _looksLikeMarkdown(String content) {
    final trimmed = content.trimLeft();
    if (trimmed.startsWith('<')) return false;
    // A tag anywhere means the publisher is speaking HTML, however scrappy.
    if (RegExp(
      r'<(p|div|h[1-6]|br|img|a|ul|ol)\b',
      caseSensitive: false,
    ).hasMatch(content)) {
      return false;
    }
    return RegExp(
          r'^\s{0,3}(#{1,6}\s|[*-]\s|>\s)',
          multiLine: true,
        ).hasMatch(content) ||
        RegExp(r'\[[^\]]+\]\([^)]+\)').hasMatch(content);
  }
}

Extraction _extractPage(({String page, String link, String? imageUrl}) job) =>
    ExtractionService.extractPage(
      job.page,
      link: job.link,
      imageUrl: job.imageUrl,
    );
