import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:headshorts/app/providers.dart';
import 'package:headshorts/data/db/article_repository.dart';
import 'package:headshorts/data/db/database.dart';
import 'package:headshorts/data/db/source_repository.dart';
import 'package:headshorts/data/db/tables.dart';
import 'package:headshorts/data/sources/source_adapter.dart';
import 'package:headshorts/features/linger/linger_controller.dart';

/// Distinct words, so no two headlines fingerprint alike — near-identical
/// titles are collapsed by de-duplication, which is not what these tests are
/// about.
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

/// Items a minute apart, newest first.
ParsedArticle _article(int n) => ParsedArticle(
  guid: 'g$n',
  title:
      '${_words[n % _words.length]} ${_words[(n * 7 + 3) % _words.length]} '
      '${_words[(n * 13 + 5) % _words.length]} ${_words[(n * 3 + 11) % _words.length]} '
      'report$n',
  link: 'https://example.com/story/$n',
  publishedAt: DateTime(2026, 9, 8, 12).subtract(Duration(minutes: n)),
);

void main() {
  late HsDatabase db;
  late SourceRepository sources;
  late ArticleRepository articles;
  late int sourceId;

  setUp(() async {
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

  Future<void> seed(int count, {int from = 0}) => articles.upsert(sourceId, [
    for (var i = from; i < from + count; i++) _article(i),
  ]);

  group('keyset pagination', () {
    test('the first page is bounded and newest first', () async {
      await seed(80);

      final page = await articles.watchBriefing(pageSize: 10).first;

      expect(page, hasLength(20)); // over-fetched so dedup can still fill
      expect(page.first.article.title, contains('report0'));
      for (var i = 1; i < page.length; i++) {
        expect(
          page[i].article.publishedAt.isBefore(page[i - 1].article.publishedAt),
          isTrue,
        );
      }
    });

    test(
      'each page extends the window without skipping or repeating',
      () async {
        await seed(80);

        final first = await articles.watchBriefing(pageSize: 10).first;
        final floor = await articles.nextFloor(
          floor: first.last.cursor,
          pageSize: 10,
        );
        final extended = await articles
            .watchBriefing(floor: floor, pageSize: 10)
            .first;

        expect(extended.length, greaterThan(first.length));
        // Everything from the first page is still there, in the same order.
        expect(
          extended.take(first.length).map((h) => h.article.id),
          first.map((h) => h.article.id),
        );
        // And no item appears twice.
        final ids = extended.map((h) => h.article.id).toList();
        expect(ids.toSet(), hasLength(ids.length));
      },
    );

    test('reports the end of the cache rather than looping', () async {
      await seed(8);

      final page = await articles.watchBriefing(pageSize: 10).first;
      final floor = await articles.nextFloor(
        floor: page.last.cursor,
        pageSize: 10,
      );

      expect(floor, isNull, reason: 'nothing below the last item');
    });

    test(
      'new items prepend without shifting the window off the bottom',
      () async {
        await seed(40);
        final first = await articles.watchBriefing(pageSize: 10).first;
        final floor = await articles.nextFloor(
          floor: first.last.cursor,
          pageSize: 10,
        );
        final before = await articles
            .watchBriefing(floor: floor, pageSize: 10)
            .first;

        // A refresh brings in five newer items.
        await articles.upsert(sourceId, [
          for (var i = 1; i <= 5; i++)
            ParsedArticle(
              guid: 'new$i',
              title:
                  'fresh ${_words[i]} ${_words[i + 2]} ${_words[i + 4]} '
                  'dispatch$i',
              link: 'https://example.com/fresh/$i',
              publishedAt: DateTime(2026, 9, 8, 13).add(Duration(minutes: i)),
            ),
        ]);

        final after = await articles
            .watchBriefing(floor: floor, pageSize: 10)
            .first;

        expect(after.length, before.length + 5);
        // The new ones are on top and nothing dropped off the bottom.
        expect(after.first.article.title, startsWith('fresh '));
        expect(after.last.article.id, before.last.article.id);
      },
    );

    test('ties on publishedAt are still a total order', () async {
      final sameMinute = DateTime(2026, 9, 8, 12);
      await articles.upsert(sourceId, [
        for (var i = 0; i < 6; i++)
          ParsedArticle(
            guid: 'tie$i',
            title: '${_words[i]} ${_words[i + 3]} ${_words[i + 6]} tie$i',
            link: 'https://example.com/tie/$i',
            publishedAt: sameMinute,
          ),
      ]);

      final page = await articles.watchBriefing(pageSize: 2).first;
      final ids = page.map((h) => h.article.id).toList();

      expect(ids, [...ids]..sort((a, b) => b.compareTo(a)));
      final floor = await articles.nextFloor(
        floor: page.last.cursor,
        pageSize: 2,
      );
      expect(floor, isNotNull);
      expect(floor!.id, lessThan(page.last.article.id));
    });
  });

  group("Linger's queue", () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);
    });

    Future<LingerQueue> settled() async {
      var state = container.read(lingerQueueProvider);
      for (var i = 0; i < 50 && state.loading; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        state = container.read(lingerQueueProvider);
      }
      return state;
    }

    test('holds only unseen, unread items', () async {
      await seed(5);
      final rows = await db.select(db.articles).get();
      await articles.mark(rows.first.id, mode: ReadMode.linger);
      await articles.mark(rows[1].id, mode: ReadMode.full);

      container.read(lingerQueueProvider);
      expect(
        await settled(),
        isA<LingerQueue>().having((q) => q.items.length, 'items', 3),
      );
    });

    test(
      'does not drop the card in front of the reader when it is seen',
      () async {
        await seed(5);
        final queue = await settled();
        expect(queue.items, hasLength(5));

        // Seeing the current card must not shorten the queue under them.
        await articles.mark(
          queue.items.first.article.id,
          mode: ReadMode.linger,
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(container.read(lingerQueueProvider).items, hasLength(5));
      },
    );

    test('rebuilding drops what has been seen', () async {
      await seed(5);
      final queue = await settled();
      await articles.mark(queue.items.first.article.id, mode: ReadMode.linger);

      await container.read(lingerQueueProvider.notifier).rebuild();

      expect(container.read(lingerQueueProvider).items, hasLength(4));
    });
  });
}
