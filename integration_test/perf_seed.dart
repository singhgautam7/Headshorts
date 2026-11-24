import 'dart:math';

import 'package:drift/drift.dart';
import 'package:headshorts/core/util/canonical_url.dart';
import 'package:headshorts/data/db/database.dart';
import 'package:headshorts/data/db/tables.dart';

/// Where `tool/feed_server.py` is, seen from an emulator.
const perfHost = 'http://10.0.2.2:8791';

const perfSources = 36;
const perfItemsPerSource = 115;

const _words = [
  'river', 'council', 'budget', 'monsoon', 'railway', 'strike', 'harvest',
  'satellite', 'court', 'festival', 'export', 'cricket', 'museum', 'bridge',
  'election', 'hospital', 'garden', 'tiger', 'summit', 'bakery', 'copper',
  'island', 'library', 'solar', 'orchestra', 'glacier', 'airport', 'lantern',
  'fishery', 'vaccine', 'archive', 'furnace', 'canyon', 'parade', 'village',
  'laser', 'forest', 'treaty', 'pension', 'comet', 'sculpture', 'harbour',
];

const _hindi = [
  'नदी', 'परिषद', 'बजट', 'मानसून', 'रेल', 'हड़ताल', 'फसल', 'उपग्रह', 'अदालत',
  'त्योहार', 'निर्यात', 'क्रिकेट', 'संग्रहालय', 'पुल', 'चुनाव', 'अस्पताल',
];

const _categories = [
  'General', 'India', 'World', 'Technology', 'Business', 'Science', 'Sport',
];

/// A heavy, realistic database: 36 sources (6 Hindi), about 4,100 articles of
/// which one in eight carries a long body with pictures, 150 bookmarks, 2,500
/// read events and 40 caught-up days. Deterministic, so runs compare.
///
/// [newest] is when the newest article was published; [spanDays] how far back
/// the rest reach. Ends with every source stamped [fetchedAt].
Future<void> seedPerf(
  HsDatabase db, {
  required DateTime newest,
  required DateTime fetchedAt,
  double spanDays = 6,
  String Function(int index)? feedUrl,
}) async {
  await db.delete(db.readEvents).go();
  await db.delete(db.bookmarks).go();
  await db.delete(db.caughtUpDays).go();
  await db.delete(db.articles).go();
  await db.delete(db.sources).go();

  final r = Random(42);
  String pick(List<String> from, int n) =>
      List.generate(n, (_) => from[r.nextInt(from.length)]).join(' ');

  await db.batch((b) {
    for (var s = 0; s < perfSources; s++) {
      b.insert(
        db.sources,
        SourcesCompanion.insert(
          id: Value(s + 1),
          title: s >= 30 ? 'हिंदी समाचार $s' : 'Perf Times $s',
          feedUrl: feedUrl?.call(s) ?? '$perfHost/feed/$s.xml',
          siteUrl: const Value(perfHost),
          category: _categories[s % _categories.length],
          language: Value(s >= 30 ? 'hi' : 'en'),
          accentDark: 0xFFE0A46B + s * 900,
          accentLight: 0xFF7A4A1E + s * 900,
          type: SourceType.rss,
          sortOrder: Value(s),
          lastFetchedAt: Value(fetchedAt),
          addedAt: Value(fetchedAt.subtract(const Duration(days: 200))),
        ),
      );
    }
  });

  final total = perfSources * perfItemsPerSource;
  await db.batch((b) {
    for (var i = 0; i < total; i++) {
      final s = i % perfSources;
      final words = s >= 30 ? _hindi : _words;
      final title = '${pick(words, 9)} ${i ~/ 7}';
      final link = '$perfHost/a/$s/$i';
      final body = i % 8 == 0
          ? [
              for (var p = 0; p < 50; p++) ...[
                '<p>${pick(words, 70)} <a href="$link#$p">${pick(words, 3)}</a></p>',
                if (p % 10 == 4)
                  '<figure><img src="$perfHost/img/$i$p.jpg"><figcaption>${pick(words, 8)}</figcaption></figure>',
              ],
            ].join()
          : null;
      b.insert(
        db.articles,
        ArticlesCompanion.insert(
          id: Value(i + 1),
          sourceId: s + 1,
          guid: link,
          title: title,
          link: link,
          canonicalUrl: Value(canonicalUrl(link)),
          titleKey: Value(titleFingerprint(title)),
          summary: Value(pick(words, 34)),
          contentSnippet: Value(pick(words, 80)),
          fullContentHtml: Value(body),
          author: const Value('A Writer'),
          imageUrl: Value(i % 5 == 4 ? null : '$perfHost/img/$i.jpg'),
          publishedAt: newest.subtract(
            Duration(seconds: (spanDays * 86400 * i / total).round()),
          ),
          fetchedAt: Value(fetchedAt),
          readFull: Value(i % 11 == 3),
          seenInLinger: Value(i % 4 == 1),
        ),
      );
    }
  });

  await db.batch((b) {
    for (var i = 0; i < 2500; i++) {
      b.insert(
        db.readEvents,
        ReadEventsCompanion.insert(
          articleId: 1 + (i * 13) % total,
          mode: i.isEven ? ReadMode.full : ReadMode.linger,
          at: Value(newest.subtract(Duration(minutes: i * 47))),
          dwellMs: Value(4000 + (i * 977) % 180000),
        ),
      );
    }
    for (var i = 0; i < 150; i++) {
      final id = 1 + i * 27;
      final s = (id - 1) % perfSources;
      b.insert(
        db.bookmarks,
        BookmarksCompanion.insert(
          articleId: Value(id),
          link: '$perfHost/a/$s/${id - 1}',
          title: 'Saved ${pick(_words, 8)}',
          summary: Value(pick(_words, 30)),
          contentHtml: Value('<p>${pick(_words, 400)}</p>'),
          imageUrl: Value('$perfHost/img/$id.jpg'),
          sourceTitle: 'Perf Times $s',
          accentDark: 0xFFE0A46B,
          accentLight: 0xFF7A4A1E,
          publishedAt: newest.subtract(Duration(hours: i)),
          savedAt: Value(newest.subtract(Duration(hours: i))),
        ),
        mode: InsertMode.insertOrIgnore,
      );
    }
    for (var i = 0; i < 40; i++) {
      final d = newest.subtract(Duration(days: i));
      b.insert(
        db.caughtUpDays,
        CaughtUpDaysCompanion.insert(day: DateTime(d.year, d.month, d.day)),
        mode: InsertMode.insertOrIgnore,
      );
    }
  });
}
