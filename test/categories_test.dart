import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:headshorts/data/db/article_repository.dart';
import 'package:headshorts/data/db/database.dart';
import 'package:headshorts/data/db/source_repository.dart';
import 'package:headshorts/data/db/tables.dart';
import 'package:headshorts/data/sources/source_adapter.dart';

ParsedArticle _article(String guid, String link, {String? title}) =>
    ParsedArticle(
      guid: guid,
      title: title ?? 'A headline about something that happened in $guid',
      link: link,
      publishedAt: DateTime(
        2026,
        9,
        8,
        12,
      ).subtract(Duration(minutes: guid.hashCode.abs() % 500)),
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

  Future<int> add(String title, String category, {bool enabled = true}) async {
    final id = await sources.add(
      title: title,
      feedUrl: 'https://example.com/${title.toLowerCase()}',
      category: category,
    );
    if (!enabled) await sources.setEnabled(id, enabled: false);
    return id;
  }

  group('categories are derived, never declared', () {
    test('one tab per category that has an enabled source', () async {
      await add('Hindu', 'India');
      await add('BBC', 'World');
      await add('Verge', 'Technology');

      expect(
        await sources.watchCategories().first,
        unorderedEquals(['India', 'World', 'Technology']),
      );
    });

    test('a category with no enabled source has no tab', () async {
      await add('Hindu', 'India');
      final verge = await add('Verge', 'Technology');
      await sources.setEnabled(verge, enabled: false);

      expect(await sources.watchCategories().first, ['India']);
    });

    test('recategorising a source moves it between tabs', () async {
      final id = await add('Hindu', 'India');
      await sources.setCategory(id, 'Asia');

      expect(await sources.watchCategories().first, ['Asia']);
    });

    test('removing the last source in a category removes the tab', () async {
      final id = await add('Verge', 'Technology');
      await add('BBC', 'World');
      await sources.remove(id);

      expect(await sources.watchCategories().first, ['World']);
    });
  });

  group('renameCategory', () {
    test('moves every source in it', () async {
      await add('Hindu', 'India');
      await add('Express', 'India');
      await add('BBC', 'World');

      expect(await sources.renameCategory('India', 'South Asia'), 2);
      expect(
        await sources.watchCategories().first,
        unorderedEquals(['South Asia', 'World']),
      );
    });

    test('renaming onto an existing name merges the two', () async {
      await add('Hindu', 'India');
      await add('BBC', 'World');
      await sources.renameCategory('India', 'World');

      expect(await sources.watchCategories().first, ['World']);
      expect((await sources.all()).every((s) => s.category == 'World'), isTrue);
    });

    test('refuses an empty name rather than losing the category', () async {
      await add('Hindu', 'India');
      expect(await sources.renameCategory('India', '   '), 0);
      expect(await sources.watchCategories().first, ['India']);
    });
  });

  group('Latest', () {
    test('merges every enabled source, newest first', () async {
      final hindu = await add('Hindu', 'India');
      final bbc = await add('BBC', 'World');
      await articles.upsert(hindu, [
        _article('a', 'https://thehindu.com/a', title: 'India story one here'),
      ]);
      await articles.upsert(bbc, [
        _article('b', 'https://bbc.co.uk/b', title: 'World story two here'),
      ]);

      final latest = await articles.watchBriefing().first;
      expect(latest, hasLength(2));
      expect(
        latest.first.article.publishedAt.isAfter(
          latest.last.article.publishedAt,
        ),
        isTrue,
      );
    });

    test('scoping by category shows only that category', () async {
      final hindu = await add('Hindu', 'India');
      final bbc = await add('BBC', 'World');
      await articles.upsert(hindu, [
        _article('a', 'https://thehindu.com/a', title: 'India story one here'),
      ]);
      await articles.upsert(bbc, [
        _article('b', 'https://bbc.co.uk/b', title: 'World story two here'),
      ]);

      final india = await articles.watchBriefing(category: 'India').first;
      expect(india, hasLength(1));
      expect(india.single.source.title, 'Hindu');
    });

    test(
      'a muted source drops out of Latest but stays in its category',
      () async {
        final firehose = await add('Firehose', 'World');
        await articles.upsert(firehose, [
          _article('a', 'https://example.com/a', title: 'A World story here'),
        ]);
        await sources.setMutedInLatest(firehose, muted: true);

        expect(await articles.watchBriefing().first, isEmpty);
        expect(
          await articles.watchBriefing(category: 'World').first,
          hasLength(1),
        );
      },
    );

    test('collapses a story two feeds both carry', () async {
      final one = await add('One', 'World');
      final two = await add('Two', 'World');
      const story = 'Rail operators trial a single tap-in fare cap';
      await articles.upsert(one, [
        _article('a', 'https://bbc.co.uk/news/x', title: story),
      ]);
      await articles.upsert(two, [
        _article(
          'b',
          'https://www.bbc.co.uk/news/x?utm_source=rss',
          title: story,
        ),
      ]);

      expect(await articles.watchBriefing().first, hasLength(1));
    });
  });

  group('read state', () {
    test('opening the full article marks every copy of the story', () async {
      final one = await add('One', 'World');
      final two = await add('Two', 'India');
      await articles.upsert(one, [
        _article('a', 'https://bbc.co.uk/news/x', title: 'A shared story here'),
      ]);
      await articles.upsert(two, [
        _article(
          'b',
          'https://www.bbc.co.uk/news/x/',
          title: 'A shared story here',
        ),
      ]);

      final all = await db.select(db.articles).get();
      await articles.mark(all.first.id, mode: ReadMode.full);

      final after = await db.select(db.articles).get();
      expect(after.every((a) => a.readFull), isTrue);
    });

    test('opening the full article removes the item from Linger', () async {
      final id = await add('One', 'World');
      await articles.upsert(id, [
        _article('a', 'https://example.com/a', title: 'A story worth reading'),
      ]);

      expect(await articles.buildLingerQueue(), hasLength(1));
      final article = (await db.select(db.articles).get()).single;
      await articles.mark(article.id, mode: ReadMode.full);
      expect(await articles.buildLingerQueue(), isEmpty);
    });

    test('seeing a card in Linger does not mark it read', () async {
      final id = await add('One', 'World');
      await articles.upsert(id, [
        _article('a', 'https://example.com/a', title: 'A story worth reading'),
      ]);
      final article = (await db.select(db.articles).get()).single;

      await articles.mark(article.id, mode: ReadMode.linger);

      final after = (await db.select(db.articles).get()).single;
      expect(after.seenInLinger, isTrue);
      expect(after.readFull, isFalse, reason: 'seen is not read');
    });

    test('an item seen in Linger leaves Linger but stays in Today', () async {
      final id = await add('One', 'World');
      await articles.upsert(id, [
        _article('a', 'https://example.com/a', title: 'A story worth reading'),
      ]);
      final article = (await db.select(db.articles).get()).single;

      await articles.mark(article.id, mode: ReadMode.linger);

      expect(await articles.buildLingerQueue(), isEmpty);
      expect(
        await articles.watchBriefing().first,
        hasLength(1),
        reason: 'Today is not affected by seenInLinger',
      );
    });
  });
}
