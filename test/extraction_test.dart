import 'package:flutter_test/flutter_test.dart';
import 'package:headshorts/data/readability/article_cleaner.dart';
import 'package:headshorts/data/readability/extraction_service.dart';

Uri get _base => Uri.parse('https://example.com/news/story');

void main() {
  group('ArticleCleaner image handling', () {
    test('resolves relative image and link addresses', () {
      final html = ArticleCleaner.clean(
        '<p><a href="/other">See</a><img src="/photo.jpg"></p>',
        base: _base,
      );

      expect(html, contains('https://example.com/other'));
      expect(html, contains('https://example.com/photo.jpg'));
    });

    test('promotes a lazy-loaded image out of data-original', () {
      final html = ArticleCleaner.clean(
        '<img src="/theme/1x1_spacer.png" '
        'data-original="https://cdn.example.com/real.jpg">',
        base: _base,
      );

      expect(html, contains('https://cdn.example.com/real.jpg'));
      expect(html, isNot(contains('1x1_spacer')));
    });

    test('drops a spacer that has no real image behind it', () {
      // Left in place it would be stretched to full width and leave a
      // screen-high hole in the middle of the article.
      expect(
        ArticleCleaner.clean(
          '<p>Before</p><img src="/theme/1x1_spacer.png"><p>After</p>',
          base: _base,
        ),
        isNot(contains('img')),
      );
    });

    test('unwraps <picture>, keeping the decodable <img> fallback', () {
      final html = ArticleCleaner.clean(
        '<picture><source srcset="/a.avif"><img src="/a.jpg"></picture>',
        base: _base,
      );

      expect(html, isNot(contains('<picture')));
      // The <img> wins: a <source> may be a format Flutter cannot decode.
      expect(html, contains('https://example.com/a.jpg'));
    });

    test('takes the widest candidate out of a srcset', () {
      final html = ArticleCleaner.clean(
        '<img srcset="/small.jpg 320w, /big.jpg 1600w, /mid.jpg 800w">',
        base: _base,
      );

      expect(html, contains('https://example.com/big.jpg'));
      expect(html, isNot(contains('small.jpg')));
    });

    test('carries a srcset off <source> onto the image inside <picture>', () {
      final html = ArticleCleaner.clean(
        '<picture><source srcset="/real.webp 1200w">'
        ' <img src="/theme/1x1_spacer.png"></picture>',
        base: _base,
      );

      expect(html, contains('https://example.com/real.webp'));
    });

    test('resolves a protocol-relative address', () {
      expect(
        ArticleCleaner.clean(
          '<img src="//cdn.example.com/a.jpg">',
          base: _base,
        ),
        contains('https://cdn.example.com/a.jpg'),
      );
    });

    test('upgrades http to https, which Android blocks outright', () {
      expect(
        ArticleCleaner.clean(
          '<img src="http://cdn.example.com/a.jpg">',
          base: _base,
        ),
        contains('https://cdn.example.com/a.jpg'),
      );
    });

    test('strips the lazy-load attributes once they are promoted', () {
      final html = ArticleCleaner.clean(
        '<img src="/1x1.gif" data-src="/real.jpg" loading="lazy">',
        base: _base,
      );

      expect(html, contains('https://example.com/real.jpg'));
      expect(html, isNot(contains('data-src')));
      expect(html, isNot(contains('loading=')));
    });

    test('drops a base64 placeholder', () {
      expect(
        ArticleCleaner.clean(
          '<img src="data:image/gif;base64,R0lGODlhAQABAAAAACw=">',
          base: _base,
        ),
        isNot(contains('img')),
      );
    });
  });

  group('ExtractionService.imageHeaders', () {
    test('carries a Referer from the article and a desktop agent', () {
      final headers = ExtractionService.imageHeaders(
        'https://example.com/news/story',
      );

      expect(headers['Referer'], 'https://example.com/news/story');
      expect(headers['User-Agent'], contains('Mozilla/5.0'));
      expect(headers['Accept'], contains('image/webp'));
      expect(headers['Accept'], isNot(contains('image/avif')));
    });
  });

  group('ArticleCleaner, prose', () {
    test('leaves prose untouched', () {
      const prose = '<p>Chlorine gas leaked from a water filtration plant.</p>';
      expect(ArticleCleaner.clean(prose, base: _base), prose);
    });
  });
}
