import 'dart:ui' show Color;

import 'package:headshorts/core/tokens/accents.dart';
import 'package:headshorts/data/db/database.dart';
import 'package:headshorts/data/feed/feed_parser.dart';
import 'package:xml/xml.dart';

/// One subscription read out of an OPML file. Folders become categories.
class OpmlEntry {
  const new({
    required this.title,
    required this.feedUrl,
    required this.category,
    this.language = 'en',
    this.siteUrl,
    this.accent,
  });

  final String title;
  final String feedUrl;
  final String category;

  /// The BCP-47 tag from the outline's `language` attribute. OPML has no
  /// language convention of its own, and neither does anyone else's exporter,
  /// so an omitted one is English — the catalog's own file states every tag.
  final String language;
  final String? siteUrl;

  /// Carried by our own files in `hsAccentDark`/`hsAccentLight`, so the
  /// design board's accents survive a round trip. Null for anyone else's
  /// OPML, where the app derives a tone instead.
  final SourceAccent? accent;
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
    // Decoded like any other plain-text field: an exporter that escaped an
    // already-escaped title ships `Books &amp;amp; Arts` as a category name.
    final title = FeedParser.plainText(
      element.getAttribute('title') ?? element.getAttribute('text') ?? '',
    );

    if (feedUrl != null && feedUrl.isNotEmpty) {
      out.add(
        OpmlEntry(
          title: title.isEmpty ? feedUrl : title,
          feedUrl: feedUrl,
          category: category,
          language: _language(element),
          siteUrl: element.getAttribute('htmlUrl')?.trim(),
          accent: _accentOf(element),
        ),
      );
      return;
    }

    // A folder: its title names the category for everything beneath it.
    final nested = title.isEmpty ? category : title;
    for (final child in element.childElements) {
      _walk(child, nested, out);
    }
  }

  static String _language(XmlElement element) {
    final tag = element.getAttribute('language')?.trim();
    return (tag == null || tag.isEmpty) ? 'en' : tag.toLowerCase();
  }

  /// Our own accent extension. A reader's OPML from another app will not
  /// carry it, which is fine — the app derives a tone in that case.
  static SourceAccent? _accentOf(XmlElement element) {
    final dark = _colour(element.getAttribute('hsAccentDark'));
    final light = _colour(element.getAttribute('hsAccentLight'));
    return (dark == null || light == null) ? null : SourceAccent(dark, light);
  }

  static Color? _colour(String? hex) {
    final value = hex?.trim().replaceFirst('#', '');
    if (value == null || value.length != 6) return null;
    final parsed = int.tryParse(value, radix: 16);
    return parsed == null ? null : Color(0xFF000000 | parsed);
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
                        'language': row.language,
                        if (row.siteUrl != null) 'htmlUrl': row.siteUrl!,
                        'hsAccentDark': _hex(row.accentDark),
                        'hsAccentLight': _hex(row.accentLight),
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

  static String _hex(int argb) =>
      '#${(argb & 0xFFFFFF).toRadixString(16).toUpperCase().padLeft(6, '0')}';
}
