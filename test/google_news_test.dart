import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:headshorts/data/feed/google_news_search.dart';

/// Reading what Google News actually returns.
///
/// The fixture is a real response, trimmed to five items — the endpoint is
/// unofficial and undocumented, so a hand-written sample would only ever
/// prove that the parser reads hand-written samples.
void main() {
  late final feed = File('test/fixtures/google_news_search.xml')
      .readAsStringSync();

  group('parsing', () {
    test('reads every item', () {
      expect(GoogleNewsSearch.parse(feed), hasLength(5));
    });

    test('names the publisher from the source element', () {
      final results = GoogleNewsSearch.parse(feed);
      expect(results.first.publisher, 'News On AIR');
      expect(results.map((r) => r.publisher), everyElement(isNotEmpty));
    });

    test('drops the publisher Google appends to every headline', () {
      final first = GoogleNewsSearch.parse(feed).first;
      expect(first.title, 'Nepali Congress leader Deepak Khadka arrested');
      expect(
        first.title,
        isNot(contains(' - News On AIR')),
        reason: 'the card prints the publisher above the headline already',
      );
    });

    test('keeps the link and the date', () {
      final first = GoogleNewsSearch.parse(feed).first;
      expect(first.link, startsWith('https://news.google.com/rss/articles/'));
      expect(first.publishedAt.year, 2026);
    });

    test('a document that is not a feed is no results, not a crash', () {
      expect(GoogleNewsSearch.parse('<html>nope</html>'), isEmpty);
      expect(GoogleNewsSearch.parse('not xml at all <<<'), isEmpty);
      expect(GoogleNewsSearch.parse(''), isEmpty);
    });
  });

  group('stripping the publisher', () {
    test('removes only the trailing publisher', () {
      expect(
        GoogleNewsSearch.stripPublisher('A headline - The Hindu', 'The Hindu'),
        'A headline',
      );
    });

    test("leaves a headline's own dashes alone", () {
      // Real headlines are full of dashes; only the suffix is Google's.
      expect(
        GoogleNewsSearch.stripPublisher(
          'Budget 2026 - what it means - Mint',
          'Mint',
        ),
        'Budget 2026 - what it means',
      );
      expect(
        GoogleNewsSearch.stripPublisher('India - Pakistan talks resume', 'BBC'),
        'India - Pakistan talks resume',
      );
    });

    test('a publisher named mid-headline is not touched', () {
      expect(
        GoogleNewsSearch.stripPublisher('The Hindu - turns 150', 'The Hindu'),
        'The Hindu - turns 150',
      );
    });

    test('an unnamed publisher leaves the title as it is', () {
      expect(GoogleNewsSearch.stripPublisher('A headline', ''), 'A headline');
    });
  });
}
