import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:headshorts/data/db/article_repository.dart';
import 'package:headshorts/data/db/database.dart';
import 'package:headshorts/data/db/source_repository.dart';
import 'package:headshorts/data/db/tables.dart';
import 'package:headshorts/data/feed/refresh_service.dart';
import 'package:headshorts/data/sources/source_adapter.dart';
import 'package:mocktail/mocktail.dart';

class _MockAdapter extends Mock implements SourceAdapter;

ParsedArticle _article(String guid, {DateTime? at}) => ParsedArticle(
  guid: guid,
  title: 'Headline $guid',
  link: 'https://example.com/$guid',
  publishedAt: at ?? DateTime(2026, 9, 8),
);

void main() {
  late HsDatabase db;
  late SourceRepository sources;
  late ArticleRepository articles;

  setUpAll(() {
    registerFallbackValue(
      const SourceRef(id: 0, feedUrl: '', type: SourceType.rss),
    );
    registerFallbackValue(SourceType.rss);
  });

  setUp(() {
    db = HsDatabase.forTesting(NativeDatabase.memory());
    sources = SourceRepository(db);
    articles = ArticleRepository(db);
  });

  tearDown(() => db.close());

  group('SourceRepository', () {
    test('adding a feed twice keeps one subscription', () async {
      final first = await sources.add(
        title: 'BBC News',
        feedUrl: 'https://example.com/rss',
        category: 'World',
      );
      final second = await sources.add(
        title: 'BBC News (again)',
        feedUrl: 'https://example.com/rss',
        category: 'World',
      );

      expect(second, first);
      expect(await sources.all(), hasLength(1));
    });

    test(
      'a failure records when the silence started, not when it repeated',
      () async {
        final id = await sources.add(
          title: 'The Verge',
          feedUrl: 'https://example.com/verge',
          category: 'Technology',
        );

        await sources.recordFailure(id, 'The address returns a 404.');
        final first = (await sources.all()).single.failingSince;

        await sources.recordFailure(id, 'The address returns a 404.');
        expect((await sources.all()).single.failingSince, first);
      },
    );

    test('a success clears the failure state', () async {
      final id = await sources.add(
        title: 'The Verge',
        feedUrl: 'https://example.com/verge',
        category: 'Technology',
      );
      await sources.recordFailure(id, 'nope');
      await sources.recordSuccess(id, etag: 'W/"1"');

      final row = (await sources.all()).single;
      expect(row.failingSince, isNull);
      expect(row.lastError, isNull);
      expect(row.etag, 'W/"1"');
    });
  });

  group('ArticleRepository', () {
    test('deduplicates on (sourceId, guid) across refreshes', () async {
      final id = await sources.add(
        title: 'Reuters',
        feedUrl: 'https://example.com/reuters',
        category: 'World',
      );

      expect(await articles.upsert(id, [_article('a'), _article('b')]), 2);
      expect(await articles.upsert(id, [_article('a'), _article('c')]), 1);

      final stored = await db.select(db.articles).get();
      expect(stored.map((a) => a.guid), unorderedEquals(['a', 'b', 'c']));
    });

    test(
      'the same guid from a different source is a different article',
      () async {
        final one = await sources.add(
          title: 'One',
          feedUrl: 'https://example.com/one',
          category: 'World',
        );
        final two = await sources.add(
          title: 'Two',
          feedUrl: 'https://example.com/two',
          category: 'World',
        );

        await articles.upsert(one, [_article('shared')]);
        await articles.upsert(two, [_article('shared')]);

        expect(await db.select(db.articles).get(), hasLength(2));
      },
    );

    test(
      'an update does not erase a body the feed has stopped sending',
      () async {
        final id = await sources.add(
          title: 'Ars',
          feedUrl: 'https://example.com/ars',
          category: 'Technology',
        );
        await articles.upsert(id, [
          ParsedArticle(
            guid: 'a',
            title: 'Headline',
            link: 'https://example.com/a',
            publishedAt: DateTime(2026, 9, 8),
            fullContentHtml: '<p>The body.</p>',
          ),
        ]);
        await articles.upsert(id, [_article('a')]);

        expect(
          (await db.select(db.articles).get()).single.fullContentHtml,
          '<p>The body.</p>',
        );
      },
    );

    test('reading in full also marks it seen, and records an event', () async {
      final id = await sources.add(
        title: 'Ars',
        feedUrl: 'https://example.com/ars',
        category: 'Technology',
      );
      await articles.upsert(id, [_article('a')]);
      final article = (await db.select(db.articles).get()).single;

      await articles.markRead(
        article.id,
        mode: ReadMode.full,
        dwell: const Duration(minutes: 3),
      );

      final updated = (await db.select(db.articles).get()).single;
      expect(updated.readInFull, isTrue);
      expect(updated.readInReel, isTrue);

      final events = await db.select(db.readEvents).get();
      expect(events.single.dwellMs, const Duration(minutes: 3).inMilliseconds);
    });
  });

  group('RefreshService', () {
    late _MockAdapter adapter;
    late RefreshService service;

    setUp(() {
      adapter = _MockAdapter();
      when(() => adapter.canHandle(any())).thenReturn(true);
      service = RefreshService(
        database: db,
        sources: sources,
        articles: articles,
        registry: SourceAdapterRegistry([adapter]),
      );
    });

    test('stores fresh items and the new validators', () async {
      final id = await sources.add(
        title: 'BBC',
        feedUrl: 'https://example.com/bbc',
        category: 'World',
      );
      when(() => adapter.fetch(any())).thenAnswer(
        (_) async => FetchResult.fresh(
          articles: [_article('a'), _article('b')],
          etag: 'W/"7"',
        ),
      );

      final last = await service.refreshAll().last;

      expect(last.added, 2);
      expect(last.done, 1);
      expect((await sources.all()).single.etag, 'W/"7"');
      expect(await db.select(db.articles).get(), hasLength(2));
      expect(id, isPositive);
    });

    test('a 304 costs nothing and keeps the cache', () async {
      final id = await sources.add(
        title: 'BBC',
        feedUrl: 'https://example.com/bbc',
        category: 'World',
      );
      await articles.upsert(id, [_article('a')]);
      when(() => adapter.fetch(any()))
          .thenAnswer((_) async => const FetchResult.unchanged());

      final last = await service.refreshAll().last;

      expect(last.added, 0);
      expect(await db.select(db.articles).get(), hasLength(1));
    });

    test('a broken feed is recorded, never thrown', () async {
      await sources.add(
        title: 'The Verge',
        feedUrl: 'https://example.com/verge',
        category: 'Technology',
      );
      when(() => adapter.fetch(any())).thenAnswer(
        (_) async => const FetchResult.failed('The address returns a 404.'),
      );

      await expectLater(service.refreshAll().last, completes);
      final row = (await sources.all()).single;
      expect(row.lastError, 'The address returns a 404.');
      expect(row.failingSince, isNotNull);
    });

    test('one failing feed does not stop the others', () async {
      await sources.add(
        title: 'Good',
        feedUrl: 'https://example.com/good',
        category: 'World',
      );
      await sources.add(
        title: 'Bad',
        feedUrl: 'https://example.com/bad',
        category: 'World',
      );
      when(() => adapter.fetch(any())).thenAnswer((invocation) async {
        final ref = invocation.positionalArguments.first as SourceRef;
        return ref.feedUrl.endsWith('bad')
            ? const FetchResult.failed('nope')
            : FetchResult.fresh(articles: [_article('a')]);
      });

      final last = await service.refreshAll().last;

      expect(last.done, 2);
      expect(last.added, 1);
    });

    test('a disabled source is not fetched', () async {
      final id = await sources.add(
        title: 'Paused',
        feedUrl: 'https://example.com/paused',
        category: 'World',
      );
      await sources.setEnabled(id, enabled: false);

      final last = await service.refreshAll().last;

      expect(last.total, 0);
      verifyNever(() => adapter.fetch(any()));
    });
  });

  group('SourceAdapterRegistry', () {
    test('resolves the adapter that claims the type', () {
      final rss = _MockAdapter();
      when(() => rss.canHandle(SourceType.rss)).thenReturn(true);

      expect(SourceAdapterRegistry([rss]).resolve(SourceType.rss), rss);
    });

    test('is explicit when no adapter is registered', () {
      final none = _MockAdapter();
      when(() => none.canHandle(any())).thenReturn(false);

      expect(
        () => SourceAdapterRegistry([none]).resolve(SourceType.rss),
        throwsStateError,
      );
    });
  });
}
