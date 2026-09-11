import 'package:headshorts/data/db/database.dart';
import 'package:xml/xml.dart';

/// One subscription read out of an OPML file. Folders become categories.
class OpmlEntry {
  const new({
    required this.title,
    required this.feedUrl,
    required this.category,
    this.siteUrl,
  });

  final String title;
  final String feedUrl;
  final String category;
  final String? siteUrl;
}

/// OPML is XML with one convention on top: nested `<outline>` elements, where
/// a node without an `xmlUrl` is a folder. A thin reader and writer is all
/// this needs — no dependency earns its keep here.
abstract final class Opml {
  static const _uncategorised = 'Uncategorised';

  /// Parses an OPML document. Throws [FormatException] on anything that is
  /// not an OPML file, so the import screen can say so plainly.
  static List<OpmlEntry> parse(String xml) {
    final XmlDocument document;
    try {
      document = XmlDocument.parse(xml);
    } on XmlException catch (e) {
      throw FormatException('That file is not valid XML: ${e.message}');
    }

    final body = document.findAllElements('body').firstOrNull;
    if (body == null) {
      throw const FormatException('That file has no OPML body.');
    }

    final entries = <OpmlEntry>[];
    for (final child in body.childElements) {
      _walk(child, _uncategorised, entries);
    }
    return entries;
  }

  static void _walk(XmlElement element, String category, List<OpmlEntry> out) {
    if (element.localName != 'outline') return;

    final feedUrl = element.getAttribute('xmlUrl')?.trim();
    final title =
        element.getAttribute('title')?.trim() ??
        element.getAttribute('text')?.trim();

    if (feedUrl != null && feedUrl.isNotEmpty) {
      out.add(
        OpmlEntry(
          title: (title == null || title.isEmpty) ? feedUrl : title,
          feedUrl: feedUrl,
          category: category,
          siteUrl: element.getAttribute('htmlUrl')?.trim(),
        ),
      );
      return;
    }

    // A folder: its title names the category for everything beneath it.
    final nested = (title == null || title.isEmpty) ? category : title;
    for (final child in element.childElements) {
      _walk(child, nested, out);
    }
  }

  /// Writes the reader's subscriptions back out, grouped into folders by
  /// category so another reader imports them the way they were kept here.
  static String write(List<SourceRow> sources) {
    final byCategory = <String, List<SourceRow>>{};
    for (final source in sources) {
      byCategory.putIfAbsent(source.category, () => []).add(source);
    }

    final builder = XmlBuilder()
      ..processing('xml', 'version="1.0" encoding="UTF-8"');
    builder.element(
      'opml',
      attributes: {'version': '2.0'},
      nest: () {
        builder.element(
          'head',
          nest: () {
            builder
              ..element('title', nest: 'HeadShorts subscriptions')
              ..element(
                'dateCreated',
                nest: DateTime.now().toUtc().toIso8601String(),
              );
          },
        );
        builder.element(
          'body',
          nest: () {
            byCategory.forEach((category, rows) {
              builder.element(
                'outline',
                attributes: {'text': category, 'title': category},
                nest: () {
                  for (final row in rows) {
                    builder.element(
                      'outline',
                      attributes: {
                        'type': 'rss',
                        'text': row.title,
                        'title': row.title,
                        'xmlUrl': row.feedUrl,
                        if (row.siteUrl != null) 'htmlUrl': row.siteUrl!,
                      },
                    );
                  }
                },
              );
            });
          },
        );
      },
    );
    return builder.buildDocument().toXmlString(pretty: true, indent: '  ');
  }
}
