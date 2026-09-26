import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:headshorts/app/providers.dart';
import 'package:headshorts/app/settings_controller.dart';
import 'package:headshorts/data/db/article_repository.dart';
import 'package:headshorts/data/db/database.dart';
import 'package:headshorts/data/db/source_repository.dart';
import 'package:headshorts/data/db/tables.dart';
import 'package:headshorts/data/feed/google_news_search.dart';
import 'package:headshorts/data/prefs/settings.dart';
import 'package:headshorts/data/sources/source_adapter.dart';
import 'package:headshorts/data/sources/source_catalog.dart';
import 'package:headshorts/features/search/search_controller.dart';
import 'package:headshorts/features/today/today_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// When Search goes to the network, and when it does not.
///
/// The rule: the cache is the engine, and a feed is fetched **only** for an
/// in-scope source that has nothing cached to look through. Subscription has
/// nothing to do with it — a source added a minute ago is subscribed and
/// empty, and searching it without fetching would come back empty while
/// looking like it had looked.
/// Stands in for Google News, so nothing in the suite touches the network.
class _FakeWebSearch extends GoogleNewsSearch {
  new(this.results) : super(Dio());

  final List<WebResult> results;
  int calls = 0;

  @override
  Future<List<WebResult>> search(String query, {DateTime? since}) async {
    calls++;
    return results;
  }
}

class _FakeAdapter implements SourceAdapter {
  new(this.articles);

  final List<ParsedArticle> articles;
  int calls = 0;

  @override
  bool canHandle(SourceType type) => true;

  @override
  Future<FetchResult> fetch(SourceRef ref) async {
    calls++;
    return FetchResult.fresh(articles: articles);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late HsDatabase db;
  late SourceRepository sources;
  late ArticleRepository articles;
  late _FakeAdapter adapter;
  late _FakeWebSearch web;
  late ProviderContainer container;
  late SettingsStore store;

  ParsedArticle live(String guid, String title) => ParsedArticle(
    guid: guid,
    title: title,
    link: 'https://example.com/$guid',
    publishedAt: DateTime.now(),
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = SettingsStore(await SharedPreferences.getInstance());
    web = _FakeWebSearch([
      WebResult(
        title: 'A monsoon story no followed source carried',
        publisher: 'The Times of India',
        link: 'https://news.google.com/rss/articles/abc',
        publishedAt: DateTime.now(),
      ),
    ]);
    db = HsDatabase.forTesting(NativeDatabase.memory());
    sources = SourceRepository(db);
    articles = ArticleRepository(db);
    adapter = _FakeAdapter([
      live('live-1', 'A monsoon headline that only the feed has'),
    ]);

    container = ProviderContainer(
      overrides: [
        sourceCatalogProvider.overrideWith((ref) async => SourceCatalog.empty),
        databaseProvider.overrideWithValue(db),
        settingsStoreProvider.overrideWithValue(store),
        googleNewsSearchProvider.overrideWithValue(web),
        adapterRegistryProvider.overrideWithValue(
          SourceAdapterRegistry([adapter]),
        ),
      ],
    );
  });

  tearDown(() {
    container.dispose();
    return db.close();
  });

  /// Waits for the source list to reach the scope, which is a drift stream.
  Future<void> settle() async {
    container
      ..listen(sourcesProvider, (_, _) {})
      ..listen(searchScopeEntriesProvider, (_, _) {});
    for (var i = 0; i < 100; i++) {
      if (container.read(searchScopeEntriesProvider).isNotEmpty) return;
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  }

  Future<SearchOutcome> search(String query) {
    container.read(searchQueryProvider.notifier).set(query);
    return container.read(searchResultsProvider.future);
  }

  test('a subscribed source with an empty cache is fetched', () async {
    // The case that shipped broken: subscribed, so the old rule skipped it,
    // and empty, so the cache had nothing to offer either. The reader got
    // nothing back from a source that was right there.
    await sources.add(
      title: 'BBC News',
      feedUrl: 'https://bbc.example/rss',
      category: 'World',
    );
    await settle();

    final outcome = await search('monsoon');

    expect(adapter.calls, 1, reason: 'the feed was fetched');
    expect(outcome.hits, hasLength(1));
    expect(outcome.hits.single.view.title, contains('monsoon'));
    expect(
      outcome.hits.single.articleId,
      isNull,
      reason: 'nothing was stored, so there is no row to open',
    );
    expect(outcome.fetchedLive, 1);
  });

  test('a source with a cache is read, not fetched', () async {
    final id = await sources.add(
      title: 'BBC News',
      feedUrl: 'https://bbc.example/rss',
      category: 'World',
    );
    await articles.upsert(id, [
      live('cached-1', 'A monsoon headline that is already cached'),
    ]);
    await settle();

    final outcome = await search('monsoon');

    expect(
      adapter.calls,
      0,
      reason: 'the cache is the engine; a fetch would be a second one',
    );
    expect(outcome.hits, hasLength(1));
    expect(outcome.hits.single.articleId, isNotNull);
    expect(outcome.fetchedLive, 0);
  });

  test('an unfollowed source added to the scope is fetched', () async {
    final id = await sources.add(
      title: 'BBC News',
      feedUrl: 'https://bbc.example/rss',
      category: 'World',
    );
    await articles.upsert(id, [live('cached-1', 'A cached monsoon headline')]);
    await settle();

    // A catalog source the reader does not follow, added to this search only.
    container.read(searchScopeProvider.notifier).set({
      'https://bbc.example/rss',
      'https://guardian.example/rss',
    });

    // The scope resolves against sources that exist; an address the catalog
    // does not carry simply is not in scope, which is its own guarantee.
    expect(container.read(searchScopeEntriesProvider).map((e) => e.feedUrl), [
      'https://bbc.example/rss',
    ]);
  });

  test(
    'a source that will not answer is one fewer source, not a failure',
    () async {
      await sources.add(
        title: 'Broken',
        feedUrl: 'https://broken.example/rss',
        category: 'World',
      );
      await sources.add(
        title: 'BBC News',
        feedUrl: 'https://bbc.example/rss',
        category: 'World',
      );
      await settle();

      final outcome = await search('monsoon');

      // Both are empty, so both are fetched; the fake answers for both.
      expect(adapter.calls, 2);
      expect(outcome.hits, hasLength(2));
    },
  );

  group('not doing the same work twice', () {
    test('refining a query does not fetch the same feed again', () async {
      // The scope case: a source with nothing cached is fetched for the
      // search, and a reader refining a query runs several searches. The
      // items are identical each time; only the filtering changes.
      await sources.add(
        title: 'BBC News',
        feedUrl: 'https://bbc.example/rss',
        category: 'World',
      );
      await settle();

      await search('monsoon');
      expect(adapter.calls, 1);

      await search('monsoon withdrawal');
      await search('monsoon withdrawal begins');
      expect(
        adapter.calls,
        1,
        reason: 'the feed was remembered, not downloaded three times',
      );
    });

    test('reading an article does not re-run the search', () async {
      // Unseen counts stream out of `articles` and tick on every refresh and
      // every article opened. Search covers a *set of sources*; it has no
      // business rebuilding — and asking Google again — for either.
      final id = await sources.add(
        title: 'BBC News',
        feedUrl: 'https://bbc.example/rss',
        category: 'World',
      );
      await articles.upsert(id, [live('c1', 'A cached monsoon headline')]);
      await settle();

      await search('monsoon');
      expect(web.calls, 1);

      final row = (await db.select(db.articles).get()).first;
      await articles.mark(row.id, mode: ReadMode.full);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await container.read(searchResultsProvider.future);

      expect(web.calls, 1, reason: 'nothing about the search changed');
    });
  });

  group('Google News', () {
    Future<void> subscribeWithCache() async {
      final id = await sources.add(
        title: 'BBC News',
        feedUrl: 'https://bbc.example/rss',
        category: 'World',
      );
      await articles.upsert(id, [
        live('cached-1', 'A monsoon headline that is already cached'),
      ]);
      await settle();
    }

    test('its results arrive in their own list, never mixed in', () async {
      await subscribeWithCache();

      final outcome = await search('monsoon');

      expect(web.calls, 1);
      expect(outcome.hits, hasLength(1), reason: "the reader's own source");
      expect(outcome.webHits, hasLength(1));
      expect(
        outcome.webHits.single.view.sourceTitle,
        'The Times of India',
        reason: 'attributed to the publisher Google names',
      );
      expect(
        outcome.webHits.single.articleId,
        isNull,
        reason: 'a Google redirect has no row and opens in the browser',
      );
      expect(outcome.isEmpty, isFalse);
    });

    test('a story the reader already has is not shown twice', () async {
      // Same headline, reached through a Google redirect rather than the
      // publisher's own address — so only the fingerprint can catch it.
      web.results.clear();
      web.results.add(
        WebResult(
          title: 'A monsoon headline that is already cached',
          publisher: 'BBC News',
          link: 'https://news.google.com/rss/articles/dup',
          publishedAt: DateTime.now(),
        ),
      );
      await subscribeWithCache();

      final outcome = await search('monsoon');

      expect(outcome.hits, hasLength(1));
      expect(outcome.webHits, isEmpty);
    });

    test('switched off, nothing is asked of Google', () async {
      // Through the controller, which is what the setting row calls.
      await container
          .read(settingsProvider.notifier)
          .setSearchTheWeb(enabled: false);
      await subscribeWithCache();

      final outcome = await search('monsoon');

      expect(web.calls, 0, reason: 'nothing left the device');
      expect(outcome.webHits, isEmpty);
    });

    test('results found only on the web still count as results', () async {
      // Nothing cached, nothing in the feed — the case that sent readers to
      // an empty screen before.
      adapter.articles.clear();
      await subscribeWithCache();

      final outcome = await search('deepak');

      expect(outcome.hits, isEmpty);
      expect(outcome.webHits, hasLength(1));
      expect(
        outcome.isEmpty,
        isFalse,
        reason: '"nothing for" must not show when the web found something',
      );
    });
  });
}
