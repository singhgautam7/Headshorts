import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:headshorts/data/db/article_repository.dart';
import 'package:headshorts/data/db/database.dart';
import 'package:headshorts/data/db/source_repository.dart';
import 'package:headshorts/data/feed/feed_parser.dart';
import 'package:headshorts/data/sources/source_adapter.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

ParsedArticle _article(
  String guid, {
  DateTime? at,
  String? author,
}) => ParsedArticle(
  guid: guid,
  title: 'Headline $guid',
  link: 'https://example.com/$guid',
  publishedAt: at ?? DateTime.now(),
  author: author,
);

DateTime _daysAgo(int days) => DateTime.now().subtract(Duration(days: days));

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

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

  // -------------------------------------------------------------------------
  // upsert() freshness gate
  // -------------------------------------------------------------------------

  group('upsert() 90-day freshness gate', () {
    test('inserts a fresh article (published today)', () async {
      final id = await sources.add(
        title: 'Reuters',
        feedUrl: 'https://example.com/reuters',
        category: 'World',
      );

      final count = await articles.upsert(id, [_article('fresh')]);

      expect(count, 1);
      final stored = await db.select(db.articles).get();
      expect(stored, hasLength(1));
    });

    test('silently drops an article published 91 days ago', () async {
      final id = await sources.add(
        title: 'Reuters',
        feedUrl: 'https://example.com/reuters',
        category: 'World',
      );

      final count = await articles.upsert(
        id,
        [_article('stale', at: _daysAgo(91))],
      );

      expect(count, 0);
      expect(await db.select(db.articles).get(), isEmpty);
    });

    test('keeps an article published 89 days ago (well within the window)',
        () async {
      final id = await sources.add(
        title: 'Reuters',
        feedUrl: 'https://example.com/reuters',
        category: 'World',
      );

      final count = await articles.upsert(
        id,
        [_article('near-boundary', at: _daysAgo(89))],
      );

      expect(count, 1);
    });

    test('filters stale items but still inserts fresh ones in the same batch',
        () async {
      final id = await sources.add(
        title: 'Reuters',
        feedUrl: 'https://example.com/reuters',
        category: 'World',
      );

      final count = await articles.upsert(id, [
        _article('old', at: _daysAgo(95)),
        _article('new1'),
        _article('new2'),
      ]);

      expect(count, 2);
      final guids = (await db.select(db.articles).get()).map((a) => a.guid);
      expect(guids, containsAll(['new1', 'new2']));
      expect(guids, isNot(contains('old')));
    });

    test('updates author on existing row when feed later provides it', () async {
      final id = await sources.add(
        title: 'Reuters',
        feedUrl: 'https://example.com/reuters',
        category: 'World',
      );

      // First upsert: no author.
      await articles.upsert(id, [_article('a', author: null)]);

      // Second upsert: author is now known.
      await articles.upsert(id, [_article('a', author: 'Jane Smith')]);

      final stored = (await db.select(db.articles).get()).single;
      expect(stored.author, 'Jane Smith');
    });

    test('does not erase a prior author when the update has none', () async {
      final id = await sources.add(
        title: 'Reuters',
        feedUrl: 'https://example.com/reuters',
        category: 'World',
      );

      await articles.upsert(id, [_article('a', author: 'Jane Smith')]);
      await articles.upsert(id, [_article('a', author: null)]);

      final stored = (await db.select(db.articles).get()).single;
      expect(stored.author, 'Jane Smith');
    });
  });

  // -------------------------------------------------------------------------
  // watchBriefing freshness filter
  // -------------------------------------------------------------------------

  group('watchBriefing() 90-day freshness filter', () {
    test('fresh articles appear in the briefing', () async {
      final id = await sources.add(
        title: 'BBC',
        feedUrl: 'https://example.com/bbc',
        category: 'World',
      );
      await articles.upsert(id, [_article('recent')]);

      final briefing = await articles.watchBriefing().first;

      expect(briefing.map((h) => h.article.guid), contains('recent'));
    });

    test('articles inserted directly at 91 days are excluded from briefing',
        () async {
      final id = await sources.add(
        title: 'BBC',
        feedUrl: 'https://example.com/bbc',
        category: 'World',
      );

      // Insert directly into the DB, bypassing the upsert freshness gate, to
      // simulate a row that aged past the window after being stored.
      await db.into(db.articles).insert(
        ArticlesCompanion.insert(
          sourceId: id,
          guid: 'old-article',
          title: 'Old Article',
          link: 'https://example.com/old',
          publishedAt: _daysAgo(91),
        ),
      );
      await articles.upsert(id, [_article('new-article')]);

      final briefing = await articles.watchBriefing().first;
      final guids = briefing.map((h) => h.article.guid);

      expect(guids, contains('new-article'));
      expect(guids, isNot(contains('old-article')));
    });
  });

  // -------------------------------------------------------------------------
  // buildLingerQueue freshness filter
  // -------------------------------------------------------------------------

  group('buildLingerQueue() 90-day freshness filter', () {
    test('fresh articles appear in the Linger queue', () async {
      final id = await sources.add(
        title: 'Ars Technica',
        feedUrl: 'https://example.com/ars',
        category: 'Technology',
      );
      await articles.upsert(id, [_article('new')]);

      final queue = await articles.buildLingerQueue();

      expect(queue.map((h) => h.article.guid), contains('new'));
    });

    test('articles aged past the window are excluded from the Linger queue',
        () async {
      final id = await sources.add(
        title: 'Ars Technica',
        feedUrl: 'https://example.com/ars',
        category: 'Technology',
      );

      // Insert a stale article directly, bypassing the upsert gate.
      await db.into(db.articles).insert(
        ArticlesCompanion.insert(
          sourceId: id,
          guid: 'stale',
          title: 'Old Story',
          link: 'https://example.com/stale',
          publishedAt: _daysAgo(100),
        ),
      );
      await articles.upsert(id, [_article('fresh')]);

      final queue = await articles.buildLingerQueue();
      final guids = queue.map((h) => h.article.guid);

      expect(guids, contains('fresh'));
      expect(guids, isNot(contains('stale')));
    });
  });

  // -------------------------------------------------------------------------
  // pruneToRetention()
  // -------------------------------------------------------------------------

  group('pruneToRetention()', () {
    test('deletes articles older than maxAge and keeps fresh ones', () async {
      final id = await sources.add(
        title: 'Reuters',
        feedUrl: 'https://example.com/reuters',
        category: 'World',
      );

      // Insert both articles directly to bypass the upsert freshness gate.
      await db.into(db.articles).insert(
        ArticlesCompanion.insert(
          sourceId: id,
          guid: 'old',
          title: 'Old',
          link: 'https://example.com/old',
          publishedAt: _daysAgo(95),
        ),
      );
      await db.into(db.articles).insert(
        ArticlesCompanion.insert(
          sourceId: id,
          guid: 'fresh',
          title: 'Fresh',
          link: 'https://example.com/fresh',
          publishedAt: DateTime.now(),
        ),
      );

      expect(await db.select(db.articles).get(), hasLength(2));

      await db.pruneToRetention();

      final remaining = (await db.select(db.articles).get()).map((a) => a.guid);
      expect(remaining, isNot(contains('old')));
      expect(remaining, contains('fresh'));
    });

    test('prunes excess articles per source beyond the keep limit', () async {
      final id = await sources.add(
        title: 'Prolific Source',
        feedUrl: 'https://example.com/prolific',
        category: 'World',
      );

      // Insert 5 fresh articles directly.
      for (var i = 0; i < 5; i++) {
        await db.into(db.articles).insert(
          ArticlesCompanion.insert(
            sourceId: id,
            guid: 'article-$i',
            title: 'Article $i',
            link: 'https://example.com/article-$i',
            publishedAt: DateTime.now().subtract(Duration(hours: i)),
          ),
        );
      }

      await db.pruneToRetention(keep: 3);

      expect(await db.select(db.articles).get(), hasLength(3));
    });
  });

  // -------------------------------------------------------------------------
  // FeedParser author cleaning
  // -------------------------------------------------------------------------

  group('FeedParser author parsing', () {
    ParsedArticle _parse(String feedXml) => FeedParser.parse(feedXml).first;

    test('extracts a clean author from RSS2 dc:creator field', () {
      final xml = '''
<rss version="2.0" xmlns:dc="http://purl.org/dc/elements/1.1/">
  <channel><title>T</title>
    <item>
      <guid>g1</guid>
      <link>https://example.com/a</link>
      <title>Headline</title>
      <dc:creator>John Doe</dc:creator>
    </item>
  </channel>
</rss>''';
      expect(_parse(xml).author, 'John Doe');
    });

    test('prefers dc:creator over <author> in RSS2', () {
      final xml = '''
<rss version="2.0" xmlns:dc="http://purl.org/dc/elements/1.1/">
  <channel><title>T</title>
    <item>
      <guid>g1</guid>
      <link>https://example.com/a</link>
      <title>Headline</title>
      <dc:creator>Jane Smith</dc:creator>
      <author>noreply@example.com (Fallback)</author>
    </item>
  </channel>
</rss>''';
      expect(_parse(xml).author, 'Jane Smith');
    });

    test('strips "email (Name)" format and returns just the name', () {
      final xml = '''
<rss version="2.0">
  <channel><title>T</title>
    <item>
      <guid>g1</guid>
      <link>https://example.com/a</link>
      <title>Headline</title>
      <author>user@example.com (John Doe)</author>
    </item>
  </channel>
</rss>''';
      expect(_parse(xml).author, 'John Doe');
    });

    test('strips leading "By " prefix (case-insensitive)', () {
      final xml = '''
<rss version="2.0" xmlns:dc="http://purl.org/dc/elements/1.1/">
  <channel><title>T</title>
    <item>
      <guid>g1</guid>
      <link>https://example.com/a</link>
      <title>Headline</title>
      <dc:creator>By Jane Smith</dc:creator>
    </item>
  </channel>
</rss>''';
      expect(_parse(xml).author, 'Jane Smith');
    });

    test('returns null when author field is absent', () {
      final xml = '''
<rss version="2.0">
  <channel><title>T</title>
    <item>
      <guid>g1</guid>
      <link>https://example.com/a</link>
      <title>Headline</title>
    </item>
  </channel>
</rss>''';
      expect(_parse(xml).author, isNull);
    });

    test('extracts author from Atom feed author name', () {
      final xml = '''
<feed xmlns="http://www.w3.org/2005/Atom">
  <title>T</title>
  <entry>
    <id>urn:uuid:1</id>
    <title>Headline</title>
    <link href="https://example.com/a"/>
    <updated>2026-09-08T06:00:00Z</updated>
    <author><name>Alice Wonderland</name></author>
  </entry>
</feed>''';
      expect(_parse(xml).author, 'Alice Wonderland');
    });

    test('falls back to Atom author email when name is absent', () {
      final xml = '''
<feed xmlns="http://www.w3.org/2005/Atom">
  <title>T</title>
  <entry>
    <id>urn:uuid:1</id>
    <title>Headline</title>
    <link href="https://example.com/a"/>
    <updated>2026-09-08T06:00:00Z</updated>
    <author><email>alice@example.com</email></author>
  </entry>
</feed>''';
      expect(_parse(xml).author, 'alice@example.com');
    });
  });
}
