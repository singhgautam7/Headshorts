import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:headshorts/core/tokens/accents.dart';
import 'package:headshorts/core/tokens/palette.dart';
import 'package:headshorts/data/db/article_repository.dart';
import 'package:headshorts/data/db/database.dart';
import 'package:headshorts/data/db/tables.dart';
import 'package:headshorts/features/linger/linger_screen.dart';
import 'package:headshorts/features/today/headline_card.dart';

import 'support/harness.dart';

const _accent = SourceAccent(Color(0xFFE39191), Color(0xFF9C3A3C));

SourceRow _source() => SourceRow(
  id: 1,
  title: 'BBC News',
  feedUrl: 'https://example.com/rss',
  category: 'World',
  language: 'en',
  accentDark: _accent.darkValue,
  accentLight: _accent.lightValue,
  type: SourceType.rss,
  enabled: true,
  sortOrder: 0,
  mutedInLatest: false,
  addedAt: DateTime(2026, 3, 4),
);

ArticleRow _article({
  bool read = false,
  String? summary = 'The pilot covers about forty stations.',
  String? imageUrl,
  String? snippet,
}) => ArticleRow(
  id: 7,
  sourceId: 1,
  guid: 'g',
  canonicalUrl: 'example.com/rail',
  titleKey: 'cap fare operators rail regions single',
  title: 'Rail operators trial a single tap-in fare cap across three regions',
  link: 'https://example.com/rail',
  publishedAt: DateTime.now().subtract(const Duration(hours: 5)),
  fetchedAt: DateTime.now(),
  seenInLinger: read,
  readFull: read,
  summary: summary,
  contentSnippet:
      snippet ??
      'The pilot covers about forty stations and runs '
          'until March.',
  imageUrl: imageUrl,
);

Headline _headline({bool read = false, String? imageUrl, String? snippet}) =>
    Headline(
      _article(read: read, imageUrl: imageUrl, snippet: snippet),
      _source(),
    );

void main() {
  group('HeadlineCard', () {
    testWidgets('shows source, headline, summary and a relative timestamp', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        HeadlineCard(ArticleView.fromHeadline(_headline()), onTap: () {}),
      );

      expect(find.text('BBC NEWS'), findsOneWidget);
      expect(find.textContaining('tap-in fare cap'), findsOneWidget);
      expect(find.textContaining('forty stations'), findsOneWidget);
      expect(find.text('5 hours ago'), findsOneWidget);
    });

    testWidgets('de-emphasises a read item without any count or badge', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        HeadlineCard(
          ArticleView.fromHeadline(_headline(read: true)),
          onTap: () {},
        ),
      );

      // Faded by the alpha of the text's own colour, not an Opacity layer.
      final ink = tester
          .widget<Text>(find.textContaining('tap-in fare cap'))
          .style!
          .color!;
      expect(ink.a, closeTo(0.5, 0.01));
      expect(
        find.descendant(
          of: find.byType(HeadlineCard),
          matching: find.byType(Opacity),
        ),
        findsNothing,
      );
      expect(find.text('5 hours ago · read'), findsOneWidget);
      expect(find.textContaining('unread'), findsNothing);
    });

    testWidgets('prefixes the timestamp with "cached" when offline', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        HeadlineCard(
          ArticleView.fromHeadline(_headline()),
          onTap: () {},
          offline: true,
        ),
      );

      expect(find.text('cached · 5 hours ago'), findsOneWidget);
    });

    testWidgets('drops the summary when a thumbnail takes the space', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        HeadlineCard(
          ArticleView.fromHeadline(
            _headline(imageUrl: 'https://example.com/x.jpg'),
          ),
          onTap: () {},
        ),
      );

      expect(find.textContaining('forty stations'), findsNothing);
      expect(find.textContaining('tap-in fare cap'), findsOneWidget);
    });

    testWidgets('opens the article when tapped', (tester) async {
      var opened = 0;
      await pumpThemed(
        tester,
        HeadlineCard(
          ArticleView.fromHeadline(_headline()),
          onTap: () => opened++,
        ),
      );

      await tester.tap(find.byType(HeadlineCard));
      expect(opened, 1);
    });
  });

  group('LingerCard', () {
    Widget card({int position = 3, int total = 12}) => Padding(
      padding: const EdgeInsets.all(16),
      child: LingerCard(
        headline: _headline(),
        position: position,
        total: total,
        onReadFull: () {},
      ),
    );

    testWidgets('carries the headline, an extract and "Read full"', (
      tester,
    ) async {
      await pumpThemed(tester, card());

      expect(find.text('BBC NEWS'), findsOneWidget);
      expect(find.textContaining('tap-in fare cap'), findsOneWidget);
      expect(find.text('Read full'), findsOneWidget);
    });

    testWidgets('says how many remain, so the end is visible', (tester) async {
      await pumpThemed(tester, card());

      expect(find.text('Swipe up for the next of 8 remaining'), findsOneWidget);
    });

    testWidgets('names the end rather than implying more', (tester) async {
      await pumpThemed(tester, card(position: 11));

      expect(find.text('Swipe up for the end of the briefing'), findsOneWidget);
    });

    testWidgets('takes an accent-derived ground on black', (tester) async {
      await pumpThemed(tester, card());

      final container = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(LingerCard),
              matching: find.byType(Container),
            )
            .first,
      );
      final decoration = container.decoration! as BoxDecoration;
      // A wash over black, not the accent itself.
      expect(decoration.color, isNot(_accent.onDark));
      expect(decoration.color, isNot(HsPalette.amoled.background));
    });

    testWidgets('keeps a neutral ground on paper', (tester) async {
      await pumpThemed(tester, card(), palette: HsPalette.light);

      final container = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(LingerCard),
              matching: find.byType(Container),
            )
            .first,
      );
      expect(
        (container.decoration! as BoxDecoration).color,
        HsPalette.light.surface,
      );
    });

    group('a long description', () {
      final long = List.filled(
        40,
        'The council agreed to study the crossing again next spring.',
      ).join(' ');

      Future<void> at(
        WidgetTester tester,
        Size size, {
        double scale = 1,
      }) async {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await pumpThemed(
          tester,
          MediaQuery(
            data: MediaQueryData(
              size: size,
              textScaler: TextScaler.linear(scale),
            ),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: LingerCard(
                headline: _headline(snippet: long),
                position: 0,
                total: 3,
                onReadFull: () {},
              ),
            ),
          ),
        );
      }

      testWidgets('never scrolls inside the card', (tester) async {
        await at(tester, const Size(390, 700));
        expect(
          find.descendant(
            of: find.byType(LingerCard),
            matching: find.byType(Scrollable),
          ),
          findsNothing,
        );
      });

      testWidgets('opens lit from Show more, and Show less closes it', (
        tester,
      ) async {
        await at(tester, const Size(390, 700));
        await tester.tap(find.text('Show more'));
        await tester.pumpAndSettle();
        expect(find.text(long), findsNWidgets(2));
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Show less'));
        await tester.pumpAndSettle();
        expect(find.text('Show less'), findsNothing);

        // A tap outside closes it too.
        await tester.tap(find.text('Show more'));
        await tester.pumpAndSettle();
        await tester.tapAt(const Offset(4, 696));
        await tester.pumpAndSettle();
        expect(find.text('Show less'), findsNothing);
      });

      for (final size in const [
        Size(800, 200),
        Size(740, 150),
        Size(360, 420),
      ]) {
        testWidgets('fits a ${size.width}x${size.height} window', (
          tester,
        ) async {
          for (final scale in [1.0, 2.0]) {
            await at(tester, size, scale: scale);
            expect(tester.takeException(), isNull, reason: 'scale $scale');
          }
        });
      }
    });

    testWidgets('a short description has nothing to show more of', (
      tester,
    ) async {
      await pumpThemed(tester, card());
      expect(find.text('Show more'), findsNothing);
    });

    testWidgets('opens the Reader from "Read full"', (tester) async {
      var opened = 0;
      await pumpThemed(
        tester,
        Padding(
          padding: const EdgeInsets.all(16),
          child: LingerCard(
            headline: _headline(),
            position: 0,
            total: 3,
            onReadFull: () => opened++,
          ),
        ),
      );

      await tester.tap(find.text('Read full'));
      expect(opened, 1);
    });
  });

  group('PositionRuler', () {
    testWidgets('samples a long set down rather than drawing a mark each', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        const Center(
          child: PositionRuler(total: 60, index: 30, accent: Color(0xFFFFFFFF)),
        ),
      );

      expect(
        find.byType(AnimatedContainer),
        findsNWidgets(PositionRuler.maxMarks),
      );
    });
  });
}
