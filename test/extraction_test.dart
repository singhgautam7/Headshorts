import 'package:flutter_test/flutter_test.dart';
import 'package:headshorts/data/readability/extraction_service.dart';

Uri get _base => Uri.parse('https://example.com/news/story');

void main() {
  group('ExtractionService.normaliseArticleHtml', () {
    test('resolves relative image and link addresses', () {
      final html = ExtractionService.normaliseArticleHtml(
        '<p><a href="/other">See</a><img src="/photo.jpg"></p>',
        base: _base,
      );

      expect(html, contains('https://example.com/other'));
      expect(html, contains('https://example.com/photo.jpg'));
    });

    test('promotes a lazy-loaded image out of data-original', () {
      final html = ExtractionService.normaliseArticleHtml(
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
        ExtractionService.normaliseArticleHtml(
          '<p>Before</p><img src="/theme/1x1_spacer.png"><p>After</p>',
          base: _base,
        ),
        isNot(contains('img')),
      );
    });

    test('unwraps <picture> to the image inside it', () {
      final html = ExtractionService.normaliseArticleHtml(
        '<picture><source srcset="/a.webp"><img src="/a.jpg"></picture>',
        base: _base,
      );

      expect(html, isNot(contains('<picture')));
      expect(html, contains('https://example.com/a.jpg'));
    });

    test('leaves prose untouched', () {
      const prose = '<p>Chlorine gas leaked from a water filtration plant.</p>';
      expect(
        ExtractionService.normaliseArticleHtml(prose, base: _base),
        prose,
      );
    });
  });
}
