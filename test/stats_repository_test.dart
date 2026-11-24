import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:headshorts/data/db/article_repository.dart';
import 'package:headshorts/data/db/database.dart';
import 'package:headshorts/data/db/source_repository.dart';
import 'package:headshorts/data/db/stats_repository.dart';
import 'package:headshorts/data/db/tables.dart';
import 'package:headshorts/data/sources/source_adapter.dart';

void main() {
  late HsDatabase db;
  late StatsRepository stats;

  setUp(() {
    db = HsDatabase.forTesting(NativeDatabase.memory());
    stats = StatsRepository(db);
  });
  tearDown(() => db.close());

  Future<int> source(String n) =>
      SourceRepository(db)
          .add(title: n, feedUrl: 'https://example.com/$n', category: 'World');

  Future<void> articles(int src, String prefix, int n) =>
      ArticleRepository(db).upsert(src, [
        for (var i = 0; i < n; i++)
          ParsedArticle(
            guid: '$prefix$i',
            title: 'Headline $prefix$i',
            link: 'https://example.com/$prefix$i',
            publishedAt: DateTime.now(),
          ),
      ]);

  test('summarise counts per source with SQL aggregates', () async {
    final a = await source('a');
    final b = await source('b');
    await articles(a, 'a', 4);
    await articles(b, 'b', 2);
    // a: 1 opened, 1 seen-not-opened; b: nothing.
    await (db.update(db.articles)..where((r) => r.guid.equals('a0'))).write(
      const ArticlesCompanion(readFull: Value(true), seenInLinger: Value(true)),
    );
    await (db.update(db.articles)..where((r) => r.guid.equals('a1'))).write(
      const ArticlesCompanion(seenInLinger: Value(true)),
    );

    final s = await stats.summarise();
    expect(s.arrived, 6);
    expect(s.readInFull, 1);
    expect(s.seenInLinger, 1);
    expect(s.passedOver, 4);
    expect(s.perSource.first.source.title, 'a');
    expect(s.perSource.first.opened, 1);
    expect(s.perSource.first.arrived, 4);
    expect(s.perSource.last.fraction, 0);
    expect(s.neverOpened.map((e) => e.source.title), ['b']);
  });

  test('empty cache is the empty summary', () async {
    expect((await stats.summarise()).arrived, 0);
  });

  test(
    'minutes group by local day and the week watch follows inserts',
    () async {
      final a = await source('a');
      await articles(a, 'a', 1);
      final id = (await db.select(db.articles).getSingle()).id;
      final now = DateTime.now();
      Future<void> read(DateTime at, int ms) => db
          .into(db.readEvents)
          .insert(
            ReadEventsCompanion.insert(
              articleId: id,
              mode: ReadMode.full,
              at: Value(at),
              dwellMs: Value(ms),
            ),
          );
      await read(now, 120000);
      await read(now, 60000);
      await read(now.subtract(const Duration(days: 1)), 30000);

      final s = await stats.summarise();
      expect(s.minutesByDay, hasLength(14));
      expect(s.minutesByDay.last.minutes, closeTo(3, 1e-9));
      expect(s.minutesByDay[12].minutes, closeTo(0.5, 1e-9));

      final emitted = <WeekReading>[];
      final sub = stats.watchWeek().listen(emitted.add);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(emitted.last.minutes, hasLength(7));
      expect(emitted.last.minutes[now.weekday - 1], closeTo(3, 1e-9));
      await read(now, 60000);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(emitted.last.minutes[now.weekday - 1], closeTo(4, 1e-9));
      await sub.cancel();
    },
  );
}
