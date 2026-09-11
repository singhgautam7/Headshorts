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
  accentDark: _accent.darkValue,
  accentLight: _accent.lightValue,
  type: SourceType.rss,
  enabled: true,
  sortOrder: 0,
  addedAt: DateTime(2026, 3, 4),
);

ArticleRow _article({
  bool read = false,
  String? summary = 'The pilot covers about forty stations.',
  String? imageUrl,
}) => ArticleRow(
  id: 7,
  sourceId: 1,
  guid: 'g',
  title: 'Rail operators trial a single tap-in fare cap across three regions',
  link: 'https://example.com/rail',
  publishedAt: DateTime.now().subtract(const Duration(hours: 5)),
  fetchedAt: DateTime.now(),
  readInReel: read,
  readInFull: read,
  summary: summary,
  contentSnippet:
      'The pilot covers about forty stations and runs '
      'until March.',
  imageUrl: imageUrl,
);

Headline _headline({bool read = false, String? imageUrl}) =>
    Headline(_article(read: read, imageUrl: imageUrl), _source());

void main() {
  group('HeadlineCard', () {
    testWidgets('shows source, headline, summary and a relative timestamp', (
      tester,
    ) async {
      await pumpThemed(tester, HeadlineCard(_headline(), onTap: () {}));

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
        HeadlineCard(_headline(read: true), onTap: () {}),
      );

      final opacity = tester.widget<Opacity>(
        find
            .descendant(
              of: find.byType(HeadlineCard),
              matching: find.byType(Opacity),
            )
            .first,
      );
      expect(opacity.opacity, 0.5);
      expect(find.text('5 hours ago · read'), findsOneWidget);
      expect(find.textContaining('unread'), findsNothing);
    });

    testWidgets('prefixes the timestamp with "cached" when offline', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        HeadlineCard(_headline(), onTap: () {}, offline: true),
      );

      expect(find.text('cached · 5 hours ago'), findsOneWidget);
    });

    testWidgets('drops the summary when a thumbnail takes the space', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        HeadlineCard(
          _headline(imageUrl: 'https://example.com/x.jpg'),
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
        HeadlineCard(_headline(), onTap: () => opened++),
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
