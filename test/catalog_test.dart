import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:headshorts/data/db/article_repository.dart';
import 'package:headshorts/data/db/database.dart';
import 'package:headshorts/data/db/source_repository.dart';
import 'package:headshorts/data/sources/source_adapter.dart';
import 'package:headshorts/data/sources/source_catalog.dart';

/// The real shipped asset, read from disk rather than mocked: a catalog that
/// parses in a test but not on the device would be worse than no test.
SourceCatalog _shipped() =>
    SourceCatalog.parse(File(SourceCatalog.assetPath).readAsStringSync());

void main() {
  group('the bundled catalog', () {
    late final catalog = _shipped();

    test('parses every feed in the asset', () {
      expect(catalog.sources.length, greaterThanOrEqualTo(40));
      expect(catalog.sources.length, lessThanOrEqualTo(60));
    });

    test('every entry is usable', () {
      for (final source in catalog.sources) {
        expect(source.title.trim(), isNotEmpty);
        expect(source.category.trim(), isNotEmpty);
        expect(source.feedUrl, startsWith('https://'));
        expect(
          source.category,
          isNot('Uncategorised'),
          reason: '${source.title} is outside a folder',
        );
      }
    });

    test('no feed is listed twice', () {
      final urls = catalog.sources.map((s) => s.feedUrl).toList();
      expect(urls.toSet(), hasLength(urls.length));
    });

    test('spans several categories', () {
      expect(catalog.categories.length, greaterThanOrEqualTo(5));
      expect(catalog.categories, containsAll(['India', 'World', 'Technology']));
    });

    test("carries the design board's own accents unaltered", () {
      // The eight the board specifies must survive the round trip through
      // OPML; the rest get a derived tone.
      final hindu = catalog.sources.firstWhere((s) => s.title == 'The Hindu');
      expect(hindu.accent.onDark.toARGB32(), 0xFFE4A868);
      expect(hindu.accent.onLight.toARGB32(), 0xFF8A5518);

      final bbc = catalog.sources.firstWhere((s) => s.title == 'BBC News');
      expect(bbc.accent.onDark.toARGB32(), 0xFFE39191);
      expect(bbc.accent.onLight.toARGB32(), 0xFF9C3A3C);
    });

    test('nothing in it is subscribed by merely loading it', () async {
      // The catalog is a directory, not a starting state. This is a type-level
      // guarantee — it holds no database — but worth stating.
      expect(catalog, isA<SourceCatalog>());
      expect(catalog.sources.first, isA<CatalogSource>());
    });
  });

  group('search', () {
    late final catalog = _shipped();

    test('an empty query browses the whole catalog', () {
      expect(catalog.search('   '), hasLength(catalog.sources.length));
    });

    test('matches a publisher by name, case-insensitively', () {
      expect(
        catalog.search('guardian').map((s) => s.title),
        contains('The Guardian'),
      );
      expect(
        catalog.search('GUARDIAN').map((s) => s.title),
        contains('The Guardian'),
      );
    });

    test('matches on a partial word', () {
      expect(catalog.search('hind').map((s) => s.title), contains('The Hindu'));
    });

    test('matches by category', () {
      final results = catalog.search('technology');
      expect(results, isNotEmpty);
      expect(results.every((s) => s.category == 'Technology'), isTrue);
    });

    test('every term has to match, so two words narrow', () {
      final wide = catalog.search('the');
      final narrow = catalog.search('the guardian');
      expect(narrow.length, lessThan(wide.length));
      expect(narrow.map((s) => s.title), contains('The Guardian'));
    });

    test('returns nothing for a query that matches nothing', () {
      // The screen turns this into a prompt to add by URL.
      expect(catalog.search('zzzz no such publisher'), isEmpty);
    });

    test('groups results by category, in catalog order', () {
      final grouped = catalog.grouped('');
      expect(grouped.keys, catalog.categories);
      expect(
        grouped.values.fold(0, (sum, list) => sum + list.length),
        catalog.sources.length,
      );
    });

    test('grouping a narrow query keeps only the matching categories', () {
      expect(catalog.grouped('technology').keys, ['Technology']);
    });
  });

  group('subscribing from the catalog', () {
    late HsDatabase db;
    late SourceRepository sources;
    late ArticleRepository articles;
    late SourceCatalog catalog;

    setUp(() {
      db = HsDatabase.forTesting(NativeDatabase.memory());
      sources = SourceRepository(db);
      articles = ArticleRepository(db);
      catalog = _shipped();
    });

    tearDown(() => db.close());

    Future<int> subscribe(CatalogSource source) => sources.add(
      title: source.title,
      feedUrl: source.feedUrl,
      siteUrl: source.siteUrl,
      category: source.category,
      accent: source.accent,
    );

    test('adds one row, with the catalog accent', () async {
      final entry = catalog.sources.firstWhere((s) => s.title == 'The Hindu');
      await subscribe(entry);

      final row = (await sources.all()).single;
      expect(row.title, 'The Hindu');
      expect(row.category, 'India');
      expect(row.accentDark, 0xFFE4A868);
      expect(row.enabled, isTrue);
    });

    test('subscribing twice keeps one subscription', () async {
      final entry = catalog.sources.first;
      final first = await subscribe(entry);
      expect(await subscribe(entry), first);
      expect(await sources.all(), hasLength(1));
    });

    test("a new source's category tab appears", () async {
      await subscribe(catalog.sources.firstWhere((s) => s.category == 'India'));
      expect(await sources.watchCategories().first, ['India']);

      // Adding a Technology source makes that tab appear.
      await subscribe(
        catalog.sources.firstWhere((s) => s.category == 'Technology'),
      );
      expect(
        await sources.watchCategories().first,
        unorderedEquals(['India', 'Technology']),
      );
    });

    test('its items reach Today once a refresh has run', () async {
      final entry = catalog.sources.firstWhere((s) => s.title == 'BBC News');
      final id = await subscribe(entry);

      expect(await articles.watchBriefing().first, isEmpty);

      // What a refresh does: fetch, then upsert against that source.
      await articles.upsert(id, [
        ParsedArticle(
          guid: 'a',
          title: 'A newly fetched headline from a freshly added source',
          link: 'https://bbc.co.uk/news/a',
          publishedAt: DateTime(2026, 9, 8),
        ),
      ]);

      final briefing = await articles.watchBriefing().first;
      expect(briefing, hasLength(1));
      expect(briefing.single.source.title, 'BBC News');
    });

    test('unsubscribing takes its items and its tab with it', () async {
      final entry = catalog.sources.firstWhere((s) => s.category == 'Science');
      final id = await subscribe(entry);
      await articles.upsert(id, [
        ParsedArticle(
          guid: 'a',
          title: 'A headline that should leave with its source',
          link: 'https://example.com/a',
          publishedAt: DateTime(2026, 9, 8),
        ),
      ]);
      expect(await articles.watchBriefing().first, hasLength(1));

      await sources.remove(id);

      expect(await articles.watchBriefing().first, isEmpty);
      expect(await sources.watchCategories().first, isEmpty);
    });

    test('turning a source off keeps it and its items for later', () async {
      // The Sources toggle pauses rather than unsubscribes: turning it back
      // on has to be instant, and unsubscribing is a deliberate act on the
      // source's own screen.
      final entry = catalog.sources.first;
      final id = await subscribe(entry);
      await articles.upsert(id, [
        ParsedArticle(
          guid: 'a',
          title: 'A headline that should survive a source being paused',
          link: 'https://example.com/a',
          publishedAt: DateTime(2026, 9, 8),
        ),
      ]);

      await sources.setEnabled(id, enabled: false);
      expect(await articles.watchBriefing().first, isEmpty);

      await sources.setEnabled(id, enabled: true);
      expect(
        await articles.watchBriefing().first,
        hasLength(1),
        reason: 'the cached item came straight back',
      );
    });

    test('disabling hides its items without unsubscribing', () async {
      final entry = catalog.sources.first;
      final id = await subscribe(entry);
      await articles.upsert(id, [
        ParsedArticle(
          guid: 'a',
          title: 'A headline from a source about to be paused',
          link: 'https://example.com/a',
          publishedAt: DateTime(2026, 9, 8),
        ),
      ]);

      await sources.setEnabled(id, enabled: false);

      expect(await articles.watchBriefing().first, isEmpty);
      expect(await sources.all(), hasLength(1), reason: 'still subscribed');
      expect(await sources.watchCategories().first, isEmpty);
    });
  });
}
