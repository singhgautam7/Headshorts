import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:headshorts/data/feed/feed_parser.dart';
import 'package:headshorts/data/feed/http_client.dart';
import 'package:headshorts/data/readability/article_cleaner.dart';
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
  Future<Extraction> extract({required String link, String? feedHtml}) async {
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
    return await compute(_extractPage, (page: page, link: link));
  }

  /// Extracts an already-fetched [page].
  static Extraction extractPage(String page, {required String link}) {
    final declared = _declaredBody(page);
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

  /// The body the publisher marked as such, when they marked one.
  ///
  /// Readability is a heuristic, and a heuristic can be fooled: NDTV wraps
  /// its story in a `js-ad-section` class, which Mozilla's unlikely-candidate
  /// rule strips before scoring begins, so the page's footer wins. A
  /// schema.org `articleBody` is the publisher saying where the article is,
  /// so it is tried first and only kept if it reads as a whole article.
  static String? _declaredBody(String page) {
    final body = html_parser
        .parse(page)
        .querySelector('[itemprop="articleBody"]');
    return body?.innerHtml;
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
    'Accept': 'image/avif,image/webp,image/*,*/*;q=0.8',
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

Extraction _extractPage(({String page, String link}) job) =>
    ExtractionService.extractPage(job.page, link: job.link);
