import 'package:drift/drift.dart';
import 'package:headshorts/data/db/database.dart';
import 'package:headshorts/data/db/tables.dart';
import 'package:headshorts/data/sources/source_adapter.dart';

/// An article together with the source that published it — what every list in
/// the app actually renders.
class Headline {
  const new(this.article, this.source);

  final ArticleRow article;
  final SourceRow source;

  bool get isRead => article.readInFull || article.readInReel;
}

/// Reads the cached briefing. Finite by construction: every query is bounded,
/// there is no cursor and no "load more".
class ArticleRepository {
  const new(this._db);

  final HsDatabase _db;

  /// The briefing for one category, newest first, capped so the list always
  /// ends. Pass a null [category] for every enabled source.
  Stream<List<Headline>> watchBriefing({String? category, int limit = 120}) {
    final query =
        _db.select(_db.articles).join([
            innerJoin(
              _db.sources,
              _db.sources.id.equalsExp(_db.articles.sourceId),
            ),
          ])
          ..where(_db.sources.enabled.equals(true))
          ..orderBy([OrderingTerm.desc(_db.articles.publishedAt)])
          ..limit(limit);

    if (category != null) {
      query.where(_db.sources.category.equals(category));
    }

    return query.watch().map(
      (rows) => rows
          .map(
            (r) =>
                Headline(r.readTable(_db.articles), r.readTable(_db.sources)),
          )
          .toList(),
    );
  }

  /// Linger works the unread part of the same finite set, oldest-of-the-new
  /// first so the reader moves forward through the day.
  Stream<List<Headline>> watchLinger({int limit = 40}) {
    final query =
        _db.select(_db.articles).join([
            innerJoin(
              _db.sources,
              _db.sources.id.equalsExp(_db.articles.sourceId),
            ),
          ])
          ..where(_db.sources.enabled.equals(true))
          ..where(_db.articles.readInFull.equals(false))
          ..orderBy([OrderingTerm.desc(_db.articles.publishedAt)])
          ..limit(limit);

    return query.watch().map(
      (rows) => rows
          .map(
            (r) =>
                Headline(r.readTable(_db.articles), r.readTable(_db.sources)),
          )
          .toList(),
    );
  }

  Stream<Headline?> watchOne(int articleId) {
    final query = _db.select(_db.articles).join([
      innerJoin(_db.sources, _db.sources.id.equalsExp(_db.articles.sourceId)),
    ])..where(_db.articles.id.equals(articleId));

    return query.watchSingleOrNull().map(
      (r) => r == null
          ? null
          : Headline(r.readTable(_db.articles), r.readTable(_db.sources)),
    );
  }

  /// How many items in each source the reader has not seen yet — the quiet
  /// "4 new" / "caught up" line on the Sources screen. A state, not a score:
  /// it disappears the moment they have been seen, and never reaches the nav.
  Stream<Map<int, int>> watchUnseenBySource() {
    final count = _db.articles.id.count();
    final query = _db.selectOnly(_db.articles)
      ..addColumns([_db.articles.sourceId, count])
      ..where(_db.articles.readInReel.equals(false))
      ..where(_db.articles.readInFull.equals(false))
      ..groupBy([_db.articles.sourceId]);

    return query.watch().map(
      (rows) => {
        for (final row in rows)
          row.read(_db.articles.sourceId)!: row.read(count)!,
      },
    );
  }

  /// Upserts a batch of parsed items, deduplicating on `(sourceId, guid)`.
  /// Returns how many were genuinely new.
  Future<int> upsert(int sourceId, List<ParsedArticle> parsed) async {
    if (parsed.isEmpty) return 0;

    final existing =
        await (_db.select(_db.articles)
              ..where((a) => a.sourceId.equals(sourceId))
              ..where((a) => a.guid.isIn(parsed.map((p) => p.guid))))
            .get();
    final known = {for (final row in existing) row.guid: row};

    var added = 0;
    await _db.batch((batch) {
      for (final item in parsed) {
        final prior = known[item.guid];
        if (prior == null) {
          added++;
          batch.insert(
            _db.articles,
            ArticlesCompanion.insert(
              sourceId: sourceId,
              guid: item.guid,
              title: item.title,
              link: item.link,
              publishedAt: item.publishedAt,
              summary: Value(item.summary),
              contentSnippet: Value(item.contentSnippet),
              fullContentHtml: Value(item.fullContentHtml),
              author: Value(item.author),
              imageUrl: Value(item.imageUrl),
            ),
            mode: InsertMode.insertOrIgnore,
          );
        } else {
          // A publisher may correct a headline or fill in the body later.
          batch.update(
            _db.articles,
            ArticlesCompanion(
              title: Value(item.title),
              summary: Value(item.summary),
              contentSnippet: Value(item.contentSnippet),
              fullContentHtml: Value(
                item.fullContentHtml ?? prior.fullContentHtml,
              ),
              imageUrl: Value(item.imageUrl ?? prior.imageUrl),
            ),
            where: (a) => a.id.equals(prior.id),
          );
        }
      }
    });
    return added;
  }

  Future<void> cacheExtractedHtml(int articleId, String html) =>
      (_db.update(_db.articles)..where((a) => a.id.equals(articleId))).write(
        ArticlesCompanion(fullContentHtml: Value(html)),
      );

  /// Silent read marking. No confirmation, no counter.
  Future<void> markRead(
    int articleId, {
    required ReadMode mode,
    Duration dwell = Duration.zero,
  }) async {
    await (_db.update(
      _db.articles,
    )..where((a) => a.id.equals(articleId))).write(
      mode == ReadMode.full
          ? const ArticlesCompanion(
              readInFull: Value(true),
              readInReel: Value(true),
            )
          : const ArticlesCompanion(readInReel: Value(true)),
    );
    await _db
        .into(_db.readEvents)
        .insert(
          ReadEventsCompanion.insert(
            articleId: articleId,
            mode: mode,
            dwellMs: Value(dwell.inMilliseconds),
          ),
        );
  }
}
