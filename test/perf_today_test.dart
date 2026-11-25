import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:headshorts/app/providers.dart';
import 'package:headshorts/app/refresh_controller.dart';
import 'package:headshorts/core/theme/hs_theme.dart';
import 'package:headshorts/core/tokens/palette.dart';
import 'package:headshorts/data/db/article_repository.dart';
import 'package:headshorts/data/db/database.dart';
import 'package:headshorts/data/db/source_repository.dart';
import 'package:headshorts/data/db/tables.dart';
import 'package:headshorts/data/feed/refresh_service.dart';
import 'package:headshorts/data/prefs/settings.dart';
import 'package:headshorts/data/sources/source_adapter.dart';
import 'package:headshorts/features/today/today_controller.dart';
import 'package:headshorts/features/today/today_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Distinct words, so no two headlines fingerprint alike.
const _words = [
  'monsoon',
  'shipping',
  'railway',
  'harvest',
  'election',
  'inflation',
  'glacier',
  'vaccine',
  'satellite',
  'orchestra',
  'referendum',
  'archipelago',
  'quarantine',
  'brewery',
  'telescope',
  'sediment',
  'cathedral',
  'plankton',
  'tungsten',
  'lighthouse',
];

ParsedArticle _article(int n, {DateTime? at}) => ParsedArticle(
  guid: 'g$n',
  title:
      '${_words[n % 20]} ${_words[(n * 7 + 3) % 20]} '
      '${_words[(n * 13 + 5) % 20]} ${_words[(n * 3 + 11) % 20]} story$n',
  link: 'https://example.com/story/$n',
  publishedAt: at ?? DateTime.now().subtract(Duration(hours: n + 1)),
);

class _FakeRefresh extends RefreshController {
  @override
  RefreshProgress build() => RefreshProgress.idle;

  @override
  Future<void> refreshIfDue() async {}

  @override
  Future<void> refresh() async {}
}

void main() {
  late HsDatabase db;
  late SourceRepository sources;
  late ArticleRepository articles;
  late SettingsStore store;
  late int sourceId;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = SettingsStore(await SharedPreferences.getInstance());
    db = HsDatabase.forTesting(NativeDatabase.memory());
    sources = SourceRepository(db);
    articles = ArticleRepository(db);
    sourceId = await sources.add(
      title: 'One',
      feedUrl: 'https://example.com/feed',
      category: 'World',
    );
  });

  tearDown(() => db.close());

  Future<void> seed(int count) =>
      articles.upsert(sourceId, [for (var i = 0; i < count; i++) _article(i)]);

  ProviderContainer container({List<Override> extra = const []}) {
    final c = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        settingsStoreProvider.overrideWithValue(store),
        databaseProvider.overrideWithValue(db),
        ...extra,
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  Future<void> settle() => Future<void>.delayed(
    briefingThrottle + const Duration(milliseconds: 150),
  );

  group('paging keeps the list', () {
    test('loadMore never leaves the list without a value', () async {
      await seed(80);
      final c = container();
      final states = <AsyncValue<List<Headline>>>[];
      c.listen(
        briefingProvider,
        (_, next) => states.add(next),
        fireImmediately: true,
      );
      await settle();
      final first = c.read(briefingProvider).requireValue.length;

      await c.read(todayPaginationProvider.notifier).loadMore();
      await settle();

      expect(c.read(briefingProvider).requireValue.length, greaterThan(first));
      final loadedOnce = states.indexWhere((s) => s.hasValue);
      expect(
        states.skip(loadedOnce).every((s) => s.hasValue),
        isTrue,
        reason: 'a page turn is the same list growing, never a skeleton',
      );
    });

    test('a page turn under a held head never shrinks the list', () async {
      await seed(200);
      final c = container();
      c.listen(briefingProvider, (_, _) {});
      await settle();
      final head = c.read(briefingProvider).requireValue.first.article;
      c
          .read(todayHeldProvider.notifier)
          .hold(ArticleCursor(head.publishedAt, head.id));
      // Sixty newer items arrive while the reader is down the list.
      final now = DateTime.now();
      await articles.upsert(sourceId, [
        for (var i = 1000; i < 1060; i++)
          _article(i, at: now.subtract(Duration(seconds: i - 999))),
      ]);
      await settle();
      final held = c.read(briefingProvider).requireValue.length;

      await c.read(todayPaginationProvider.notifier).loadMore();
      await settle();
      final after = c.read(briefingProvider).requireValue;
      expect(after.length, greaterThanOrEqualTo(held));
      expect(after.first.article.id, head.id);
    });

    test(
      'the scope is the same across a page turn and new across a filter',
      () async {
        await seed(60);
        final c = container()..listen(briefingProvider, (_, _) {});
        final scope = c.read(briefingScopeProvider);

        await c.read(todayPaginationProvider.notifier).loadMore();
        expect(c.read(briefingScopeProvider), scope);

        c.read(mutedSourcesProvider.notifier).toggle(sourceId, visible: false);
        expect(c.read(briefingScopeProvider), isNot(scope));
      },
    );
  });

  group('new stories do not move the list', () {
    test(
      'a held head hides arrivals and says only that something is waiting',
      () async {
        await seed(10);
        final c = container()
          ..listen(briefingProvider, (_, _) {})
          ..listen(newerWaitingProvider, (_, _) {});
        await settle();
        final head = c.read(briefingProvider).requireValue.first;

        c.read(todayHeldProvider.notifier).hold(head.cursor);
        await settle();
        await articles.upsert(sourceId, [_article(100, at: DateTime.now())]);
        await settle();

        final held = c.read(briefingProvider).requireValue;
        expect(held.first.article.id, head.article.id);
        expect(held.any((h) => h.article.guid == 'g100'), isFalse);
        expect(c.read(newerWaitingProvider).value, isTrue);

        c.read(todayHeldProvider.notifier).release();
        await settle();
        expect(
          c.read(briefingProvider).requireValue.first.article.guid,
          'g100',
        );
        expect(c.read(newerWaitingProvider).value, isFalse);
      },
    );

    test('holding twice keeps the first position', () {
      final c = container();
      final hold = c.read(todayHeldProvider.notifier);
      final a = ArticleCursor(DateTime(2026, 1, 2), 5);
      hold
        ..hold(a)
        ..hold(ArticleCursor(DateTime(2026, 1, 3), 9));
      expect(c.read(todayHeldProvider), a);
    });

    test('a different filter lets go of the hold', () {
      final c = container();
      c.read(todayHeldProvider.notifier).hold(ArticleCursor(DateTime(2026), 1));
      c.read(mutedSourcesProvider.notifier).toggle(1, visible: false);
      expect(c.read(todayHeldProvider), isNull);
    });
  });

  group('the screen', () {
    // The database runs on the real clock; the widget tree on the test's. So
    // writes go through `runAsync`, and a settle lets both clocks turn.
    Future<void> settleScreen(WidgetTester tester) async {
      for (var i = 0; i < 3; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 30)),
        );
        await tester.pump(briefingThrottle + const Duration(milliseconds: 50));
      }
      await tester.pumpAndSettle();
    }

    Future<void> pump(WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(372, 780));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        ProviderScope(
          retry: (_, _) => null,
          overrides: [
            settingsStoreProvider.overrideWithValue(store),
            databaseProvider.overrideWithValue(db),
            refreshProvider.overrideWith(_FakeRefresh.new),
          ],
          child: MaterialApp(
            theme: buildHsTheme(HsPalette.amoled),
            home: const Scaffold(body: TodayScreen()),
          ),
        ),
      );
      await settleScreen(tester);
    }

    // Unmounted, with the clock let run, so no stream-closing timer is left on
    // the test's clock for the database's `close` to wait on.
    Future<void> unmount(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    }

    double? topOfVisibleRow(WidgetTester tester) {
      for (final text in tester.widgetList<Text>(
        find.textContaining('story'),
      )) {
        final y = tester.getTopLeft(find.byWidget(text)).dy;
        if (y > 250 && y < 500) return y;
      }
      return null;
    }

    testWidgets('arrivals wait behind "Latest stories" while scrolled', (
      tester,
    ) async {
      await tester.runAsync(() => seed(40));
      await pump(tester);

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
      await settleScreen(tester);
      final title = tester
          .widgetList<Text>(find.textContaining('story'))
          .firstWhere((t) {
            final y = tester.getTopLeft(find.byWidget(t)).dy;
            return y > 250 && y < 500;
          })
          .data!;
      final before = tester.getTopLeft(find.text(title)).dy;

      await tester.runAsync(
        () => articles.upsert(sourceId, [_article(100, at: DateTime.now())]),
      );
      await settleScreen(tester);

      expect(
        tester.getTopLeft(find.text(title)).dy,
        before,
        reason: 'the row under the thumb did not move',
      );
      expect(topOfVisibleRow(tester), isNotNull);
      expect(find.text('Latest stories'), findsOneWidget);
      expect(find.textContaining('story100'), findsNothing);

      await tester.tap(find.text('Latest stories'));
      await settleScreen(tester);
      expect(find.textContaining('story100'), findsOneWidget);
      expect(find.text('Latest stories'), findsNothing);
      await unmount(tester);
    });

    testWidgets('the day is marked caught up only at the end of the cache', (
      tester,
    ) async {
      await tester.runAsync(() => seed(30));
      await pump(tester);
      expect(
        await tester.runAsync(() => db.select(db.caughtUpDays).get()),
        isEmpty,
        reason: 'the end of the list has not been reached',
      );

      for (var i = 0; i < 3; i++) {
        await tester.drag(
          find.byType(CustomScrollView),
          const Offset(0, -20000),
        );
        await settleScreen(tester);
      }

      expect(find.textContaining('caught up'), findsWidgets);
      expect(
        await tester.runAsync(() => db.select(db.caughtUpDays).get()),
        hasLength(1),
      );
      await unmount(tester);
    });
  });

  group('coming back', () {
    Future<void> fetched(int daysAgo, {bool failing = false}) async {
      await sources.recordSuccess(sourceId);
      await db
          .update(db.sources)
          .write(
            SourcesCompanion(
              lastFetchedAt: Value(
                DateTime.now().subtract(Duration(days: daysAgo)),
              ),
              failingSince: failing
                  ? Value(DateTime.now().subtract(const Duration(days: 2)))
                  : const Value(null),
            ),
          );
    }

    ProviderContainer withAdapter(_Counter counter) => container(
      extra: [
        adapterRegistryProvider.overrideWithValue(
          SourceAdapterRegistry([counter]),
        ),
      ],
    );

    test('one fresh source does not make the stale ones look fresh', () async {
      await fetched(2);
      await sources.add(
        title: 'Two',
        feedUrl: 'https://two.example.com/rss',
        category: 'World',
      );
      await (db.update(db.sources)
            ..where((s) => s.feedUrl.equals('https://two.example.com/rss')))
          .write(SourcesCompanion(lastFetchedAt: Value(DateTime.now())));
      final counter = _Counter();
      final c = withAdapter(counter);

      await c.read(refreshProvider.notifier).refreshIfDue();
      expect(counter.calls, greaterThan(0), reason: 'the oldest decides');
    });

    test('a failing source does not force a refresh on every resume', () async {
      await fetched(5, failing: true);
      await sources.add(
        title: 'Two',
        feedUrl: 'https://two.example.com/rss',
        category: 'World',
      );
      await (db.update(db.sources)
            ..where((s) => s.feedUrl.equals('https://two.example.com/rss')))
          .write(SourcesCompanion(lastFetchedAt: Value(DateTime.now())));
      final counter = _Counter();
      final c = withAdapter(counter);

      await c.read(refreshProvider.notifier).refreshIfDue();
      expect(counter.calls, 0);
    });

    test(
      'every source failing is being offline, not a reason to stop',
      () async {
        await fetched(2, failing: true);
        final counter = _Counter();
        final c = withAdapter(counter);

        await c.read(refreshProvider.notifier).refreshIfDue();
        expect(counter.calls, greaterThan(0));
      },
    );

    test('onResume wakes the streams, then refreshes if due', () async {
      await seed(3);
      await fetched(2);
      final counter = _Counter();
      final c = withAdapter(counter);
      final lengths = <int>[];
      c.listen(
        briefingProvider,
        (_, next) => next.whenData((l) => lengths.add(l.length)),
        fireImmediately: true,
      );
      await settle();
      expect(lengths.last, 3);

      // A write drift was not told about, as a headless engine would make.
      await db.customStatement('DELETE FROM articles');
      await c.read(refreshProvider.notifier).onResume();
      await settle();

      expect(lengths.last, 0);
      expect(counter.calls, 1, reason: 'due after two days');
    });

    test('a reader who was away is told once, after the refresh', () async {
      await fetched(10);
      final c = withAdapter(_Counter())..listen(awayNoticeProvider, (_, _) {});
      expect(c.read(awayNoticeProvider), isFalse);

      await c.read(refreshProvider.notifier).refresh();
      expect(c.read(awayNoticeProvider), isTrue);
    });

    test('a reader who was not away is not told', () async {
      await fetched(1);
      final c = withAdapter(_Counter())..listen(awayNoticeProvider, (_, _) {});

      await c.read(refreshProvider.notifier).refresh();
      expect(c.read(awayNoticeProvider), isFalse);
    });
  });
}

class _Counter implements SourceAdapter {
  int calls = 0;

  @override
  bool canHandle(SourceType type) => true;

  @override
  Future<FetchResult> fetch(SourceRef ref) async {
    calls++;
    return const FetchResult.fresh(articles: []);
  }
}
