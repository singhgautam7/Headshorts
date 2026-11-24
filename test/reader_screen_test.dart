import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:headshorts/app/providers.dart';
import 'package:headshorts/core/theme/hs_theme.dart';
import 'package:headshorts/core/tokens/palette.dart';
import 'package:headshorts/data/db/article_repository.dart';
import 'package:headshorts/data/db/database.dart';
import 'package:headshorts/data/db/source_repository.dart';
import 'package:headshorts/data/prefs/settings.dart';
import 'package:headshorts/data/readability/extraction_service.dart';
import 'package:headshorts/data/sources/source_adapter.dart';
import 'package:headshorts/features/bookmarks/bookmarks_controller.dart';
import 'package:headshorts/features/reader/listen_controller.dart';
import 'package:headshorts/features/reader/reader_controller.dart';
import 'package:headshorts/features/reader/reader_screen.dart';
import 'package:headshorts/features/reader/related/other_sources_section.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late HsDatabase db;
  late SettingsStore store;
  late ArticleRow articleRow;
  late SourceRow sourceRow;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    store = SettingsStore(await SharedPreferences.getInstance());
    db = HsDatabase.forTesting(NativeDatabase.memory());
    final sourceId = await SourceRepository(db).add(
      title: 'Hacker News',
      feedUrl: 'https://example.com/feed',
      category: 'Tech',
    );
    await ArticleRepository(db).upsert(sourceId, [
      ParsedArticle(
        guid: 'hn-1',
        title:
            'A very long headline that keeps going and going so that it '
            'wraps across many lines at the largest system font size',
        link: 'https://example.com/story/hn-1',
        publishedAt: DateTime(2026, 9, 8, 12),
        contentSnippet:
            'A standfirst that is long enough to be shown, and '
            'that also wraps a good many times at a large font.',
      ),
    ]);
    articleRow = (await db.select(db.articles).get()).first;
    sourceRow = (await db.select(db.sources).get()).first;
  });

  tearDown(() => db.close());

  List<Override> overrides({Headline? headline, bool missing = false}) => [
    settingsStoreProvider.overrideWithValue(store),
    databaseProvider.overrideWithValue(db),
    articleProvider.overrideWith(
      (ref, id) => Stream.value(
        missing ? null : (headline ?? Headline(articleRow, sourceRow)),
      ),
    ),
    isBookmarkedProvider.overrideWith((ref, link) => Stream.value(false)),
    listenSupportedProvider.overrideWith((ref, language) async => true),
    extractionProvider.overrideWith(
      (ref, id) async => const ExtractedArticle(
        html: '<p>The body paragraph, long enough to count as an article.</p>',
        byline: null,
        wordCount: 150,
      ),
    ),
  ];

  Widget app(Widget home, {double textScale = 1}) => ProviderScope(
    retry: (_, _) => null,
    overrides: overrides(),
    child: MaterialApp(
      theme: buildHsTheme(HsPalette.amoled),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: home,
    ),
  );

  testWidgets('the body mounts only after the push transition', (tester) async {
    await tester.binding.setSurfaceSize(const Size(372, 780));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      app(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ReaderScreen(articleRow.id),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    expect(find.textContaining('A very long headline'), findsOneWidget);
    expect(
      find.textContaining('The body paragraph', findRichText: true),
      findsNothing,
    );

    await tester.pumpAndSettle();
    expect(
      find.textContaining('The body paragraph', findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets('the related section closes a cached article', (tester) async {
    await tester.binding.setSurfaceSize(const Size(372, 780));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(app(ReaderScreen(articleRow.id)));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    final section = find.byType(OtherSourcesSection);
    expect(section, findsOneWidget);
    expect(
      tester.getTopLeft(section).dy,
      greaterThanOrEqualTo(
        tester
            .getTopLeft(
              find.textContaining('The body paragraph', findRichText: true),
            )
            .dy,
      ),
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle(const Duration(seconds: 2));
  });

  testWidgets('a pruned id says so instead of staying a skeleton', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(372, 780));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: overrides(missing: true),
        child: MaterialApp(
          theme: buildHsTheme(HsPalette.amoled),
          home: const ReaderScreen(9999),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('This story is no longer saved on your phone.'),
      findsOneWidget,
    );
    expect(find.text('Back to Headlines'), findsOneWidget);
  });

  testWidgets('largest font on a small screen does not overflow', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(app(ReaderScreen(articleRow.id), textScale: 2));
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Aa'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(TextSizeSlider), findsOneWidget);

    await tester.tapAt(const Offset(180, 600));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('More options'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
