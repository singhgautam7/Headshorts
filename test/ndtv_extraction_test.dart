import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:headshorts/core/util/canonical_url.dart';
import 'package:headshorts/data/feed/feed_parser.dart';
import 'package:headshorts/data/readability/article_cleaner.dart';
import 'package:headshorts/data/readability/extraction_service.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:html_readability/html_readability.dart';

/// A real NDTV page as served to a browser: the story collapsed behind a
/// "Show full article" toggle, ad slots and widgets threaded between its
/// paragraphs, and the body wrapper classed `js-ad-section`.
void main() {
  final page = File('test/fixtures/ndtv_collapsed.html').readAsStringSync();
  final base = Uri.parse(
    'https://www.ndtv.com/world-news/day-after-talks-in-delhi-iran-says-it-wants-to-turn-the-page-with-uae-12041274',
  );

  const opening = 'In a big sign of diplomatic progress';
  const closing = 'New Delhi Declaration 2026';
  const junk = [
    'Show full article',
    'MIDTABOOLA',
    'VuukleAD',
    'Story Text',
    'Quick Read',
    'Got a follow',
    'Advertisement',
    'Related News',
    'Trending News',
    'Follow us',
    'Track Latest News',
    'Read Time',
    'WhatsApp',
    'Quick Links',
  ];

  int words(String html) =>
      FeedParser.plainText(html)
          .split(RegExp(r'\s+'))
          .where((w) => w.isNotEmpty)
          .length;

  dom.DocumentFragment parse(String html) => html_parser.parseFragment(html);

  test('the fixture really is the hard case', () {
    // Guards the test itself: if the fixture stops carrying the collapse,
    // the ad markers and the ad-classed wrapper, the assertions below stop
    // meaning anything.
    expect(page, contains('Art-exp_cn'));
    expect(page, contains('Show full article'));
    expect(page, contains('<!--MIDTABOOLA-->'));
    expect(page, contains('js-ad-section'));
    expect(page, contains(opening));
    expect(page, contains(closing));
  });

  group('through readability, as the Reader runs it', () {
    late final cleaned = ArticleCleaner.clean(
      readability(page).htmlContent,
      base: base,
    );
    late final text = parse(cleaned).text!;

    test('the collapsed body comes through whole and continuous', () {
      expect(text, contains(opening));
      expect(text, contains(closing));
      expect(parse(cleaned).querySelectorAll('p').length, 12);
      expect(parse(cleaned).querySelectorAll('h3').length, 2);
      expect(words(cleaned), greaterThan(400));
    });

    test('ads, widgets and the toggle are gone', () {
      for (final marker in junk) {
        expect(text, isNot(contains(marker)), reason: marker);
      }
    });
  });

  group('through the service, as the Reader runs it', () {
    late final result = ExtractionService.extractPage(
      page,
      link: base.toString(),
    );

    test('ships a whole body, not a thin one', () {
      expect(result, isA<ExtractedArticle>());
      final html = (result as ExtractedArticle).html;
      final text = parse(html).text!;
      expect(text, contains(opening));
      expect(text, contains(closing));
      expect(words(html), greaterThan(400));
      for (final marker in junk) {
        expect(text, isNot(contains(marker)), reason: marker);
      }
    });
  });

  group('when the whole article wrapper is what arrives', () {
    // Readability can hand back a wider container than the story div, and
    // NDTV's is classed `js-ad-section`. The ad rule must not eat it.
    late final wrapper = html_parser
        .parse(page)
        .querySelector('article')!
        .outerHtml;
    late final cleaned = ArticleCleaner.clean(wrapper, base: base);
    late final text = parse(cleaned).text!;

    test('keeps the article', () {
      expect(text, contains(opening));
      expect(text, contains(closing));
      expect(words(cleaned), greaterThan(400));
    });

    test('still strips the junk around it', () {
      for (final marker in junk) {
        expect(text, isNot(contains(marker)), reason: marker);
      }
    });
  });

  test('a comment never becomes prose', () {
    expect(
      ArticleCleaner.clean('<p>One.</p><!--AD-SLOT--><p>Two.</p>', base: base),
      isNot(contains('AD-SLOT')),
    );
  });

  test('a declared body that is a short brief is the whole article', () {
    // 60 words in an articleBody: a complete brief, not a teaser.
    final brief = List.filled(
      6,
      'Ten words of a news brief that is complete here.',
    ).join(' ');
    final page =
        '<html><body><nav>Home World</nav> '
        '<div itemprop="articleBody"><p>$brief</p></div> '
        '<footer>About Us Advertise Channels</footer></body></html>';
    expect(
      ExtractionService.extractPage(page, link: 'https://example.com/a'),
      isA<ExtractedArticle>(),
    );
  });

  group("the feed's picture and the page's caption for it", () {
    // The Hindu: the top picture, with its caption, sits outside the
    // declared articleBody; the <img> holds a spacer and the real address is
    // in a <source>; the feed names the same picture at another size.
    const page =
        '<html><body>'
        '<div class="article-picture"><div class="picture"><picture> '
        '<source srcset="https://th-i.example.com/incoming/x/article1.ece/alternates/LANDSCAPE_1200/KEJRIWAL.jpg 1200w"> '
        '<img src="https://example.com/theme/1x1_spacer.png" alt="Arvind Kejriwal. File"> '
        '</picture></div><p class="caption"> Arvind Kejriwal. File | Photo Credit: The Hindu </p></div> '
        '<div itemprop="articleBody"> '
        '<p>AAP national convener Arvind Kejriwal on Tuesday slammed the BJP, claiming that while the state government has curbed most of the drugs coming in from across the border, the bulk of the supply now comes from elsewhere.</p> '
        '<p>The party government in the state has faced criticism over drug abuse, with several videos on the issue going viral on social media in recent days, and the opposition has demanded answers.</p> '
        '</div></body></html>';
    const feedImage =
        'https://th-i.example.com/incoming/x/article1.ece/alternates/LANDSCAPE_615/KEJRIWAL.jpg';

    test('puts the picture at the head of the body with its caption', () {
      final result = ExtractionService.extractPage(
        page,
        link: 'https://example.com/a',
        imageUrl: feedImage,
      );
      final html = (result as ExtractedArticle).html;
      expect(html, startsWith('<figure><img src="$feedImage">'));
      expect(
        html,
        contains(
          '<figcaption>Arvind Kejriwal. File | Photo Credit: The Hindu</figcaption>',
        ),
      );
      expect(bodyHasImage(html, feedImage), isTrue);
    });

    test('leaves the body alone when it already carries the picture', () {
      final withFigure = page.replaceFirst(
        '<div itemprop="articleBody">',
        '<div itemprop="articleBody"><figure><img src="$feedImage"> '
            '<figcaption>In the body</figcaption></figure>',
      );
      final html = (ExtractionService.extractPage(
        withFigure,
        link: 'https://example.com/a',
        imageUrl: feedImage,
      ) as ExtractedArticle).html;
      expect('<img'.allMatches(html).length, 1);
      expect(html, contains('In the body'));
      expect(html, isNot(contains('Photo Credit')));
    });

    test('adds nothing when the page does not show the picture', () {
      final html = (ExtractionService.extractPage(
        page,
        link: 'https://example.com/a',
        imageUrl: 'https://elsewhere.example.com/other.jpg',
      ) as ExtractedArticle).html;
      expect(html, isNot(contains('<figure')));
    });
  });
}
