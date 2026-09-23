import 'package:flutter_test/flutter_test.dart';
import 'package:headshorts/data/db/database.dart';
import 'package:headshorts/data/db/tables.dart';
import 'package:headshorts/data/sources/opml.dart';

const _opml = '''
<?xml version="1.0" encoding="UTF-8"?>
<opml version="2.0">
  <head><title>feedly-export</title></head>
  <body>
    <outline text="India" title="India">
      <outline type="rss" text="The Hindu" xmlUrl="https://thehindu.com/rss"
               htmlUrl="https://thehindu.com"/>
      <outline type="rss" text="Scroll.in" xmlUrl="https://scroll.in/feed"/>
    </outline>
    <outline type="rss" text="Loose feed" xmlUrl="https://example.com/loose"/>
  </body>
</opml>
''';

SourceRow _source(String title, String category) => SourceRow(
  id: 1,
  title: title,
  feedUrl: 'https://example.com/${title.toLowerCase()}',
  siteUrl: 'https://example.com',
  category: category,
  language: 'en',
  accentDark: 0xFFE4A868,
  accentLight: 0xFF8A5518,
  type: SourceType.rss,
  enabled: true,
  sortOrder: 0,
  mutedInLatest: false,
  addedAt: DateTime(2026),
);

void main() {
  group('Opml.parse', () {
    test('turns folders into categories', () {
      final entries = Opml.parse(_opml);

      expect(entries, hasLength(3));
      expect(entries[0].title, 'The Hindu');
      expect(entries[0].category, 'India');
      expect(entries[0].siteUrl, 'https://thehindu.com');
      expect(entries[1].category, 'India');
    });

    test('keeps a feed that sits outside any folder', () {
      expect(Opml.parse(_opml).last.category, 'Uncategorised');
    });

    test('rejects a file that is not OPML', () {
      expect(() => Opml.parse('<html/>'), throwsFormatException);
      expect(() => Opml.parse('not xml at all'), throwsFormatException);
    });
  });

  group('Opml.write', () {
    test('round-trips through parse', () {
      final written = Opml.write([
        _source('The Hindu', 'India'),
        _source('BBC News', 'World'),
      ]);

      final entries = Opml.parse(written);
      expect(entries, hasLength(2));
      expect(
        entries.map((e) => e.category),
        unorderedEquals(['India', 'World']),
      );
      expect(
        entries.map((e) => e.title),
        unorderedEquals(['The Hindu', 'BBC News']),
      );
    });
  });
}
