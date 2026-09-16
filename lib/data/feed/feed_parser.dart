import 'package:dart_rss/dart_rss.dart';
import 'package:headshorts/data/sources/source_adapter.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:intl/intl.dart';
import 'package:xml/xml.dart';

/// Turns a feed document into [ParsedArticle]s, whatever dialect it speaks.
///
/// Pure and synchronous: everything here is exercised by unit tests without a
/// network or a database.
abstract final class FeedParser {
  /// Sniffs RSS 2.0, RSS 1.0 (RDF) and Atom, then parses accordingly.
  ///
  /// Throws [FormatException] when the document is not a feed at all.
  static List<ParsedArticle> parse(String body) {
    final XmlDocument document;
    try {
      document = XmlDocument.parse(body);
    } on XmlException catch (e) {
      throw FormatException('Not XML: ${e.message}');
    }

    final root = document.rootElement.name.local.toLowerCase();
    if (root == 'feed') return _fromAtom(AtomFeed.parse(body));
    if (root == 'rdf') return _fromRss1(Rss1Feed.parse(body));
    if (root == 'rss') return _fromRss2(RssFeed.parse(body));
    throw FormatException('Unrecognised feed root element <$root>');
  }

  static List<ParsedArticle> _fromRss2(RssFeed feed) {
    final out = <ParsedArticle>[];
    for (final item in feed.items) {
      final link = item.link?.trim();
      final guid = _firstNonEmpty([item.guid, link]);
      if (guid == null || link == null || link.isEmpty) continue;

      // `content:encoded` is a full-content feed handing us the article body;
      // `description` is usually a summary. Treat them differently.
      final content = item.content?.value.trim();
      final description = item.description?.trim();

      out.add(
        ParsedArticle(
          guid: guid,
          title: _text(item.title) ?? 'Untitled',
          link: link,
          publishedAt:
              parseDate(item.pubDate) ??
              parseDate(item.dc?.date) ??
              DateTime.now(),
          summary: _snippet(description),
          contentSnippet: _snippet(content ?? description),
          fullContentHtml: _fullContent(content),
          author: _cleanAuthor(
            _firstNonEmpty([item.dc?.creator, item.author]),
          ),
          imageUrl: _imageFromRss(item),
        ),
      );
    }
    return out;
  }

  static List<ParsedArticle> _fromRss1(Rss1Feed feed) {
    final out = <ParsedArticle>[];
    for (final item in feed.items) {
      final link = item.link?.trim();
      if (link == null || link.isEmpty) continue;
      final content = item.content?.value.trim();
      out.add(
        ParsedArticle(
          guid: link,
          title: _text(item.title) ?? 'Untitled',
          link: link,
          publishedAt: parseDate(item.dc?.date) ?? DateTime.now(),
          summary: _snippet(item.description),
          contentSnippet: _snippet(content ?? item.description),
          fullContentHtml: _fullContent(content),
          author: _cleanAuthor(item.dc?.creator),
        ),
      );
    }
    return out;
  }

  static List<ParsedArticle> _fromAtom(AtomFeed feed) {
    final out = <ParsedArticle>[];
    for (final item in feed.items) {
      final link = _atomLink(item);
      final guid = _firstNonEmpty([item.id, link]);
      if (guid == null || link == null) continue;
      final content = item.content?.trim();

      out.add(
        ParsedArticle(
          guid: guid,
          title: _text(item.title) ?? 'Untitled',
          link: link,
          publishedAt:
              parseDate(item.published) ??
              parseDate(item.updated) ??
              DateTime.now(),
          summary: _snippet(item.summary),
          contentSnippet: _snippet(content ?? item.summary),
          fullContentHtml: _fullContent(content),
          author: _cleanAuthor(
            _firstNonEmpty([
              item.authors.firstOrNull?.name,
              item.authors.firstOrNull?.email,
            ]),
          ),
          imageUrl: item.media?.thumbnails.firstOrNull?.url,
        ),
      );
    }
    return out;
  }

  static String? _atomLink(AtomItem item) {
    final links = item.links;
    final alternate = links.where((l) => l.rel == 'alternate' || l.rel == null);
    final href = (alternate.firstOrNull ?? links.firstOrNull)?.href?.trim();
    return (href == null || href.isEmpty) ? null : href;
  }

  static String? _imageFromRss(RssItem item) {
    final thumb = item.media?.thumbnails.firstOrNull?.url;
    if (thumb != null && thumb.isNotEmpty) return thumb;
    final content = item.media?.contents
        .where((c) => (c.medium ?? 'image') == 'image')
        .firstOrNull
        ?.url;
    if (content != null && content.isNotEmpty) return content;
    final enclosure = item.enclosure;
    if (enclosure != null && (enclosure.type ?? '').startsWith('image/')) {
      return enclosure.url;
    }
    return null;
  }

  /// Only keep markup as "full content" when there is enough of it to be an
  /// article. A two-sentence teaser wrapped in `<p>` is still a summary.
  static String? _fullContent(String? html) {
    if (html == null || html.isEmpty) return null;
    return plainText(html).length >= _fullContentThreshold ? html : null;
  }

  static const _fullContentThreshold = 900;

  static String? _snippet(String? html) {
    if (html == null) return null;
    final text = plainText(html);
    return text.isEmpty ? null : text;
  }

  /// Strips markup, decodes entities and collapses whitespace — feeds
  /// routinely put HTML in fields that are meant to be plain text.
  ///
  /// Entities are decoded until the text stops changing, at most [_maxDecodes]
  /// times. Publishers that escape an already-escaped field ship `&amp;amp;`,
  /// and one pass leaves a visible `&amp;` in the headline.
  static String plainText(String html) {
    var text = html;
    for (var pass = 0; pass < _maxDecodes; pass++) {
      final decoded = html_parser.parseFragment(text).text ?? '';
      if (decoded == text) break;
      text = decoded;
      if (!_entity.hasMatch(text)) break;
    }
    return text.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// Two rounds handles single and double encoding. A third would only ever
  /// mangle prose that legitimately contains something entity-shaped.
  static const _maxDecodes = 2;

  static final _entity = RegExp(
    r'&(#\d+|#[xX][0-9a-fA-F]+|[a-zA-Z][a-zA-Z0-9]{1,31});',
  );

  /// A plain-text field: markup out, entities decoded, empty means absent.
  static String? _text(String? value) {
    if (value == null) return null;
    final text = plainText(value);
    return text.isEmpty ? null : text;
  }

  /// Cleans an author string: removes wrapping parentheses if formatted like
  /// `user@example.com (Author Name)`, strips leading "by " / "By ", and
  /// strips HTML tags and entities.
  static String? _cleanAuthor(String? raw) {
    if (raw == null) return null;
    var text = plainText(raw);
    if (text.isEmpty) return null;

    final parenMatch = RegExp(r'\(([^)]+)\)').firstMatch(text);
    if (parenMatch != null && text.contains('@')) {
      text = parenMatch.group(1)!.trim();
    }
    if (text.toLowerCase().startsWith('by ')) {
      text = text.substring(3).trim();
    }
    return text.isEmpty ? null : text;
  }

  static String? _firstNonEmpty(List<String?> candidates) {
    for (final c in candidates) {
      final t = c?.trim();
      if (t != null && t.isNotEmpty) return t;
    }
    return null;
  }

  static final _rfc822 = [
    DateFormat('EEE, dd MMM yyyy HH:mm:ss', 'en_US'),
    DateFormat('dd MMM yyyy HH:mm:ss', 'en_US'),
    DateFormat('EEE, dd MMM yyyy HH:mm', 'en_US'),
  ];

  /// Feeds date things in RFC 822, ISO 8601, and a long tail of near-misses.
  static DateTime? parseDate(String? raw) {
    final value = raw?.trim();
    if (value == null || value.isEmpty) return null;

    final iso = DateTime.tryParse(value);
    if (iso != null) return iso.toLocal();

    // RFC 822 dates end in a zone: "+0530", "GMT", "IST".
    final match = RegExp(r'^(.*?)\s*([+-]\d{4}|[A-Z]{2,4})?$')
        .firstMatch(value);
    final head = (match?.group(1) ?? value).trim();
    final zone = match?.group(2);

    for (final format in _rfc822) {
      try {
        final parsed = format.parseLoose(head, true);
        return _applyZone(parsed, zone).toLocal();
      } on FormatException {
        continue;
      }
    }
    return null;
  }

  static DateTime _applyZone(DateTime utcWallClock, String? zone) {
    if (zone == null || zone.isEmpty) return utcWallClock;
    final numeric = RegExp(r'^([+-])(\d{2})(\d{2})$').firstMatch(zone);
    if (numeric == null) return utcWallClock;
    final sign = numeric.group(1) == '-' ? -1 : 1;
    final offset = Duration(
      hours: int.parse(numeric.group(2)!),
      minutes: int.parse(numeric.group(3)!),
    );
    return utcWallClock.subtract(offset * sign);
  }
}
