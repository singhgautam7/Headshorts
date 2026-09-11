import 'package:dio/dio.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:headshorts/data/feed/feed_parser.dart';
import 'package:html/parser.dart' as html_parser;

part 'feed_discovery.freezed.dart';

/// A feed found behind a site address, described in the terms the add-source
/// sheet uses: what it is called, and whether it carries full articles.
@freezed
abstract class DiscoveredFeed with _$DiscoveredFeed {
  const factory({
    required String url,
    required String title,
    required bool hasFullContent,
    required int itemsPerDay,
    String? siteUrl,
  }) = _DiscoveredFeed;
}

/// The reader pastes a *site*, not a feed. This finds the feed for them.
class FeedDiscovery {
  const new(this._dio);

  final Dio _dio;

  /// Common locations to try when a page declares no feed of its own.
  static const _guesses = [
    '/feed',
    '/rss',
    '/rss.xml',
    '/feed.xml',
    '/atom.xml',
    '/index.xml',
  ];

  /// Resolves whatever the reader pasted into the feeds behind it.
  ///
  /// If the address is itself a feed, that is the single result. Otherwise the
  /// page's `<link rel="alternate">` declarations are followed, and failing
  /// that a short list of conventional paths is tried.
  Future<List<DiscoveredFeed>> discover(String input) async {
    final url = normalise(input);
    if (url == null) return const [];

    final response = await _get(url);
    if (response == null) return const [];

    final body = response.data ?? '';
    final contentType = response.headers.value('content-type') ?? '';

    if (_looksLikeFeed(contentType, body)) {
      final feed = await _describe(url, body: body);
      return feed == null ? const [] : [feed];
    }

    final candidates = _linkedFeeds(body, base: Uri.parse(url));
    if (candidates.isEmpty) {
      candidates.addAll(
        _guesses.map((p) => Uri.parse(url).resolve(p).toString()),
      );
    }

    final found = <DiscoveredFeed>[];
    for (final candidate in candidates.take(6)) {
      final feed = await _describe(candidate, siteUrl: url);
      if (feed != null) found.add(feed);
    }
    return found;
  }

  /// Accepts "thehindu.com", "https://thehindu.com/", "www.bbc.co.uk/news".
  static String? normalise(String input) {
    var value = input.trim();
    if (value.isEmpty) return null;
    if (!value.contains('://')) value = 'https://$value';
    final uri = Uri.tryParse(value);
    if (uri == null || uri.host.isEmpty) return null;
    return uri.toString();
  }

  Future<Response<String>?> _get(String url) async {
    try {
      final response = await _dio.get<String>(url);
      return response.statusCode == 200 ? response : null;
    } on DioException {
      return null;
    }
  }

  static bool _looksLikeFeed(String contentType, String body) {
    if (contentType.contains('xml') && !contentType.contains('xhtml')) {
      return true;
    }
    final head = body.trimLeft();
    return head.startsWith('<?xml') ||
        head.contains('<rss') ||
        head.contains('<feed');
  }

  static List<String> _linkedFeeds(String html, {required Uri base}) {
    const types = {
      'application/rss+xml',
      'application/atom+xml',
      'application/feed+json',
      'application/json',
    };
    return html_parser
        .parse(html)
        .querySelectorAll('link[rel~="alternate"]')
        .where((e) => types.contains(e.attributes['type']?.toLowerCase()))
        .map((e) => e.attributes['href'])
        .whereType<String>()
        .map((href) => base.resolve(href).toString())
        .toSet()
        .toList();
  }

  /// Fetches a candidate and reports what it actually contains, so the sheet
  /// can say "full articles · about 30 a day" rather than just a URL.
  Future<DiscoveredFeed?> _describe(
    String url, {
    String? body,
    String? siteUrl,
  }) async {
    final text = body ?? (await _get(url))?.data;
    if (text == null) return null;

    try {
      final articles = FeedParser.parse(text);
      if (articles.isEmpty) {
        return DiscoveredFeed(
          url: url,
          title: _feedTitle(text) ?? Uri.parse(url).host,
          hasFullContent: false,
          itemsPerDay: 0,
          siteUrl: siteUrl,
        );
      }

      final withBody = articles.where((a) => a.fullContentHtml != null).length;
      return DiscoveredFeed(
        url: url,
        title: _feedTitle(text) ?? Uri.parse(url).host,
        hasFullContent: withBody * 2 >= articles.length,
        itemsPerDay: _itemsPerDay(articles.map((a) => a.publishedAt).toList()),
        siteUrl: siteUrl,
      );
    } on FormatException {
      return null;
    }
  }

  static String? _feedTitle(String body) {
    final match = RegExp(
      '<title[^>]*>(.*?)</title>',
      dotAll: true,
      caseSensitive: false,
    ).firstMatch(body);
    final raw = match?.group(1);
    if (raw == null) return null;
    final text = FeedParser.plainText(raw);
    return text.isEmpty ? null : text;
  }

  /// A rough publishing rate, from the span the feed's own items cover.
  static int _itemsPerDay(List<DateTime> dates) {
    if (dates.length < 2) return dates.length;
    dates.sort();
    final span = dates.last.difference(dates.first);
    final days = span.inMinutes / Duration.minutesPerDay;
    if (days <= 0.5) return dates.length;
    return (dates.length / days).round().clamp(1, 999);
  }
}
