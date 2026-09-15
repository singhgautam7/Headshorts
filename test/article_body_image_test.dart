import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:headshorts/core/util/canonical_url.dart';
import 'package:headshorts/data/prefs/settings.dart';
import 'package:headshorts/features/reader/article_body.dart';

import 'support/harness.dart';

void main() {
  Future<void> pump(WidgetTester tester, String html) => pumpThemed(
    tester,
    SizedBox(
      width: 360,
      child: ArticleBody(
        html: html,
        articleUrl: 'https://example.com/article',
        bodySize: 17,
        linkMode: LinkOpenMode.inApp,
      ),
    ),
  );

  group('ArticleBody images', () {
    testWidgets('every inline picture is one ArticleImage', (tester) async {
      await pump(
        tester,
        '<p>One</p><img src="https://example.com/a.jpg"> '
        '<p>Two</p><img src="https://example.com/b.jpg">',
      );
      expect(find.byType(ArticleImage), findsNWidgets(2));
    });

    test("the body knows whether it carries the feed's picture", () {
      const html =
          '<figure><img src="https://static.example.com/photo/msid-12345,imgsize-999.cms"> '
          '<figcaption>Caption</figcaption></figure><p>Two</p>';
      expect(
        bodyHasImage(
          html,
          'https://static.example.com/photo/msid-12345,imgsize-111.cms',
        ),
        isTrue,
      );
      expect(
        bodyHasImage(html, 'https://static.example.com/other.jpg'),
        isFalse,
      );
    });
  });

  group('sameImage', () {
    test('sees through the size a publisher writes into the address', () {
      expect(
        sameImage(
          'https://c.ndtvimg.com/2026-09/x_uae-iran_625x300_13.jpeg?downsize=773:435',
          'https://c.ndtvimg.com/2026-09/x_uae-iran_1200x900_13.jpeg',
        ),
        isTrue,
      );
      expect(
        sameImage(
          'https://www.hindustantimes.com/ht-img/img/2026/09/14/400x225/pic.webp',
          'https://www.hindustantimes.com/ht-img/img/2026/09/14/1600x900/pic.webp',
        ),
        isTrue,
      );
      expect(
        sameImage(
          'https://www.hindustantimes.com/ht-img/img/2026/09/14/1600x900/logo/Mahesh-Palawat_1789397040560_eI1X.jpg',
          'https://www.hindustantimes.com/ht-img/img/2026/09/14/400x225/Mahesh-Palawat_1789397040560_eI1X.jpg',
        ),
        isTrue,
      );
      expect(
        sameImage(
          'https://i.guim.co.uk/img/media/abc/0_0_2036_3072/master/2036.jpg?width=445',
          'https://i.guim.co.uk/img/media/abc/0_0_2036_3072/master/2036.jpg?width=1200',
        ),
        isTrue,
      );
    });

    test('does not merge two different pictures', () {
      expect(
        sameImage(
          'https://c.ndtvimg.com/2026-09/a_625x300.jpeg',
          'https://c.ndtvimg.com/2026-09/b_625x300.jpeg',
        ),
        isFalse,
      );
      // The Guardian names every file by its width: two different photos.
      expect(
        sameImage(
          'https://i.guim.co.uk/img/media/abc/0_0_2036_3072/master/2036.jpg',
          'https://i.guim.co.uk/img/media/def/0_0_2036_3072/master/2036.jpg',
        ),
        isFalse,
      );
      expect(sameImage('https://x/a.jpg', null), isFalse);
    });
  });
}
