import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:headshorts/app/providers.dart';
import 'package:headshorts/data/db/article_repository.dart';
import 'package:headshorts/data/db/database.dart';
import 'package:headshorts/data/db/source_repository.dart';
import 'package:headshorts/data/db/tables.dart';
import 'package:headshorts/data/feed/refresh_service.dart';
import 'package:headshorts/data/sources/source_adapter.dart';
import 'package:headshorts/features/today/today_controller.dart';

/// An adapter that answers from a script, records the order it was called in,
/// and can be told to hang or to throw.
class _ScriptedAdapter implements SourceAdapter {
  new(this.script);

  final Map<String, FetchResult Function()> script;
  final List<String> inFlight = <String>[];
  int peakConcurrency = 0;

  @override
  bool canHandle(SourceType type) => type == SourceType.rss;

  @override
  Future<FetchResult> fetch(SourceRef ref) async {
    inFlight.add(ref.feedUrl);
    peakConcurrency = peakConcurrency < inFlight.length
        ? inFlight.length
        : peakConcurrency;
    await Future<void>.delayed(const Duration(milliseconds: 5));
    inFlight.remove(ref.feedUrl);
    return (script[ref.feedUrl] ??
        () => const FetchResult.fresh(articles: []))();
  }
}

ParsedArticle _article(String guid, {String? title}) => ParsedArticle(
  guid: guid,
  title: title ?? 'Something specific and distinct happened in $guid today',
  link: 'https://example.com/$guid',
  publishedAt: DateTime(2026, 9, 8, 12),
);

void main() {
  late HsDatabase db;
  late SourceRepository sources;
  late ArticleRepository articles;

  setUp(() {
    db = HsDatabase.forTesting(NativeDatabase.memory());
    sources = SourceRepository(db);
    articles = ArticleRepository(db);
  });

  tearDown(() => db.close());

  Future<int> add(String name) => sources.add(
    title: name,
    feedUrl: 'https://$name.example.com/rss',
    category: 'World',
  );

  RefreshService service(SourceAdapter adapter) => RefreshService(
    database: db,
    sources: sources,
    articles: articles,
    registry: SourceAdapterRegistry([adapter]),
  );

  group('the first briefing', () {
    test(
      'a feed that throws does not take the rest of the run with it',
      () async {
        await add('good');
        await add('bad');
        await add('alsogood');

        final adapter = _ScriptedAdapter({
          'https://good.example.com/rss': () =>
              FetchResult.fresh(articles: [_article('g1'), _article('g2')]),
          'https://bad.example.com/rss': () => throw StateError('malformed'),
          'https://alsogood.example.com/rss': () =>
              FetchResult.fresh(articles: [_article('a1')]),
        });

        final progress = await service(adapter).refreshAll().toList();

        // Every feed reported, and the two healthy ones stored their items.
        expect(progress.last.done, 3);
        expect(await db.select(db.articles).get(), hasLength(3));

        final broken = (await sources.all()).firstWhere(
          (s) => s.title == 'bad',
        );
        expect(broken.lastError, isNotNull);
        expect(broken.failingSince, isNotNull);
      },
    );

    test('a feed that hangs is timed out, not waited on forever', () async {
      await add('slow');
      final adapter = _HangingAdapter();

      final progress = await service(adapter)
          .refreshAll()
          .toList()
          .timeout(const Duration(seconds: 30));

      expect(progress.last.done, 1);
      final slow = (await sources.all()).single;
      expect(slow.lastError, contains('too long'));
    }, timeout: const Timeout(Duration(seconds: 40)));

    test('no more than `concurrency` feeds are in flight at once', () async {
      for (var i = 0; i < 20; i++) {
        await add('feed$i');
      }
      final adapter = _ScriptedAdapter({});

      await service(adapter).refreshAll().drain<void>();

      expect(
        adapter.peakConcurrency,
        lessThanOrEqualTo(RefreshService.concurrency),
      );
      expect(adapter.peakConcurrency, greaterThan(1));
    });

    test('the run is only "finished" once every feed has reported', () async {
      await add('one');
      await add('two');
      final adapter = _ScriptedAdapter({
        'https://one.example.com/rss': () =>
            FetchResult.fresh(articles: [_article('x')]),
      });

      final progress = await service(adapter).refreshAll().toList();

      // Nothing claims completion mid-run — that flag is what stops Today
      // saying "You're caught up" over a cache that is still filling.
      expect(progress.where((p) => p.finished), hasLength(1));
      expect(progress.last.finished, isTrue);
      expect(progress.last.done, progress.last.total);
    });

    test('onboarding and a later refresh return the same items', () async {
      // Onboarding: subscribe, then fetch.
      await add('paper');
      final adapter = _ScriptedAdapter({
        // Genuinely distinct headlines: the de-duplicator collapses ones that
        // fingerprint alike, and three variations on one sentence do.
        'https://paper.example.com/rss': () => FetchResult.fresh(
          articles: [
            _article('one', title: 'Rail operators trial a single fare cap'),
            _article('two', title: 'Monsoon rains close two mountain passes'),
            _article('three', title: 'Chip maker delays its next factory'),
          ],
        ),
      });

      await service(adapter).refreshAll().drain<void>();
      final afterOnboarding = await articles.watchBriefing().first;

      // The same pipeline, run again the way the refresh mark runs it.
      await service(adapter).refreshAll().drain<void>();
      final afterRefresh = await articles.watchBriefing().first;

      expect(afterOnboarding, hasLength(3));
      expect(
        afterRefresh.map((h) => h.article.guid),
        afterOnboarding.map((h) => h.article.guid),
      );
    });

    test(
      'items are stored before the validators that would 304 them',
      () async {
        await add('paper');
        // The first run stores items and an ETag.
        var body = [_article('one')];
        final adapter = _ScriptedAdapter({
          'https://paper.example.com/rss': () =>
              FetchResult.fresh(articles: body, etag: 'v1'),
        });
        await service(adapter).refreshAll().drain<void>();

        expect(await db.select(db.articles).get(), hasLength(1));
        expect((await sources.all()).single.etag, 'v1');

        // A later 304 keeps what was stored rather than emptying it.
        body = [];
        final unchanged = _ScriptedAdapter({
          'https://paper.example.com/rss': () => const FetchResult.unchanged(),
        });
        await service(unchanged).refreshAll().drain<void>();

        expect(await db.select(db.articles).get(), hasLength(1));
      },
    );
  });

  group('Today never filters on when the app was installed', () {
    test('an item published before the source was added still shows', () async {
      final id = await add('archive');
      await articles.upsert(id, [
        ParsedArticle(
          guid: 'old',
          title: 'A story filed well before this reader ever opened the app',
          link: 'https://example.com/old',
          // Two years before the subscription existed.
          publishedAt: DateTime(2024),
        ),
      ]);

      final briefing = await articles.watchBriefing().first;
      expect(briefing, hasLength(1));
    });
  });

  group('the categories derive from the sources', () {
    test('adding a source in a new category adds it live', () async {
      final container = ProviderContainer(
        overrides: [sourceRepositoryProvider.overrideWithValue(sources)],
      );
      addTearDown(container.dispose);

      final tabs = container.listen(
        categoriesProvider,
        (_, _) {},
        fireImmediately: true,
      );
      await container.read(categoriesProvider.future);
      expect(tabs.read().value, [latestScope]);

      await sources.add(
        title: 'A tech site',
        feedUrl: 'https://tech.example.com/rss',
        category: 'Technology',
      );
      await pumpEventQueue();
      expect(tabs.read().value, [latestScope, 'Technology']);

      await sources.add(
        title: 'A business site',
        feedUrl: 'https://biz.example.com/rss',
        category: 'Business',
      );
      await pumpEventQueue();
      // Ordered the way the sources are — sortOrder, then title — so
      // "A business site" leads. What matters is that both categories are there.
      expect(
        tabs.read().value,
        containsAll([latestScope, 'Technology', 'Business']),
      );
      expect(tabs.read().value, hasLength(3));
    });

    test('a selection whose category has gone falls back to Latest', () async {
      final id = await sources.add(
        title: 'A tech site',
        feedUrl: 'https://tech.example.com/rss',
        category: 'Technology',
      );
      final container = ProviderContainer(
        overrides: [sourceRepositoryProvider.overrideWithValue(sources)],
      );
      addTearDown(container.dispose);

      container.listen(categoriesProvider, (_, _) {}, fireImmediately: true);
      await container.read(categoriesProvider.future);
      container.read(selectedCategoryProvider.notifier).select('Technology');
      expect(container.read(activeCategoryProvider), 'Technology');

      // Pausing the only source in it takes the category away.
      await sources.setEnabled(id, enabled: false);
      await pumpEventQueue();

      expect(container.read(activeCategoryProvider), latestScope);
    });
  });
}

/// Never answers. The pipeline has to give up on it by itself.
class _HangingAdapter implements SourceAdapter {
  @override
  bool canHandle(SourceType type) => true;

  @override
  Future<FetchResult> fetch(SourceRef ref) => Completer<FetchResult>().future;
}
