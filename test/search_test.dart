import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:headshorts/data/db/article_repository.dart';
import 'package:headshorts/data/db/database.dart';
import 'package:headshorts/data/db/source_repository.dart';
import 'package:headshorts/data/sources/source_adapter.dart';
import 'package:headshorts/features/search/search_controller.dart';

/// Full-text search over the cache: the FTS5 index, the scope, and the date
/// range. Everything here runs with no network at all, which is the point.
void main() {
  late HsDatabase db;
  late SourceRepository sources;
  late ArticleRepository articles;
  late int hindu;
  late int bbc;

  final now = DateTime.now();

  ParsedArticle item(
    String guid,
    String title, {
    String? snippet,
    Duration ago = Duration.zero,
  }) => ParsedArticle(
    guid: guid,
    title: title,
    link: 'https://example.com/$guid',
    publishedAt: now.subtract(ago),
    contentSnippet: snippet,
  );

  setUp(() async {
    db = HsDatabase.forTesting(NativeDatabase.memory());
    sources = SourceRepository(db);
    articles = ArticleRepository(db);

    hindu = await sources.add(
      title: 'The Hindu',
      feedUrl: 'https://hindu.example/rss',
      category: 'India',
    );
    bbc = await sources.add(
      title: 'BBC News',
      feedUrl: 'https://bbc.example/rss',
      category: 'World',
    );

    await articles.upsert(hindu, [
      item(
        'h1',
        'Heatwave warning extended for Vidarbha districts',
        snippet: 'The alert now runs to Friday for six districts.',
        ago: const Duration(hours: 3),
      ),
      item(
        'h2',
        'Kerala opens a floating solar plant on the backwaters',
        ago: const Duration(days: 20),
      ),
    ]);
    await articles.upsert(bbc, [
      item(
        'b1',
        'What a late-season heatwave does to standing crops',
        ago: const Duration(days: 2),
      ),
      item(
        'b2',
        'Rail operators trial a single tap-in fare cap',
        ago: const Duration(days: 40),
      ),
    ]);
  });

  tearDown(() => db.close());

  group('the query', () {
    test('matches a word in the title', () async {
      final hits = await articles.search(query: 'heatwave');
      expect(hits.map((h) => h.article.guid), unorderedEquals(['h1', 'b1']));
    });

    test('matches a prefix, so results follow the typing', () async {
      expect(await articles.search(query: 'heatw'), isNotEmpty);
    });

    test('matches the body snippet, not only the headline', () async {
      final hits = await articles.search(query: 'Friday');
      expect(hits.single.article.guid, 'h1');
    });

    test('every term has to match, so a second word narrows', () async {
      expect(await articles.search(query: 'heatwave crops'), hasLength(1));
      expect(await articles.search(query: 'heatwave zebra'), isEmpty);
    });

    test('returns results newest first, never by relevance', () async {
      final hits = await articles.search(query: 'heatwave');
      expect(hits.first.article.guid, 'h1', reason: '3 hours beats 2 days');
    });

    test('an empty or punctuation-only query is not a search', () async {
      expect(await articles.search(query: '   '), isEmpty);
      expect(await articles.search(query: '"'), isEmpty);
    });

    test('a query with FTS syntax in it cannot throw', () async {
      // Quoted and starred, so AND/OR/NEAR and a stray quote are just words.
      for (final query in ['AND', 'a OR b', 'NEAR(x y)', 'he"at', '*']) {
        await expectLater(articles.search(query: query), completes);
      }
    });

    test('finds a Devanagari headline', () async {
      await articles.upsert(hindu, [
        item('h3', 'लू से बचाव के लिए दोपहर में बाहरी काम पर रोक'),
      ]);
      final hits = await articles.search(query: 'दोपहर');
      expect(hits.single.article.guid, 'h3');
    });
  });

  group('the scope', () {
    test('searches only the sources given', () async {
      final hits = await articles.search(query: 'heatwave', sourceIds: {bbc});
      expect(hits.single.article.guid, 'b1');
    });

    test('an empty scope finds nothing, rather than everything', () async {
      // Saying so beats quietly ignoring the reader's own filter.
      expect(
        await articles.search(query: 'heatwave', sourceIds: const {}),
        isEmpty,
      );
    });

    test('a paused source is still searchable', () async {
      await sources.setEnabled(bbc, enabled: false);
      final hits = await articles.search(query: 'heatwave', sourceIds: {bbc});
      expect(
        hits.single.article.guid,
        'b1',
        reason: 'the scope decides what is in, not the subscription',
      );
    });
  });

  group('the date range', () {
    test('excludes anything published before the start', () async {
      final hits = await articles.search(
        query: 'heatwave',
        from: now.subtract(const Duration(hours: 12)),
      );
      expect(hits.map((h) => h.article.guid), ['h1']);
    });

    test('excludes anything published after the end', () async {
      final hits = await articles.search(
        query: 'heatwave',
        to: now.subtract(const Duration(days: 1)),
      );
      expect(hits.map((h) => h.article.guid), ['b1']);
    });

    test('a window takes both ends', () async {
      expect(
        await articles.search(
          query: 'heatwave',
          from: now.subtract(const Duration(days: 5)),
          to: now.subtract(const Duration(days: 1)),
        ),
        hasLength(1),
      );
    });
  });

  group('the index keeps up with the table', () {
    test('a newly fetched item is findable at once', () async {
      expect(await articles.search(query: 'monsoon'), isEmpty);
      await articles.upsert(hindu, [
        item('h9', 'Monsoon withdrawal begins a week early'),
      ]);
      expect(await articles.search(query: 'monsoon'), hasLength(1));
    });

    test('a corrected headline is findable under its new words', () async {
      await articles.upsert(hindu, [
        item('h1', 'Cyclone warning extended for Vidarbha districts'),
      ]);
      expect(await articles.search(query: 'cyclone'), hasLength(1));
      expect(
        await articles.search(query: 'heatwave'),
        hasLength(1),
        reason: 'only the BBC copy is left',
      );
    });

    test('a pruned item leaves the index with it', () async {
      await db.pruneToRetention(keep: 1);
      final hits = await articles.search(query: 'tap-in');
      expect(hits, isEmpty);
    });

    test('results are deduplicated like every other list', () async {
      // The same story through a second feed is one thing to read.
      final mirror = await sources.add(
        title: 'Aggregator',
        feedUrl: 'https://agg.example/rss',
        category: 'India',
      );
      await articles.upsert(mirror, [
        item(
          'a1',
          'Heatwave warning extended for Vidarbha districts',
          ago: const Duration(hours: 2),
        ),
      ]);
      final hits = await articles.search(query: 'Vidarbha');
      expect(hits, hasLength(1));
    });
  });

  /// What the date chip opens on, and what each flag means.
  ///
  /// The two flags look interchangeable and are not: one is about whether
  /// there is a time constraint at all (the copy, and the offer to widen),
  /// the other about whether the reader has narrowed anything (the chip's
  /// dress). Swapping them hides the widening offer on the one screen that
  /// exists to offer it.
  group('the date presets', () {
    test('Search opens on the past week, not on everything', () {
      // "Any time" as the default implied an archive the app has never had:
      // a feed carries its most recent items, so an unbounded search is
      // unbounded over a few days of cache. The default states the scope.
      expect(SearchDateRange.initial.preset, DateRangePreset.week);
      final start = SearchDateRange.initial.start;
      expect(start, isNotNull);
      expect(DateTime.now().difference(start!).inHours, closeTo(24 * 7, 1));
    });

    test('only the unbounded preset applies no constraint', () {
      expect(SearchDateRange.any.start, isNull);
      expect(SearchDateRange.any.isUnbounded, isTrue);
      expect(SearchDateRange.initial.isUnbounded, isFalse);
    });

    test('only the opening range reads as untouched', () {
      expect(SearchDateRange.initial.isInitial, isTrue);
      expect(SearchDateRange.any.isInitial, isFalse);
      expect(const SearchDateRange(DateRangePreset.day).isInitial, isFalse);
    });

    test('the longest option names a corpus, not a period', () {
      // It is the whole of what the last refreshes brought in. Calling it
      // "Any time" is the thing readers reported as broken search.
      expect(DateRangePreset.anyTime.label, 'Everything cached');
    });
  });
}
