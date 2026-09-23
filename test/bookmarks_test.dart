import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:headshorts/data/db/article_repository.dart';
import 'package:headshorts/data/db/bookmark_repository.dart';
import 'package:headshorts/data/db/database.dart';
import 'package:headshorts/data/db/source_repository.dart';
import 'package:headshorts/data/sources/source_adapter.dart';

/// Save for later.
///
/// The promise a bookmark makes is that it outlives the cache it came from —
/// the prune, the 90-day window, and unsubscribing the source. That promise
/// is the whole of this file.
void main() {
  late HsDatabase db;
  late SourceRepository sources;
  late ArticleRepository articles;
  late BookmarkRepository bookmarks;
  late int sourceId;

  Future<Headline> fetch(String guid) async {
    final all = await articles.watchBriefing().first;
    return all.firstWhere((h) => h.article.guid == guid);
  }

  Future<void> add(String guid, String title, {Duration ago = Duration.zero}) =>
      articles.upsert(sourceId, [
        ParsedArticle(
          guid: guid,
          title: title,
          link: 'https://example.com/$guid',
          publishedAt: DateTime.now().subtract(ago),
          contentSnippet: 'A snippet for $guid.',
          fullContentHtml: '<p>The extracted body of $guid.</p>',
        ),
      ]);

  setUp(() async {
    db = HsDatabase.forTesting(NativeDatabase.memory());
    sources = SourceRepository(db);
    articles = ArticleRepository(db);
    bookmarks = BookmarkRepository(db);

    sourceId = await sources.add(
      title: 'BBC News',
      feedUrl: 'https://bbc.example/rss',
      category: 'World',
    );
  });

  tearDown(() => db.close());

  test(
    'a saved article keeps everything needed to render it offline',
    () async {
      await add('a', 'Rail operators trial a single tap-in fare cap');
      await bookmarks.save(await fetch('a'));

      final row = (await bookmarks.watchAll().first).single;
      expect(row.title, 'Rail operators trial a single tap-in fare cap');
      expect(row.sourceTitle, 'BBC News');
      expect(row.language, 'en');
      expect(row.contentHtml, contains('extracted body'));
      expect(row.accentDark, isNonZero);
      expect(row.link, 'https://example.com/a');
    },
  );

  test('saving twice keeps one bookmark', () async {
    await add('a', 'A headline that gets saved more than once');
    await bookmarks.save(await fetch('a'));
    await bookmarks.save(await fetch('a'));
    expect(await bookmarks.watchAll().first, hasLength(1));
  });

  test('a bookmark survives a prune that clears the cache', () async {
    await add('a', 'A headline that is saved before the prune');
    await add('b', 'A different headline that is not saved at all');
    await bookmarks.save(await fetch('a'));

    // Keep nothing: the harshest prune there is.
    await db.pruneToRetention(keep: 0);

    expect(await bookmarks.watchAll().first, hasLength(1));
    // The row it was taken from is spared too, so the Reader keeps working.
    final left = await db.select(db.articles).get();
    expect(left.map((a) => a.guid), ['a']);
  });

  test('a bookmark survives the 90-day freshness window', () async {
    // Inserted straight into the table: `upsert` refuses anything older than
    // the window at the door, which is the pipeline doing its job. What is
    // under test is the prune that sweeps up what is already there.
    await db
        .into(db.articles)
        .insert(
          ArticlesCompanion.insert(
            sourceId: sourceId,
            guid: 'old',
            title: 'A headline older than the freshness window',
            link: 'https://example.com/old',
            publishedAt: DateTime.now().subtract(const Duration(days: 200)),
          ),
        );
    await bookmarks.save(
      Headline(
        (await db.select(db.articles).get()).single,
        (await sources.all()).single,
      ),
    );

    await db.pruneToRetention();

    expect(await bookmarks.watchAll().first, hasLength(1));
  });

  test('a bookmark survives clearing the cached articles', () async {
    await add('a', 'A saved headline that outlives a cache clear');
    await add('b', 'An unsaved headline that does not');
    await bookmarks.save(await fetch('a'));

    await db.clearCache();

    expect(await bookmarks.watchAll().first, hasLength(1));
    expect(await db.select(db.articles).get(), hasLength(1));
  });

  test('a bookmark survives unsubscribing its source', () async {
    await add('a', 'A saved headline whose source is about to go');
    await bookmarks.save(await fetch('a'));

    await sources.remove(sourceId);

    // The article row goes with the source — that cascade is deliberate —
    // and the bookmark does not, because it is a copy rather than a pointer.
    expect(await db.select(db.articles).get(), isEmpty);
    final row = (await bookmarks.watchAll().first).single;
    expect(row.title, 'A saved headline whose source is about to go');
    expect(row.contentHtml, isNotNull);
  });

  test('removing and undoing puts it back exactly as it was', () async {
    await add('a', 'A headline removed by a swipe and then restored');
    await bookmarks.save(await fetch('a'));
    final row = (await bookmarks.watchAll().first).single;

    await bookmarks.removeById(row.id);
    expect(await bookmarks.watchAll().first, isEmpty);

    await bookmarks.restore(row);
    expect((await bookmarks.watchAll().first).single.title, row.title);
  });

  test(
    'saved state is keyed on the link, so a second copy reads as saved',
    () async {
      await add('a', 'One story that two feeds both carry');
      await bookmarks.save(await fetch('a'));
      expect(
        await bookmarks.watchIsSaved('https://example.com/a').first,
        isTrue,
      );
      expect(
        await bookmarks.watchIsSaved('https://example.com/z').first,
        isFalse,
      );
    },
  );

  test('the count is a value, and it goes down again', () async {
    expect(await bookmarks.watchCount().first, 0);
    await add('a', 'The first of two headlines to be saved');
    await add('b', 'The second of two headlines to be saved');
    await bookmarks.save(await fetch('a'));
    await bookmarks.save(await fetch('b'));
    expect(await bookmarks.watchCount().first, 2);

    await bookmarks.removeByLink('https://example.com/a');
    expect(await bookmarks.watchCount().first, 1);
  });
}
