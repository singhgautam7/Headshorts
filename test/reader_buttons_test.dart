import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:headshorts/app/providers.dart';
import 'package:headshorts/app/settings_controller.dart';
import 'package:headshorts/data/db/article_repository.dart';
import 'package:headshorts/data/db/database.dart';
import 'package:headshorts/data/db/source_repository.dart';
import 'package:headshorts/data/prefs/settings.dart';
import 'package:headshorts/data/readability/extraction_service.dart';
import 'package:headshorts/data/sources/source_adapter.dart';
import 'package:headshorts/features/reader/reader_controller.dart';
import 'package:headshorts/features/reader/reader_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/harness.dart';

void main() {
  late HsDatabase db;
  late SourceRepository sources;
  late ArticleRepository articles;
  late SettingsStore store;
  late int articleId;
  late ArticleRow articleRow;
  late SourceRow sourceRow;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    store = SettingsStore(prefs);

    db = HsDatabase.forTesting(NativeDatabase.memory());
    sources = SourceRepository(db);
    articles = ArticleRepository(db);

    final sourceId = await sources.add(
      title: 'Hacker News',
      feedUrl: 'https://example.com/feed',
      category: 'Tech',
    );

    await articles.upsert(sourceId, [
      ParsedArticle(
        guid: 'hn-1',
        title: 'Sample Article Title for Test',
        link: 'https://example.com/story/hn-1',
        publishedAt: DateTime(2026, 9, 8, 12),
        contentSnippet: 'A brief description of the story.',
      ),
    ]);

    final allArticles = await db.select(db.articles).get();
    articleRow = allArticles.first;
    articleId = articleRow.id;

    final allSources = await db.select(db.sources).get();
    sourceRow = allSources.first;
  });

  tearDown(() => db.close());

  testWidgets(
    'renders 3 separated floating buttons (open in web, share, more)',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(372, 780));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await pumpThemed(
        tester,
        ProviderScope(
          overrides: [
            settingsStoreProvider.overrideWithValue(store),
            databaseProvider.overrideWithValue(db),
            articleProvider.overrideWith(
              (ref, id) => Stream.value(Headline(articleRow, sourceRow)),
            ),
            extractionProvider.overrideWith(
              (ref, id) async => const ExtractedArticle(
                html: '<p>Paragraph 1 with enough content to be an extracted article.</p>',
                byline: 'Test Author',
                wordCount: 150,
              ),
            ),
          ],
          child: ReaderScreen(articleId),
        ),
      );

      await tester.pumpAndSettle();

      final semantics = tester.ensureSemantics();

      // Verify all 3 buttons are rendered with their accessibility semantics
      final webButton = find.bySemanticsLabel('Open in web');
      final shareButton = find.bySemanticsLabel('Share');
      final moreButton = find.bySemanticsLabel('More options');

      expect(webButton, findsOneWidget);
      expect(shareButton, findsOneWidget);
      expect(moreButton, findsOneWidget);

      // Verify "Open in web" has visible text
      expect(find.text('Open in web'), findsOneWidget);

      // Verify tapping "More options" opens the popup menu
      await tester.tap(moreButton);
      await tester.pumpAndSettle();
      expect(find.text('Copy link'), findsOneWidget);
      expect(find.text('Open in browser'), findsOneWidget);
      expect(find.text('Text size'), findsOneWidget);

      semantics.dispose();
    },
  );

  group('text size popover', () {
    Finder slider() => find.byType(TextSizeSlider);

    Future<void> open(WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(372, 780));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await pumpThemed(
        tester,
        ProviderScope(
          overrides: [
            settingsStoreProvider.overrideWithValue(store),
            databaseProvider.overrideWithValue(db),
            articleProvider.overrideWith(
              (ref, id) => Stream.value(Headline(articleRow, sourceRow)),
            ),
            extractionProvider.overrideWith(
              (ref, id) async => ExtractedArticle(
                // Long enough that the Reader scrolls.
                html: List.filled(40, '<p>A paragraph of prose.</p>').join(),
                byline: null,
                wordCount: 200,
              ),
            ),
          ],
          child: ReaderScreen(articleId),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Aa'));
      // Mid-way through opening it is sliding in, not simply present.
      await tester.pump(const Duration(milliseconds: 80));
      final sliding = tester
          .widgetList<SlideTransition>(
            find.ancestor(of: slider(), matching: find.byType(SlideTransition)),
          )
          .any((t) => t.position.value != Offset.zero);
      expect(sliding, isTrue, reason: 'the popover should slide in');
      await tester.pumpAndSettle();
    }

    TextSizeStep current(WidgetTester tester) =>
        ProviderScope.containerOf(tester.element(find.byType(ReaderScreen)))
            .read(settingsProvider)
            .textSize;

    testWidgets('opens from the bar and closes on a tap outside', (
      tester,
    ) async {
      await open(tester);
      expect(slider(), findsOneWidget);

      // Somewhere in the prose, well clear of the card.
      await tester.tapAt(const Offset(186, 600));
      await tester.pumpAndSettle();
      expect(slider(), findsNothing);
    });

    testWidgets('closes when the reader scrolls', (tester) async {
      await open(tester);
      // The barrier is what the finger lands on; the drag closes it.
      await tester.drag(
        find.byType(ListView),
        const Offset(0, -200),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();
      expect(slider(), findsNothing);
    });

    testWidgets('snaps to the five steps only', (tester) async {
      await open(tester);
      final box = tester.getRect(
        find.descendant(of: slider(), matching: find.byType(GestureDetector)),
      );
      // A tap just past the middle snaps to the middle step, not between.
      await tester.tapAt(box.center + const Offset(9, 0));
      await tester.pumpAndSettle();
      expect(current(tester), TextSizeStep.medium);

      await tester.tapAt(Offset(box.right - 2, box.center.dy));
      await tester.pumpAndSettle();
      expect(current(tester), TextSizeStep.largest);

      await tester.tapAt(Offset(box.left + 2, box.center.dy));
      await tester.pumpAndSettle();
      expect(current(tester), TextSizeStep.smallest);
    });
  });
}
