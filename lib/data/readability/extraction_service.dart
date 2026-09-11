import 'package:dio/dio.dart';
import 'package:headshorts/data/feed/feed_parser.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:html_readability/html_readability.dart';

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
      final fromFeed = _assess(feedHtml, sourceUrl: link);
      if (fromFeed is ExtractedArticle) return fromFeed;
    }

    final String page;
    try {
      final response = await _dio.get<String>(link);
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
    final text = plainText ?? FeedParser.plainText(html);
    final words = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    if (words < _minimumWords) {
      return const ThinExtraction(
        'On-device extraction did not find a clean body.',
      );
    }
    return ExtractedArticle(
      html: normaliseArticleHtml(html, base: Uri.parse(sourceUrl)),
      byline: null,
      wordCount: words,
    );
  }

  /// Attributes publishers hide the real image behind while a 1×1 spacer sits
  /// in `src`. Promoting one of these is what makes lazy-loaded article
  /// images appear at all.
  static const _lazyAttributes = [
    'data-original',
    'data-src',
    'data-lazy-src',
    'data-original-src',
  ];

  /// Markup a publisher serves is not markup a reader can lay out.
  ///
  /// This resolves relative URLs against the article, promotes lazy-loaded
  /// images into `src`, unwraps `<picture>` (which has no layout meaning
  /// here), and drops the spacer images that would otherwise be stretched to
  /// full width and leave a page-high hole in the middle of the article.
  static String normaliseArticleHtml(String html, {required Uri base}) {
    final fragment = html_parser.parseFragment(html);

    for (final picture in fragment.querySelectorAll('picture')) {
      final image = picture.querySelector('img');
      if (image == null) {
        picture.remove();
      } else {
        picture.replaceWith(image);
      }
    }

    for (final image in fragment.querySelectorAll('img')) {
      for (final attribute in _lazyAttributes) {
        final value = image.attributes[attribute];
        if (value != null && value.isNotEmpty && !_isSpacer(value)) {
          image.attributes['src'] = value;
          break;
        }
      }

      final src = image.attributes['src'];
      if (src == null || src.isEmpty || _isSpacer(src)) {
        // A spacer carries no information, and laying it out costs a screen.
        image.remove();
      }
    }

    for (final element in fragment.querySelectorAll('img, a, source')) {
      for (final attribute in const ['src', 'href', 'srcset']) {
        final value = element.attributes[attribute];
        if (value == null || value.isEmpty || value.startsWith('data:')) {
          continue;
        }
        element.attributes[attribute] = attribute == 'srcset'
            ? value
                  .split(',')
                  .map((part) => _resolveCandidate(part, base))
                  .join(', ')
            : base.resolve(value).toString();
      }
    }

    return _serialise(fragment);
  }

  static bool _isSpacer(String url) {
    final lower = url.toLowerCase();
    return lower.startsWith('data:') ||
        lower.contains('spacer') ||
        lower.contains('1x1') ||
        lower.contains('blank.gif') ||
        lower.contains('placeholder');
  }

  static String _resolveCandidate(String candidate, Uri base) {
    final parts = candidate.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return candidate;
    parts[0] = base.resolve(parts.first).toString();
    return parts.join(' ');
  }

  static String _serialise(dom.DocumentFragment fragment) => fragment.nodes
      .map((n) => n is dom.Element ? n.outerHtml : n.text ?? '')
      .join();
}
