import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:headshorts/data/db/article_repository.dart';
import 'package:headshorts/data/db/database.dart';
import 'package:headshorts/data/db/source_repository.dart';
import 'package:headshorts/data/db/tables.dart';
import 'package:headshorts/data/sources/source_adapter.dart';
import 'package:headshorts/features/linger/linger_controller.dart';
import 'package:headshorts/features/today/today_controller.dart';

ParsedArticle _article(String guid, String title) => ParsedArticle(
  guid: guid,
  title: title,
  link: 'https://example.com/$guid',
  publishedAt: DateTime(
    2026,
    9,
    8,
    12,
  ).subtract(Duration(minutes: guid.length)),
);

void main() {
  late HsDatabase db;
  late SourceRepository sources;
  late ArticleRepository articles;

  late int hindu;
  late int verge;
  late int guardian;

  setUp(() async {
    db = HsDatabase.forTesting(NativeDatabase.memory());
    sources = SourceRepository(db);
    articles = ArticleRepository(db);

    hindu = await sources.add(
      title: 'The Hindu',
      feedUrl: 'https://hindu.example.com/rss',
      category: 'India',
    );
    verge = await sources.add(
      title: 'The Verge',
      feedUrl: 'https://verge.example.com/rss',
      category: 'Technology',
    );
    guardian = await sources.add(
      title: 'The Guardian',
      feedUrl: 'https://guardian.example.com/rss',
      category: 'Technology',
    );

    await articles.upsert(hindu, [
      _article('h1', 'Monsoon rains close two mountain passes in Himachal'),
    ]);
    await articles.upsert(verge, [
      _article('v1', 'Chip maker delays its next factory by a year'),
    ]);
    await articles.upsert(guardian, [
      _article('g1', 'Rail operators trial a single tap-in fare cap'),
    ]);
  });

  tearDown(() => db.close());

  Future<List<String>> queue({String? category, Set<int>? sourceIds}) async {
    final items = await articles.buildLingerQueue(
      category: category,
      sourceIds: sourceIds,
    );
    return items.map((h) => h.source.title).toList();
  }

  group('the Linger filter', () {
    test('an unfiltered queue is every enabled source', () async {
      expect(
        await queue(),
        containsAll(['The Hindu', 'The Verge', 'The Guardian']),
      );
    });

    test('a category narrows the queue to that category', () async {
      expect(await queue(category: 'Technology'), hasLength(2));
      expect(await queue(category: 'India'), ['The Hindu']);
    });

    test('source tags narrow it further, within the category', () async {
      expect(await queue(category: 'Technology', sourceIds: {verge}), [
        'The Verge',
      ]);
    });

    test('a source outside the category is not brought back in', () async {
      // A stale pick from another category must not widen the scope.
      expect(await queue(category: 'India', sourceIds: {verge}), isEmpty);
    });

    test('an empty selection means nothing, not everything', () async {
      // Saying so beats quietly ignoring the reader's own filter.
      expect(await queue(sourceIds: const {}), isEmpty);
    });

    test(
      'a paused source drops out of the queue whatever the filter',
      () async {
        await sources.setEnabled(verge, enabled: false);

        expect(await queue(category: 'Technology'), ['The Guardian']);
        expect(
          await queue(category: 'Technology', sourceIds: {verge}),
          isEmpty,
        );
      },
    );

    test('the filter never touches seen and read', () async {
      // Filtering is a lens. It hides items; it does not consume them.
      final before = await db.select(db.articles).get();
      await queue(category: 'Technology', sourceIds: {guardian});
      final after = await db.select(db.articles).get();

      expect(
        after.map((a) => a.seenInLinger),
        before.map((a) => a.seenInLinger),
      );
      expect(after.map((a) => a.readFull), before.map((a) => a.readFull));
    });

    test(
      'items already seen in Linger stay out of the rebuilt queue',
      () async {
        final item = (await articles.buildLingerQueue(category: 'India'))
            .single;
        await articles.mark(item.article.id, mode: ReadMode.linger);

        expect(await queue(category: 'India'), isEmpty);
      },
    );
  });

  group('LingerFilter', () {
    test('the default is Latest with every source', () {
      const filter = LingerFilter();
      expect(filter.category, latestScope);
      expect(filter.sourceIds, isNull);
      expect(filter.isDefault, isTrue);
    });

    test('a filter with any narrowing is not the default', () {
      expect(const LingerFilter(category: 'India').isDefault, isFalse);
      expect(const LingerFilter(sourceIds: {1}).isDefault, isFalse);
    });

    test('two filters with the same scope are equal', () {
      // The queue controller compares these to decide whether a load it
      // started is still the one the reader is waiting for.
      expect(
        const LingerFilter(category: 'India', sourceIds: {1, 2}),
        const LingerFilter(category: 'India', sourceIds: {2, 1}),
      );
      expect(
        const LingerFilter(category: 'India'),
        isNot(const LingerFilter(category: 'India', sourceIds: {1})),
      );
    });
  });
}
