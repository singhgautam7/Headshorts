import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show immutable;
import 'package:headshorts/data/feed/feed_parser.dart';
import 'package:xml/xml.dart';

/// One result from Google News.
///
/// Deliberately **not** a `ParsedArticle`: nothing here is ever stored, it has
/// no source of the reader's, and its link is a Google redirect rather than
/// the publisher's address. Keeping it a separate type is what stops it
/// drifting into the briefing by accident.
@immutable
class WebResult {
  const new({
    required this.title,
    required this.publisher,
    required this.link,
    required this.publishedAt,
  });

  final String title;

  /// The publisher Google names, which is the only attribution there is.
  final String publisher;

  /// A `news.google.com` redirect. It resolves in a browser and nowhere else,
  /// so these results open in a Custom Tab rather than in the Reader.
  final String link;

  final DateTime publishedAt;
}

/// Searches Google News' public RSS endpoint.
///
/// The one thing in this app that looks beyond the reader's own feeds. It
/// exists because a feed carries only its most recent items: a name or a
/// subject that no subscribed publisher happened to run in the last few days
/// cannot be found in the cache, and re-fetching the same feeds does not help.
///
/// **The query leaves the device.** That is the whole cost of it, it is the
/// only thing in HeadShorts that does, and it is stated on the results, in
/// Privacy, and behind a setting that turns it off.
///
/// Unofficial: Google publishes no contract for this endpoint. A failure is
/// therefore ordinary — the reader's own results still stand on their own,
/// and the web group simply does not appear.
class GoogleNewsSearch {
  const new(this._client);

  final Dio _client;

  static const _endpoint = 'https://news.google.com/rss/search';

  /// How long the web is given before the reader's own results go up without
  /// it. Shorter than a feed fetch: this is the extra, not the substance.
  static const timeout = Duration(seconds: 6);

  /// At most this many, so one query cannot flood the reader's own results.
  static const limit = 25;

  Future<List<WebResult>> search(String query, {DateTime? since}) async {
    final terms = query.trim();
    if (terms.isEmpty) return const [];

    try {
      final response = await _client.get<String>(
        _endpoint,
        queryParameters: <String, String>{
          // `when:` narrows at Google's end, so a "past week" search does not
          // pull a year of results back to throw most of them away.
          'q': [terms, ?_window(since)].join(' '),
          'hl': 'en-IN',
          'gl': 'IN',
          'ceid': 'IN:en',
        },
        options: Options(responseType: ResponseType.plain),
      );

      final body = response.data;
      if (body == null || body.isEmpty) return const [];
      return parse(body).take(limit).toList();
    } on Object catch (_) {
      // The web is the extra. Losing it costs the reader nothing they had.
      return const [];
    }
  }

  /// Google's own coarse recency filter. Anything longer than a month is left
  /// off: the endpoint's older results thin out badly, and a date range is
  /// applied again on what comes back anyway.
  static String? _window(DateTime? since) {
    if (since == null) return null;
    final days = DateTime.now().difference(since).inDays;
    if (days <= 1) return 'when:1d';
    if (days <= 7) return 'when:7d';
    if (days <= 31) return 'when:1m';
    return null;
  }

  /// Reads the feed Google returns.
  ///
  /// Its own parse rather than [FeedParser]'s, for two fields that only this
  /// endpoint has: the `<source>` element naming the publisher, and a title
  /// that repeats that publisher after a trailing dash.
  static List<WebResult> parse(String xml) {
    final XmlDocument document;
    try {
      document = XmlDocument.parse(xml);
    } on XmlException catch (_) {
      return const [];
    }

    final out = <WebResult>[];
    for (final item in document.findAllElements('item')) {
      final link = item.getElement('link')?.innerText.trim() ?? '';
      final rawTitle = FeedParser.plainText(
        item.getElement('title')?.innerText ?? '',
      );
      if (link.isEmpty || rawTitle.isEmpty) continue;

      final publisher = FeedParser.plainText(
        item.getElement('source')?.innerText ?? '',
      );
      final published =
          FeedParser.parseDate(item.getElement('pubDate')?.innerText) ??
          DateTime.now();

      out.add(
        WebResult(
          title: stripPublisher(rawTitle, publisher),
          publisher: publisher.isEmpty ? 'Google News' : publisher,
          link: link,
          publishedAt: published,
        ),
      );
    }
    return out;
  }

  /// Google appends " - Publisher" to every headline. The card already names
  /// the publisher above the headline, so leaving it in prints it twice.
  ///
  /// Only the trailing occurrence, and only when it is the publisher: plenty
  /// of real headlines contain a dash of their own.
  static String stripPublisher(String title, String publisher) {
    if (publisher.isEmpty) return title;
    final suffix = ' - $publisher';
    return title.endsWith(suffix)
        ? title.substring(0, title.length - suffix.length).trim()
        : title;
  }
}
