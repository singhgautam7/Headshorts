import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:headshorts/core/util/relative_time.dart';
import 'package:headshorts/core/util/stream_throttle.dart';
import 'package:headshorts/data/db/article_repository.dart';
import 'package:headshorts/data/db/bookmark_repository.dart';
import 'package:headshorts/data/db/database.dart';
import 'package:headshorts/data/db/source_repository.dart';
import 'package:headshorts/data/db/tables.dart';
import 'package:headshorts/data/feed/feed_parser.dart';
import 'package:headshorts/data/feed/refresh_service.dart';
import 'package:headshorts/data/sources/rss_source_adapter.dart';
import 'package:headshorts/data/sources/source_adapter.dart';

/// Distinct words so de-duplication never merges the fixtures.
ParsedArticle _article(
  String guid, {
  String? title,
  DateTime? at,
  String? snippet,
}) => ParsedArticle(
  guid: guid,
  title: title ?? 'Unique $guid story about ${guid.split('').reversed.join()}',
  link: 'https://example.com/$guid',
  publishedAt: at ?? DateTime.now().subtract(const Duration(hours: 1)),
  contentSnippet: snippet,
);

/// Answers every request from [respond] and tells the test when Dio cancels.
class _FakeHttp implements HttpClientAdapter {
  new(this.respond);

  final ResponseBody Function(RequestOptions options) respond;
  bool cancelled = false;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    unawaited(cancelFuture?.then((_) => cancelled = true));
    return Future.value(respond(options));
  }

  @override
  void close({bool force = false}) {}
}

Dio _dio(_FakeHttp http) => Dio()..httpClientAdapter = http;

SourceRef _ref() => const SourceRef(
  id: 1,
  feedUrl: 'https://example.com/rss',
  type: SourceType.rss,
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

  group('throttleLatest', () {
    test('first event at once, a burst collapses to its newest', () {
      fakeAsync((async) {
        final source = StreamController<int>();
        final seen = <int>[];
        throttleLatest(
          source.stream,
          const Duration(milliseconds: 400),
        ).listen(seen.add);

        source.add(1);
        async.flushMicrotasks();
        expect(seen, [1]);

        source
          ..add(2)
          ..add(3)
          ..add(4);
        async.elapse(const Duration(milliseconds: 399));
        expect(seen, [1], reason: 'inside the window nothing more is let out');

        async.elapse(const Duration(milliseconds: 2));
        expect(seen, [1, 4], reason: 'the trailing event is the latest one');

        // Quiet for a window, then the next one goes straight through.
        async.elapse(const Duration(seconds: 1));
        source.add(5);
        async.flushMicrotasks();
        expect(seen, [1, 4, 5]);
      });
    });

    test('a pending event is delivered when the source closes', () async {
      final source = StreamController<int>();
      final out = throttleLatest(
        source.stream,
        const Duration(milliseconds: 200),
      ).toList();
      source
        ..add(1)
        ..add(2);
      await source.close();
      expect(await out, [1, 2]);
    });

    test('cancelling leaves no timer behind', () {
      fakeAsync((async) {
        final source = StreamController<int>();
        final sub = throttleLatest(
          source.stream,
          const Duration(milliseconds: 400),
        ).listen((_) {});
        source
          ..add(1)
          ..add(2);
        async.flushMicrotasks();
        unawaited(sub.cancel());
        expect(async.pendingTimers, isEmpty);
      });
    });
  });

  group('a refresh does not re-emit what did not change', () {
    test('a source stamped by a refresh is not a new source list', () async {
      final id = await add('one');
      final seen = <List<SourceRow>>[];
      final sub = sources.watchAll().listen(seen.add);
      await pumpEventQueue();
      expect(seen, hasLength(1));

      await sources.recordSuccess(id, etag: 'abc');
      await pumpEventQueue();
      expect(
        seen,
        hasLength(1),
        reason: 'lastFetchedAt and etag are not drawn',
      );

      await sources.setEnabled(id, enabled: false);
      await pumpEventQueue();
      expect(seen, hasLength(2), reason: 'enabled is');
      await sub.cancel();
    });

    test('Headline equality ignores the source fetch bookkeeping', () async {
      final id = await add('one');
      await articles.upsert(id, [_article('a')]);
      final first = (await articles.watchBriefing().first).single;

      await sources.recordSuccess(id, etag: 'x');
      final second = (await articles.watchBriefing().first).single;

      expect(second, first);
      expect(second.hashCode, first.hashCode);

      await articles.mark(first.article.id, mode: ReadMode.full);
      final read = (await articles.watchBriefing().first).single;
      expect(read, isNot(first), reason: 'a read flag is drawn');
    });

    test('an upsert of unchanged items writes nothing', () async {
      final id = await add('one');
      final items = [_article('a'), _article('b')];
      expect(await articles.upsert(id, items), 2);

      final events = <int>[];
      final sub = db
          .select(db.articles)
          .watch()
          .listen((rows) => events.add(rows.length));
      await pumpEventQueue();
      final before = events.length;

      expect(await articles.upsert(id, items), 0);
      await pumpEventQueue();
      expect(events.length, before, reason: 'no UPDATE, so no re-query');

      // A corrected headline does write.
      await articles.upsert(id, [_article('a', title: 'A corrected headline')]);
      await pumpEventQueue();
      expect(events.length, greaterThan(before));
      final row = await (db.select(
        db.articles,
      )..where((a) => a.guid.equals('a'))).getSingle();
      expect(row.title, 'A corrected headline');
      await sub.cancel();
    });

    test('a feed that stops sending a body does not erase it', () async {
      final id = await add('one');
      await articles.upsert(id, [
        ParsedArticle(
          guid: 'a',
          title: 'Keeps its body when the feed stops sending one',
          link: 'https://example.com/a',
          publishedAt: DateTime.now().subtract(const Duration(hours: 1)),
          fullContentHtml: '<p>The body</p>',
        ),
      ]);
      await articles.upsert(id, [
        ParsedArticle(
          guid: 'a',
          title: 'Keeps its body when the feed stops sending one, edited',
          link: 'https://example.com/a',
          publishedAt: DateTime.now().subtract(const Duration(hours: 1)),
        ),
      ]);
      final row = await db.select(db.articles).getSingle();
      expect(row.fullContentHtml, '<p>The body</p>');
    });
  });

  group('lists do not carry bodies', () {
    test(
      'the briefing has no body or snippet, the Linger queue its head',
      () async {
        final id = await add('one');
        await articles.upsert(id, [
          ParsedArticle(
            guid: 'a',
            title: 'A story whose body must stay in the database',
            link: 'https://example.com/a',
            publishedAt: DateTime.now().subtract(const Duration(hours: 1)),
            contentSnippet: 'snippet',
            fullContentHtml: '<p>${'x' * 5000}</p>',
          ),
        ]);

        final today = (await articles.watchBriefing().first).single.article;
        expect(today.fullContentHtml, isNull);
        expect(today.contentSnippet, isNull);

        final linger = (await articles.buildLingerQueue()).single.article;
        expect(linger.contentSnippet, 'snippet');
        expect(linger.fullContentHtml!.length, 2000);

        // The Reader still gets the whole thing.
        final stored = await db.select(db.articles).getSingle();
        expect(stored.fullContentHtml!.length, greaterThan(5000));
      },
    );

    test('the bookmark list has no body, and Undo brings it back', () async {
      final id = await add('one');
      await articles.upsert(id, [
        ParsedArticle(
          guid: 'a',
          title: 'A saved article with a long body',
          link: 'https://example.com/a',
          publishedAt: DateTime.now().subtract(const Duration(hours: 1)),
        ),
      ]);
      final headline = (await articles.watchBriefing().first).single;
      final bookmarks = BookmarkRepository(db);
      await bookmarks.save(headline, contentHtml: '<p>Saved body</p>');

      final listed = (await bookmarks.watchAll().first).single;
      expect(listed.contentHtml, isNull);

      await bookmarks.removeById(listed.id);
      expect(await db.select(db.bookmarks).get(), isEmpty);
      await bookmarks.restore(listed);
      final back = await db.select(db.bookmarks).getSingle();
      expect(back.contentHtml, '<p>Saved body</p>');
    });
  });

  group('the database file', () {
    test('has the indices the queries ride', () async {
      final names =
          (await db
                  .customSelect(
                    "SELECT name FROM sqlite_master WHERE type='index'",
                  )
                  .get())
              .map((r) => r.read<String>('name'))
              .toSet();
      expect(
        names,
        containsAll([
          'idx_read_events_article',
          'idx_read_events_at',
          'idx_articles_source_published',
        ]),
      );
    });

    test('an install with the old full-row FTS trigger is upgraded', () async {
      final dir = await Directory.systemTemp.createTemp('hs_fts');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/db.sqlite');

      var disk = HsDatabase.forTesting(NativeDatabase(file));
      await disk.customSelect('SELECT 1').get(); // opens, creates the index
      await disk.customStatement('DROP TRIGGER articles_fts_update');
      await disk.customStatement(
        'CREATE TRIGGER articles_fts_update AFTER UPDATE ON articles BEGIN '
        'INSERT INTO articles_fts(articles_fts, rowid, title, summary, '
        "content_snippet) VALUES ('delete', old.id, old.title, old.summary, "
        'old.content_snippet); END',
      );
      await disk.close();

      disk = HsDatabase.forTesting(NativeDatabase(file));
      addTearDown(disk.close);
      final sql =
          (await disk
                  .customSelect(
                    "SELECT sql FROM sqlite_master WHERE name='articles_fts_update'",
                  )
                  .getSingle())
              .read<String>('sql');
      expect(sql, contains('UPDATE OF title, summary, content_snippet'));
    });

    test('the index still follows a corrected headline', () async {
      final id = await add('one');
      await articles.upsert(id, [_article('a', title: 'Zeppelin sighted')]);
      await articles.upsert(id, [_article('a', title: 'Dirigible sighted')]);
      Future<List<int>> find(String word) =>
          db.searchArticleIds(match: ftsQuery(word)!, limit: 10);
      expect(await find('dirigible'), hasLength(1));
      expect(await find('zeppelin'), isEmpty);
    });

    test('notifyExternalWrite wakes streams after a write drift did not see', () async {
      final id = await add('one');
      await articles.upsert(id, [_article('a')]);
      final seen = <int>[];
      final sub = articles.watchBriefing().listen((l) => seen.add(l.length));
      await pumpEventQueue();
      expect(seen.last, 1);

      // What a headless engine's write looks like from here: drift is not told.
      await db.customStatement('DELETE FROM articles');
      await pumpEventQueue();
      expect(seen.last, 1, reason: 'drift cannot see a write it did not make');

      db.notifyExternalWrite();
      await pumpEventQueue();
      expect(seen.last, 0);
      await sub.cancel();
    });
  });

  group('the pipeline', () {
    test('refuses a feed over the size cap while it streams', () async {
      final http = _FakeHttp(
        (_) => ResponseBody(
          Stream.fromIterable([
            for (var i = 0; i < 10; i++) Uint8List(1024 * 1024),
          ]),
          200,
        ),
      );
      final result = await RssSourceAdapter(_dio(http)).fetch(_ref());
      expect(result, isA<FetchFailed>());
      expect((result as FetchFailed).message, 'The feed is too large to read.');
    });

    test('a declared length over the cap is refused before any body', () async {
      final http = _FakeHttp(
        (_) => ResponseBody(
          Stream.value(Uint8List(10)),
          200,
          headers: {
            Headers.contentLengthHeader: ['${RssSourceAdapter.maxBytes + 1}'],
          },
        ),
      );
      final result = await RssSourceAdapter(_dio(http)).fetch(_ref());
      expect((result as FetchFailed).message, contains('too large'));
    });

    test('the deadline cancels the request instead of abandoning it', () async {
      final http = _FakeHttp(
        (_) => ResponseBody(Completer<Uint8List>().future.asStream(), 200),
      );
      final adapter = RssSourceAdapter(
        _dio(http),
        deadline: const Duration(milliseconds: 50),
      );
      final result = await adapter.fetch(_ref());
      await pumpEventQueue();
      expect(result, isA<FetchFailed>());
      expect((result as FetchFailed).message, contains('too long'));
      expect(http.cancelled, isTrue, reason: 'the socket is told to stop');
    });

    test('429 and 5xx say what happened', () async {
      Future<String> messageFor(int status) async {
        final http = _FakeHttp(
          (_) => ResponseBody(Stream.value(Uint8List(0)), status),
        );
        final dio = _dio(http)..options.validateStatus = (_) => true;
        return ((await RssSourceAdapter(
          dio,
        ).fetch(_ref())) as FetchFailed).message;
      }

      expect(await messageFor(429), contains('limiting requests'));
      final dio = _dio(
        _FakeHttp((_) => ResponseBody(Stream.value(Uint8List(0)), 503)),
      );
      final server = (await RssSourceAdapter(dio).fetch(_ref())) as FetchFailed;
      expect(server.message, contains('server had a problem'));
    });

    test('a refresh failure is recorded, not swallowed', () async {
      await add('bad');
      final service = RefreshService(
        database: db,
        sources: sources,
        articles: articles,
        registry: SourceAdapterRegistry([_Throws()]),
      );
      await service.refreshAll().drain<void>();
      final row = (await sources.all()).single;
      expect(row.lastError, 'The feed could not be read.');
    });
  });

  group('dates', () {
    test('named zones resolve to the same instant as their offsets', () {
      final cases = {
        'GMT': DateTime.utc(2026, 6, 1, 10),
        'UTC': DateTime.utc(2026, 6, 1, 10),
        'EST': DateTime.utc(2026, 6, 1, 15),
        'EDT': DateTime.utc(2026, 6, 1, 14),
        'CST': DateTime.utc(2026, 6, 1, 16),
        'CDT': DateTime.utc(2026, 6, 1, 15),
        'MST': DateTime.utc(2026, 6, 1, 17),
        'MDT': DateTime.utc(2026, 6, 1, 16),
        'PST': DateTime.utc(2026, 6, 1, 18),
        'PDT': DateTime.utc(2026, 6, 1, 17),
        'IST': DateTime.utc(2026, 6, 1, 4, 30),
      };
      for (final entry in cases.entries) {
        final parsed = FeedParser.parseDate(
          'Mon, 01 Jun 2026 10:00:00 ${entry.key}',
        );
        expect(
          parsed!.isAtSameMomentAs(entry.value),
          isTrue,
          reason: '${entry.key} gave $parsed',
        );
      }
    });

    test('a future-dated item is clamped to now, an undated one keeps now', () {
      final future = DateTime.now().add(const Duration(days: 2)).toUtc();
      final stamp = future.toIso8601String();
      final items = FeedParser.parse('''
<rss version="2.0"><channel><title>t</title>
<item><title>Ahead of its time entirely</title><link>https://e.com/1</link>
<guid>1</guid><pubDate>$stamp</pubDate></item>
<item><title>No date at all anywhere</title><link>https://e.com/2</link>
<guid>2</guid></item>
</channel></rss>''');
      final now = DateTime.now();
      for (final item in items) {
        expect(item.publishedAt.isAfter(now), isFalse);
        expect(now.difference(item.publishedAt).inMinutes, lessThan(1));
      }
    });

    test('"updated" carries the day once it is not today', () {
      final now = DateTime(2026, 11, 25, 12);
      expect(
        updatedLabel(DateTime(2026, 11, 25, 9, 38), now: now),
        'updated 9:38',
      );
      expect(
        updatedLabel(DateTime(2026, 11, 24, 21, 5), now: now),
        'updated yesterday 21:05',
      );
      expect(
        updatedLabel(DateTime(2026, 10, 25, 9, 38), now: now),
        'updated 25 Oct',
      );
    });
  });

  group('an abandoned source', () {
    Future<int> abandoned() async {
      final id = await add('old');
      await db
          .update(db.sources)
          .write(
            SourcesCompanion(
              failingSince: Value(
                DateTime.now().subtract(const Duration(days: 20)),
              ),
            ),
          );
      return id;
    }

    RefreshService service(SourceAdapter adapter, DateTime Function() now) =>
        RefreshService(
          database: db,
          sources: sources,
          articles: articles,
          registry: SourceAdapterRegistry([adapter]),
          now: now,
        );

    test('is tried by an explicit refresh and recovers', () async {
      await abandoned();
      final adapter = _Counting();
      await service(
        adapter,
        DateTime.now,
      ).refreshAll(explicit: true).drain<void>();
      expect(adapter.calls, 1);
      final row = (await sources.all()).single;
      expect(row.failingSince, isNull);
      expect(row.isAbandoned, isFalse);
    });

    test('is tried at most once a day by a routine refresh', () async {
      await abandoned();
      final adapter = _Counting(fail: true);
      var clock = DateTime.now();
      final svc = service(adapter, () => clock);

      await svc.refreshAll().drain<void>();
      expect(adapter.calls, 1);
      await svc.refreshAll().drain<void>();
      expect(adapter.calls, 1, reason: 'not again the same day');

      clock = clock.add(const Duration(hours: 25));
      await svc.refreshAll().drain<void>();
      expect(adapter.calls, 2);
    });

    test('is given a fresh start when switched back on', () async {
      final id = await abandoned();
      await sources.setEnabled(id, enabled: true);
      expect((await sources.all()).single.failingSince, isNull);
    });
  });

  group('coming back after 30 days away', () {
    test('rows past the window go, saved and recent rows stay', () async {
      final id = await add('one');
      final old = DateTime.now().subtract(const Duration(days: 100));
      // Straight into the table: `upsert` itself refuses items past the window.
      Future<void> insertRow(String guid, DateTime at) => db
          .into(db.articles)
          .insert(
            ArticlesCompanion.insert(
              sourceId: id,
              guid: guid,
              title: 'Row $guid kept apart from the rest',
              link: 'https://example.com/$guid',
              publishedAt: at,
            ),
          );
      await insertRow('saved', old);
      await insertRow('gone', old);
      await insertRow(
        'recent',
        DateTime.now().subtract(const Duration(days: 2)),
      );
      final saved = await (db.select(
        db.articles,
      )..where((a) => a.guid.equals('saved'))).getSingle();
      await db
          .into(db.bookmarks)
          .insert(
            BookmarksCompanion.insert(
              link: saved.link,
              title: saved.title,
              sourceTitle: 'one',
              accentDark: 0,
              accentLight: 0,
              publishedAt: saved.publishedAt,
            ),
          );
      // Last fetched a month ago.
      await sources.recordSuccess(id);
      await db
          .update(db.sources)
          .write(
            SourcesCompanion(
              lastFetchedAt: Value(
                DateTime.now().subtract(const Duration(days: 30)),
              ),
            ),
          );

      final adapter = _Counting(
        articles: [_article('new', title: 'Brand new item arriving now')],
      );
      final service = RefreshService(
        database: db,
        sources: sources,
        articles: articles,
        registry: SourceAdapterRegistry([adapter]),
      );
      await service.refreshAll().drain<void>();

      final guids = (await db.select(db.articles).get())
          .map((a) => a.guid)
          .toSet();
      expect(guids, {'saved', 'recent', 'new'});
    });
  });
}

class _Throws implements SourceAdapter {
  @override
  bool canHandle(SourceType type) => true;

  @override
  Future<FetchResult> fetch(SourceRef ref) async => throw StateError('boom');
}

class _Counting implements SourceAdapter {
  new({this.fail = false, this.articles = const []});

  final bool fail;
  final List<ParsedArticle> articles;
  int calls = 0;

  @override
  bool canHandle(SourceType type) => true;

  @override
  Future<FetchResult> fetch(SourceRef ref) async {
    calls++;
    return fail
        ? const FetchResult.failed('down')
        : FetchResult.fresh(articles: articles);
  }
}
