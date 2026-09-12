import 'package:dio/dio.dart';
import 'package:headshorts/data/feed/feed_parser.dart';
import 'package:headshorts/data/feed/http_client.dart';
import 'package:headshorts/data/readability/article_cleaner.dart';
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

  /// Below this many words the result is not an article — it is a teaser, a
  /// paywall notice, or a consent page.
  static const _minimumWords = 120;

  /// Extracts [link], preferring [feedHtml] when the feed already carried the
  /// whole article.
  Future<Extraction> extract({required String link, String? feedHtml}) async {
    if (feedHtml != null && feedHtml.trim().isNotEmpty) {
      final fromFeed = _assess(normaliseToHtml(feedHtml), sourceUrl: link);
      if (fromFeed is ExtractedArticle) return fromFeed;
    }

    final String page;
    try {
      // Ask as a desktop browser: several publishers serve a stripped,
      // image-free document to anything that looks like a crawler.
      final response = await _dio.get<String>(
        link,
        options: Options(headers: {'User-Agent': userAgent}),
      );
      if (response.statusCode != 200 || response.data == null) {
        return const ThinExtraction('The publisher did not return the page.');
      }
      page = response.data!;
    } on DioException {
      return const ThinExtraction('The publisher could not be reached.');
    }

    try {
      final result = readability(page);
      return _assess(
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

  Extraction _assess(
    String html, {
    required String sourceUrl,
    String? plainText,
  }) {
    final cleaned = ArticleCleaner.clean(html, base: Uri.parse(sourceUrl));
    final text = plainText ?? FeedParser.plainText(cleaned);
    final words = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    if (words < _minimumWords || cleaned.trim().isEmpty) {
      return const ThinExtraction(
        'On-device extraction did not find a clean body.',
      );
    }
    return ExtractedArticle(
      html: cleaned,
      byline: null,
      wordCount: words,
    );
  }

  /// The same user agent the feed client sends, so a publisher sees one
  /// consistent visitor rather than two.
  static const userAgent = browserUserAgent;

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
