import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:headshorts/data/readability/article_cleaner.dart';
import 'package:headshorts/data/readability/cleaning_rules.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

String _fixture(String name) => File('test/fixtures/$name').readAsStringSync();

dom.DocumentFragment _parse(String html) => html_parser.parseFragment(html);

void main() {
  group('a Guardian article with a newsletter block', () {
    // Real extracted HTML, saved from theguardian.com.
    late final source = _fixture('guardian_newsletter.html');
    late final cleaned = ArticleCleaner.clean(
      source,
      base: Uri.parse(
        'https://www.theguardian.com/world/2026/sep/07/canada-tariffs-us-trump',
      ),
    );

    test('the fixture really does contain the boilerplate', () {
      // Guards the test itself: if the fixture stops exercising the bug, the
      // assertions below stop meaning anything.
      expect(source.toLowerCase(), contains('skip past newsletter promotion'));
      expect(source.toLowerCase(), contains('after newsletter promotion'));
    });

    test('drops the skip link and both orphan captions', () {
      final text = _parse(cleaned).text!.toLowerCase();
      expect(text, isNot(contains('skip past newsletter promotion')));
      expect(text, isNot(contains('after newsletter promotion')));
      expect(text, isNot(contains('newsletter promotion')));
    });

    test('keeps the article itself', () {
      final text = _parse(cleaned).text!;
      expect(text.length, greaterThan(1000));
      expect(_parse(cleaned).querySelectorAll('p').length, greaterThan(4));
    });

    test('leaves no empty container where the promo was', () {
      for (final element in _parse(
        cleaned,
      ).querySelectorAll('figure, div, p')) {
        if (element.querySelector('img') != null) continue;
        expect(
          element.text.trim(),
          isNotEmpty,
          reason: 'an empty <${element.localName}> was left behind',
        );
      }
    });
  });

  group('a structured article', () {
    late final cleaned = ArticleCleaner.clean(
      _fixture('structured_article.html'),
      base: Uri.parse('https://www.theverge.com/games/991547/nintendo-direct'),
    );

    test('preserves headings and lists', () {
      final doc = _parse(cleaned);
      expect(doc.querySelectorAll('h2, h3'), isNotEmpty);
      expect(doc.querySelectorAll('ul, ol'), isNotEmpty);
      expect(doc.querySelectorAll('li'), isNotEmpty);
    });

    test('preserves inline emphasis', () {
      expect(_parse(cleaned).querySelectorAll('strong, b, em, i'), isNotEmpty);
    });

    test('emits only allowlisted tags', () {
      for (final element in _parse(cleaned).querySelectorAll('*')) {
        expect(
          allowedTags,
          contains(element.localName),
          reason: '<${element.localName}> should have been unwrapped',
        );
      }
    });

    test('strips class, style, id and data attributes', () {
      for (final element in _parse(cleaned).querySelectorAll('*')) {
        for (final name in element.attributes.keys) {
          final attribute = name.toString();
          expect(
            attribute,
            isNot(anyOf('class', 'style', 'id')),
            reason: 'on <${element.localName}>',
          );
          expect(attribute.startsWith('data-'), isFalse);
          expect(attribute.startsWith('on'), isFalse);
        }
      }
    });
  });

  group('an article with inline links', () {
    late final cleaned = ArticleCleaner.clean(
      _fixture('linked_article.html'),
      base: Uri.parse('https://www.theverge.com/gadgets/992003/asus-cetra'),
    );

    test('keeps the links', () {
      expect(_parse(cleaned).querySelectorAll('a[href]'), isNotEmpty);
    });

    test('every href is absolute and tappable', () {
      for (final anchor in _parse(cleaned).querySelectorAll('a')) {
        final href = anchor.attributes['href'];
        expect(href, isNotNull, reason: 'anchor with no href survived');
        expect(href, startsWith('https://'));
      }
    });
  });

  group('inline link stitching', () {
    const base = 'https://timesofindia.indiatimes.com/sports/cricket';

    test('stitches a paragraph split around an inline link without newlines', () {
      const html =
          '<p>NEW DELHI: The </p><a href="/parties/aiadmk">AIADMK</a><p> on Monday took a swipe at DMK.</p>';
      final cleaned = ArticleCleaner.clean(html, base: Uri.parse(base));
      expect(
        cleaned,
        '<p>NEW DELHI: The <a href="https://timesofindia.indiatimes.com/parties/aiadmk">AIADMK</a> on Monday took a swipe at DMK.</p>',
      );
    });

    test('stitches multiple inline links and text within a single sentence', () {
      const html =
          '<p>Both </p><a href="/a">Party A</a> and <a href="/b">Party B</a><p> opposed the resolution.</p>';
      final cleaned = ArticleCleaner.clean(html, base: Uri.parse(base));
      expect(
        cleaned,
        '<p>Both <a href="https://timesofindia.indiatimes.com/a">Party A</a> and <a href="https://timesofindia.indiatimes.com/b">Party B</a> opposed the resolution.</p>',
      );
    });

    test('prepends leading inline links to the following paragraph', () {
      const html =
          '<a href="/breaking">Exclusive:</a><p> The government announced the committee.</p>';
      final cleaned = ArticleCleaner.clean(html, base: Uri.parse(base));
      expect(
        cleaned,
        '<p><a href="https://timesofindia.indiatimes.com/breaking">Exclusive:</a> The government announced the committee.</p>',
      );
    });

    test('appends trailing inline link to the preceding paragraph', () {
      const html =
          '<p>Read more details at </p><a href="/report">our report.</a>';
      final cleaned = ArticleCleaner.clean(html, base: Uri.parse(base));
      expect(
        cleaned,
        '<p>Read more details at <a href="https://timesofindia.indiatimes.com/report">our report.</a></p>',
      );
    });

    test('keeps standalone links between two complete sentences in their own paragraph', () {
      const html =
          '<p>First sentence ended here.</p><a href="/promo">Click here for full report</a><p>Second sentence starts afresh.</p>';
      final cleaned = ArticleCleaner.clean(html, base: Uri.parse(base));
      expect(
        cleaned,
        '<p>First sentence ended here.</p><p><a href="https://timesofindia.indiatimes.com/promo">Click here for full report</a></p><p>Second sentence starts afresh.</p>',
      );
    });
  });

  group('cleaning rules', () {
    const base = 'https://example.com/news/story';
    String clean(String html) =>
        ArticleCleaner.clean(html, base: Uri.parse(base));

    test('drops the labels publishers thread between paragraphs', () {
      // Indian Express's byline strip and ad-slot label, TOI's SEO tail, and
      // a tag list at the foot — each a whole element whose text is the label.
      final out = clean(
        '<p>3 min read<em>Jaipur</em>Updated: Sep 14, 2026 08:46 PM IST</p> '
        '<p>Real prose here, long enough to be a paragraph of the story.</p> '
        '<p>Story continues below this ad</p> '
        '<p>More real prose, also long enough to count as the story.</p> '
        '<p>Catch the latest World News and Live updates on Times of India.</p> '
        '<ul><li>Tags:</li><li><a href="https://x/about/jaipur/">Jaipur</a></li></ul>',
      );
      expect(out, contains('Real prose here'));
      expect(out, contains('More real prose'));
      for (final label in [
        'min read',
        'Story continues',
        'Catch the latest',
        'Tags',
        'Jaipur',
      ]) {
        expect(out, isNot(contains(label)), reason: label);
      }
    });

    test('keeps a wrapper with several real paragraphs whatever its class', () {
      // Indian Express gates the second half of a story, figures included,
      // in `paywall container-wall-exclusive`.
      final out = clean(
        '<p>Opening paragraph of the story, long enough to be real prose.</p> '
        '<div class="paywall container-wall-exclusive"> '
        '<p>Second paragraph of the story, long enough to be real prose here, and then some more words so the wrapper is plainly an article.</p> '
        '<p>Third paragraph of the story, long enough to be real prose here, and then some more words so the wrapper is plainly an article.</p> '
        '<p>Fourth paragraph of the story, long enough to be real prose here, and then some more words so the wrapper is plainly an article.</p> '
        '<p>Fifth paragraph of the story, long enough to be real prose here, and then some more words so the wrapper is plainly an article.</p> '
        '<p>Sixth paragraph of the story, long enough to be real prose here, and then some more words so the wrapper is plainly an article.</p> '
        '<img src="https://example.com/photo.jpg"></div>',
      );
      expect(out, contains('Sixth paragraph'));
      expect(out, contains('https://example.com/photo.jpg'));
    });

    test('removes a boilerplate container by class', () {
      expect(
        clean(
          '<p>Real prose here.</p> <div class="newsletter-signup">'
          ' <p>Sign up for our daily briefing</p></div>',
        ),
        isNot(contains('daily briefing')),
      );
    });

    test('removes share, related and advert blocks', () {
      for (final marker in const [
        'share-tools',
        'related-stories',
        'ad-slot',
        'sponsored-content',
      ]) {
        expect(
          clean('<p>Real prose.</p><div class="$marker"><p>Junk</p></div>'),
          isNot(contains('Junk')),
          reason: marker,
        );
      }
    });

    test('drops aside, iframe, form and button outright', () {
      final cleaned = clean(
        '<p>Prose.</p><aside>Aside</aside><iframe src="x"></iframe> '
        '<form><button>Go</button></form>',
      );
      expect(cleaned, contains('Prose.'));
      for (final junk in const ['Aside', 'iframe', 'Go', 'form']) {
        expect(cleaned, isNot(contains(junk)), reason: junk);
      }
    });

    test('unwraps an unknown tag but keeps its prose', () {
      final cleaned = clean('<my-widget><p>Kept prose.</p></my-widget>');
      expect(cleaned, contains('Kept prose.'));
      expect(cleaned, isNot(contains('my-widget')));
    });

    test('removes an element hidden from assistive technology', () {
      expect(
        clean('<p>Prose.</p><p aria-hidden="true">Decoration</p>'),
        isNot(contains('Decoration')),
      );
    });

    test('strips tracking parameters from a link', () {
      expect(
        clean('<p><a href="/x?utm_source=rss&id=7">Link</a></p>'),
        contains('https://example.com/x?id=7'),
      );
    });

    test('drops a javascript: href rather than rendering it', () {
      final cleaned = clean('<p><a href="javascript:alert(1)">Tap</a></p>');
      expect(cleaned, isNot(contains('javascript')));
      expect(cleaned, contains('Tap'));
    });

    test('keeps prose that merely mentions a boilerplate word', () {
      const prose =
          '<p>The newsletter industry has grown considerably, and readers '
          'now subscribe to more of them than ever before.</p>';
      expect(clean(prose), contains('newsletter industry'));
    });

    test('preserves and normalises photo captions to figcaption', () {
      expect(
        clean(
          '<img src="https://example.com/pic.jpg"> '
          '<div class="Ta7d_ img_cptn"><span>Pakistan\'s Babar Azam, center. (AP Photo)</span></div> '
          '<p>NEW DELHI: The match concluded.</p>',
        ),
        contains(
          "<figcaption>Pakistan's Babar Azam, center. (AP Photo)</figcaption>",
        ),
      );

      // A caption whose picture is gone is a label under nothing: TOI's lead
      // video leaves one at the top of every story once the embed is dropped.
      expect(
        clean(
          '<p class="wp-caption-text">Photograph: Jane Doe</p><p>Story body.</p>',
        ),
        isNot(contains('Jane Doe')),
      );

      // The caption class is often on the wrapper that holds the picture —
      // Indian Express's `span.custom-caption` — and the picture must survive.
      final wrapped = clean(
        '<p>Before.</p><span class="custom-caption"> '
        '<img src="https://example.com/real.jpg" alt="Faiz Hasan won"> '
        '<span>Faiz Hasan won from ward 71</span></span><p>After.</p>',
      );
      expect(wrapped, contains('https://example.com/real.jpg'));
      expect(
        wrapped,
        contains('<figcaption>Faiz Hasan won from ward 71</figcaption>'),
      );

      expect(
        clean(
          '<figure><img src="https://example.com/pic.jpg" /> '
          '<div class="caption">A view of the stadium</div></figure>',
        ),
        contains('<figcaption>A view of the stadium</figcaption>'),
      );

      // Promos and share blocks matching caption keywords must NOT become figcaptions
      expect(
        clean(
          '<div class="promo-caption">Sign up for our newsletter</div><p>Story body.</p>',
        ),
        isNot(contains('<figcaption>')),
      );
    });

    test('is registry-driven, so a publisher quirk is data', () {
      // The Guardian's captions come from the per-domain registry, not code.
      expect(
        rulesFor('theguardian.com').exactText,
        contains('after newsletter promotion'),
      );
      expect(
        rulesFor('www.theguardian.com').exactText,
        contains('after newsletter promotion'),
      );
      expect(
        rulesFor('example.com').exactText,
        isNot(contains('after newsletter promotion')),
      );
      // Global rules still apply everywhere.
      expect(rulesFor('example.com').exactText, contains('advertisement'));
    });
  });
}
