import 'package:flutter_test/flutter_test.dart';
import 'package:headshorts/data/feed/feed_parser.dart';
import 'package:headshorts/data/sources/source_adapter.dart';

const _rss2 = '''
<?xml version="1.0"?>
<rss version="2.0" xmlns:content="http://purl.org/rss/1.0/modules/content/"
     xmlns:media="http://search.yahoo.com/mrss/">
  <channel>
    <title>The Hindu</title>
    <item>
      <title>Monsoon withdrawal begins ahead of schedule</title>
      <link>https://example.com/monsoon</link>
      <guid>tag:example.com,2026:monsoon</guid>
      <pubDate>Mon, 08 Sep 2026 04:12:00 +0530</pubDate>
      <description>&lt;p&gt;Weather office data shows the retreat.&lt;/p&gt;</description>
      <media:thumbnail url="https://example.com/monsoon.jpg"/>
    </item>
    <item>
      <title>A full-content item</title>
      <link>https://example.com/full</link>
      <pubDate>Mon, 08 Sep 2026 02:00:00 GMT</pubDate>
      <description>Teaser only.</description>
      <content:encoded>&lt;p&gt;BODY BODY BODY. &lt;/p&gt;</content:encoded>
    </item>
  </channel>
</rss>
''';

const _atom = '''
<?xml version="1.0"?>
<feed xmlns="http://www.w3.org/2005/Atom">
  <title>Ars Technica</title>
  <entry>
    <id>urn:uuid:1</id>
    <title>On-device model updates</title>
    <link rel="alternate" href="https://example.com/ars"/>
    <published>2026-09-08T06:00:00Z</published>
    <summary>What actually changed this year.</summary>
  </entry>
</feed>
''';

void main() {
  _entityDecoding();
  group('FeedParser', () {
    test('parses RSS 2.0 items with guid, date and media thumbnail', () {
      final articles = FeedParser.parse(_rss2);

      expect(articles, hasLength(2));
      final first = articles.first;
      expect(first.guid, 'tag:example.com,2026:monsoon');
      expect(first.title, 'Monsoon withdrawal begins ahead of schedule');
      expect(first.imageUrl, 'https://example.com/monsoon.jpg');
      // Markup is stripped from fields meant to be plain text.
      expect(first.summary, 'Weather office data shows the retreat.');
      // 04:12 +0530 is 22:42 UTC on the previous day.
      expect(first.publishedAt.toUtc().hour, 22);
      expect(first.publishedAt.toUtc().day, 7);
    });

    test('falls back to the link when an item has no guid', () {
      expect(FeedParser.parse(_rss2)[1].guid, 'https://example.com/full');
    });

    test('treats a short content:encoded as a summary, not a full body', () {
      // A teaser wrapped in <p> is still a teaser; the Reader must extract.
      expect(FeedParser.parse(_rss2)[1].fullContentHtml, isNull);
    });

    test('keeps a long content:encoded as the article body', () {
      final long = _rss2.replaceFirst(
        '&lt;p&gt;BODY BODY BODY. &lt;/p&gt;',
        '&lt;p&gt;${'word ' * 400}&lt;/p&gt;',
      );
      expect(FeedParser.parse(long)[1].fullContentHtml, isNotNull);
    });

    test('parses Atom entries via the alternate link', () {
      final articles = FeedParser.parse(_atom);

      expect(articles, hasLength(1));
      expect(articles.single.link, 'https://example.com/ars');
      expect(articles.single.guid, 'urn:uuid:1');
      expect(articles.single.publishedAt.toUtc().hour, 6);
    });

    test('rejects a document that is not a feed', () {
      expect(
        () => FeedParser.parse('<html><body>Not a feed</body></html>'),
        throwsFormatException,
      );
      expect(() => FeedParser.parse('nonsense'), throwsFormatException);
    });

    group('parseDate', () {
      test('reads ISO 8601', () {
        expect(FeedParser.parseDate('2026-09-08T06:00:00Z')!.toUtc().hour, 6);
      });

      test('reads RFC 822 with a numeric offset', () {
        expect(
          FeedParser.parseDate('Mon, 08 Sep 2026 04:12:00 +0530')!.toUtc().hour,
          22,
        );
      });

      test('returns null rather than guessing', () {
        expect(FeedParser.parseDate('sometime last week'), isNull);
        expect(FeedParser.parseDate(null), isNull);
        expect(FeedParser.parseDate('  '), isNull);
      });
    });
  });
}

void _entityDecoding() {
  group('entity decoding', () {
    List<ParsedArticle> parse(String title, {String description = 'A body.'}) =>
        FeedParser.parse('''
<rss version="2.0"><channel><title>T</title>
  <item>
    <guid>g1</guid>
    <link>https://example.com/a</link>
    <title>$title</title>
    <description>$description</description>
    <author>Jane O&amp;#39;Neill</author>
  </item>
</channel></rss>''');

    test('decodes named and numeric entities in a headline', () {
      final item = parse(
        'Fish &amp; chips: the PM&#39;s &quot;plan&quot; for &lt;2030',
      ).single;

      expect(item.title, 'Fish & chips: the PM\'s "plan" for <2030');
      expect(item.title, isNot(contains('&amp;')));
    });

    test('decodes a doubly-encoded field', () {
      // A publisher that escaped an already-escaped string. One pass leaves a
      // visible `&amp;` in the headline.
      final item = parse('Arts &amp;amp; Letters, &amp;#39;96').single;

      expect(item.title, "Arts & Letters, '96");
    });

    test('decodes at most twice, so real text survives', () {
      // The XML layer has already decoded once by the time a field reaches
      // us, so a feed field is effectively decoded three deep. Past that,
      // decoding forever would mangle prose that merely reads like an entity.
      expect(
        FeedParser.plainText('Tom &amp;amp;amp; Jerry'),
        'Tom &amp; Jerry',
      );
      expect(FeedParser.plainText('Tom &amp;amp; Jerry'), 'Tom & Jerry');
      expect(FeedParser.plainText('Tom & Jerry'), 'Tom & Jerry');
    });

    test('decodes the summary and the author too', () {
      final item = parse(
        'A headline',
        description: 'Delays at Heathrow &amp; Gatwick cost &#163;4m.',
      ).single;

      expect(item.summary, 'Delays at Heathrow & Gatwick cost £4m.');
      expect(item.author, "Jane O'Neill");
    });

    test('leaves a full-content body as markup for the Reader to parse', () {
      final body =
          '<p>${'Long enough to count as an article. ' * 40}</p>'
          '<p>Fish &amp; chips.</p>';
      final item = FeedParser.parse('''
<rss version="2.0" xmlns:content="http://purl.org/rss/1.0/modules/content/">
<channel><title>T</title>
  <item>
    <guid>g1</guid>
    <link>https://example.com/a</link>
    <title>A headline</title>
    <content:encoded><![CDATA[$body]]></content:encoded>
  </item>
</channel></rss>''').single;

      // The Reader's own pipeline parses this; decoding it here would break
      // the markup.
      expect(item.fullContentHtml, contains('<p>'));
      expect(item.fullContentHtml, contains('&amp;'));
    });
  });
}
