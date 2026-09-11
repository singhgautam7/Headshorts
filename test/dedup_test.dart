import 'package:flutter_test/flutter_test.dart';
import 'package:headshorts/core/util/canonical_url.dart';
import 'package:headshorts/data/db/article_repository.dart';
import 'package:headshorts/data/db/database.dart';
import 'package:headshorts/data/db/tables.dart';

SourceRow _source(int id, String title) => SourceRow(
  id: id,
  title: title,
  feedUrl: 'https://example.com/$id',
  category: 'World',
  accentDark: 0xFFE39191,
  accentLight: 0xFF9C3A3C,
  type: SourceType.rss,
  enabled: true,
  sortOrder: 0,
  mutedInLatest: false,
  addedAt: DateTime(2026),
);

Headline _headline({
  required int id,
  required int sourceId,
  String link = 'https://example.com/story',
  String title = 'A headline about something that happened somewhere',
  int minutesAgo = 0,
}) => Headline(
  ArticleRow(
    id: id,
    sourceId: sourceId,
    guid: 'g$id',
    title: title,
    link: link,
    canonicalUrl: canonicalUrl(link),
    titleKey: titleFingerprint(title),
    publishedAt: DateTime(2026).subtract(Duration(minutes: minutesAgo)),
    fetchedAt: DateTime(2026),
    seenInLinger: false,
    readFull: false,
  ),
  _source(sourceId, 'Source $sourceId'),
);

void main() {
  group('canonicalUrl', () {
    test('strips tracking parameters', () {
      expect(
        canonicalUrl('https://bbc.co.uk/news/x?utm_source=twitter&at_medium=x'),
        canonicalUrl('https://bbc.co.uk/news/x'),
      );
    });

    test('ignores www, m and amp hosts, and a trailing slash', () {
      const plain = 'https://thehindu.com/news/story';
      expect(
        canonicalUrl('https://www.thehindu.com/news/story/'),
        canonicalUrl(plain),
      );
      expect(
        canonicalUrl('https://m.thehindu.com/news/story'),
        canonicalUrl(plain),
      );
      expect(
        canonicalUrl('https://thehindu.com/news/story/amp'),
        canonicalUrl(plain),
      );
    });

    test('unwraps an aggregator redirect to the publisher', () {
      expect(
        canonicalUrl(
          'https://news.google.com/rss/articles/x?url='
          'https%3A%2F%2Fbbc.co.uk%2Fnews%2Fy&hl=en',
        ),
        canonicalUrl('https://bbc.co.uk/news/y'),
      );
    });

    test('keeps parameters that choose the page', () {
      expect(
        canonicalUrl('https://example.com/read?id=42'),
        isNot(canonicalUrl('https://example.com/read?id=43')),
      );
    });

    test('does not collapse different stories', () {
      expect(
        canonicalUrl('https://bbc.co.uk/news/a'),
        isNot(canonicalUrl('https://bbc.co.uk/news/b')),
      );
    });
  });

  group('titleFingerprint', () {
    test('matches the same story worded differently', () {
      expect(
        titleFingerprint('Rail operators trial a single tap-in fare cap'),
        titleFingerprint('Single tap-in fare cap trialled by rail operators'),
      );
    });

    test('separates different stories', () {
      expect(
        titleFingerprint('Monsoon withdrawal begins ahead of schedule'),
        isNot(titleFingerprint('Shipping rates ease as transits return')),
      );
    });

    test('refuses to fingerprint a headline too short to be sure', () {
      // A false merge is worse than a duplicate.
      expect(titleFingerprint('Budget day'), '');
      expect(titleFingerprint('It is over'), '');
    });
  });

  group('dedupeStories', () {
    test('keeps the first copy of a story carried by two feeds', () {
      final items = [
        _headline(id: 1, sourceId: 1, link: 'https://bbc.co.uk/news/x'),
        _headline(
          id: 2,
          sourceId: 2,
          link: 'https://www.bbc.co.uk/news/x?utm_source=feed',
          minutesAgo: 30,
        ),
      ];

      final deduped = dedupeStories(items);

      expect(deduped, hasLength(1));
      expect(deduped.single.article.id, 1);
    });

    test('collapses the same story filed under two titles', () {
      final items = [
        _headline(
          id: 1,
          sourceId: 1,
          link: 'https://one.example/a',
          title: 'Rail operators trial a single tap-in fare cap',
        ),
        _headline(
          id: 2,
          sourceId: 2,
          link: 'https://two.example/b',
          title: 'Single tap-in fare cap trialled by rail operators',
        ),
      ];

      expect(dedupeStories(items), hasLength(1));
    });

    test('leaves genuinely different stories alone', () {
      final items = [
        _headline(
          id: 1,
          sourceId: 1,
          link: 'https://one.example/a',
          title: 'Monsoon withdrawal begins ahead of schedule',
        ),
        _headline(
          id: 2,
          sourceId: 2,
          link: 'https://two.example/b',
          title: 'Shipping rates ease as Red Sea transits return',
        ),
      ];

      expect(dedupeStories(items), hasLength(2));
    });

    test('never merges items with no keys at all', () {
      final bare = [
        for (var i = 1; i <= 3; i++)
          Headline(
            ArticleRow(
              id: i,
              sourceId: 1,
              guid: 'g$i',
              title: 'Short one',
              link: '',
              canonicalUrl: '',
              titleKey: '',
              publishedAt: DateTime(2026),
              fetchedAt: DateTime(2026),
              seenInLinger: false,
              readFull: false,
            ),
            _source(1, 'One'),
          ),
      ];

      expect(dedupeStories(bare), hasLength(3));
    });

    test('preserves order', () {
      const titles = [
        'Monsoon withdrawal begins ahead of schedule this year',
        'Shipping rates ease as Red Sea transits return to normal',
        'Rail operators trial a single tap-in fare cap',
        'School consolidation lands unevenly across the states',
      ];
      final items = [
        for (var i = 1; i <= 4; i++)
          _headline(
            id: i,
            sourceId: i,
            link: 'https://example.com/$i',
            title: titles[i - 1],
          ),
      ];

      expect(dedupeStories(items).map((h) => h.article.id), [1, 2, 3, 4]);
    });
  });

  group('capConsecutive', () {
    List<Headline> from(List<int> sourceIds) => [
      for (var i = 0; i < sourceIds.length; i++)
        _headline(
          id: i + 1,
          sourceId: sourceIds[i],
          link: 'https://example.com/$i',
        ),
    ];

    test('is off at zero, leaving order strictly chronological', () {
      final items = from([1, 1, 1, 1, 2]);
      expect(capConsecutive(items, 0), same(items));
    });

    test('moves an over-represented source down, dropping nothing', () {
      // Source 1 four times in a row, then source 2.
      final capped = capConsecutive(from([1, 1, 1, 1, 2]), 2);

      expect(capped, hasLength(5));
      expect(capped.map((h) => h.source.id), [1, 1, 2, 1, 1]);
    });

    test('leaves a list already within the cap untouched', () {
      final items = from([1, 2, 1, 2]);
      expect(capConsecutive(items, 2).map((h) => h.article.id), [1, 2, 3, 4]);
    });

    test('never loses an item, whatever the run', () {
      final items = from([1, 1, 1, 1, 1, 1, 2, 2, 3]);
      expect(capConsecutive(items, 3), hasLength(items.length));
    });
  });
}
