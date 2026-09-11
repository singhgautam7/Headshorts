import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show immutable;
import 'package:headshorts/core/util/canonical_url.dart';
import 'package:headshorts/data/db/database.dart';
import 'package:headshorts/data/db/tables.dart';
import 'package:headshorts/data/sources/source_adapter.dart';

/// How many items Today loads at a time.
const todayPageSize = 25;

/// The most items Linger will queue in one sitting.
const lingerQueueSize = 60;

/// An article together with the source that published it — what every list in
/// the app actually renders.
class Headline {
  const new(this.article, this.source);

  final ArticleRow article;
  final SourceRow source;

  /// The reader opened the full article. The only sense in which anything in
  /// this app has been "read".
  bool get isRead => article.readFull;

  /// The card settled in Linger. Keeps it from coming round again there, and
  /// means nothing at all in Today.
  bool get isSeen => article.seenInLinger;

  /// Where this item sits in the newest-first order. Paired with the id it is
  /// a total order, so pages never overlap or skip.
  ArticleCursor get cursor => ArticleCursor(article.publishedAt, article.id);
}

/// A position in the newest-first briefing.
///
/// Ordering by `publishedAt` alone is not a total order — feeds routinely
/// stamp several items with the same minute — so the id breaks the tie. Paging
/// from a cursor rather than an offset means a refresh cannot make the list
/// skip or repeat an item under the reader.
@immutable
class ArticleCursor {
  const new(this.publishedAt, this.id);

  final DateTime publishedAt;
  final int id;

  @override
  bool operator ==(Object other) =>
      other is ArticleCursor &&
      other.publishedAt == publishedAt &&
      other.id == id;

  @override
  int get hashCode => Object.hash(publishedAt, id);
}

/// Collapses copies of the same story into one item.
///
/// Two feeds carrying the same article — a publisher's own feed and an
/// aggregator's, or a national and a regional edition — are one thing to read.
/// The first copy in the list wins, so with a newest-first list the reader
/// gets the freshest version.
///
/// Matching is by canonical URL first, then by a loose headline fingerprint
/// for the same story filed under two slightly different titles. Items with
/// neither key are always kept: a false merge is worse than a duplicate.
List<Headline> dedupeStories(List<Headline> items) {
  final seenUrls = <String>{};
  final seenTitles = <String>{};
  final out = <Headline>[];

  for (final item in items) {
    final url = item.article.canonicalUrl;
    final title = item.article.titleKey;
    if (url.isNotEmpty && !seenUrls.add(url)) continue;
    if (title.isNotEmpty && !seenTitles.add(title)) continue;
    out.add(item);
  }
  return out;
}

/// Stops one prolific source from filling the screen.
///
/// Chronological order is kept for everything that fits; an item that would be
/// the [maxRun]+1st in a row from the same source is held back and released as
/// soon as something from elsewhere has broken the run. Nothing is dropped and
/// nothing is scored — this is fairness, not relevance. Off unless the reader
/// turns it on.
///
/// At the very end of a finite list there may be nothing left to interleave
/// with, so held-back items simply follow. A list that is one source all the
/// way down is one source all the way down.
List<Headline> capConsecutive(List<Headline> items, int maxRun) {
  if (maxRun <= 0 || items.length < 2) return items;

  final out = <Headline>[];
  final held = <Headline>[];
  int? lastSource;
  var run = 0;

  bool fits(Headline item) => item.source.id != lastSource || run < maxRun;

  void append(Headline item) {
    if (item.source.id == lastSource) {
      run++;
    } else {
      lastSource = item.source.id;
      run = 1;
    }
    out.add(item);
  }

  for (final item in items) {
    // Anything held back goes as soon as it fits again.
    held.removeWhere((waiting) {
      if (!fits(waiting)) return false;
      append(waiting);
      return true;
    });

    if (fits(item)) {
      append(item);
    } else {
      held.add(item);
    }
  }

  return out..addAll(held);
}

/// Reads the cached briefing. Finite by construction: every query is bounded,
/// there is no cursor and no "load more".
class ArticleRepository {
  const new(this._db);

  final HsDatabase _db;

  /// The briefing for one category, newest first, capped so the list always
  /// ends. Pass a null [category] for every enabled source.
  /// One page of Today, plus everything above it.
  ///
  /// Reactive over the whole loaded window: a refresh prepends new items and
  /// the reader's position is untouched, because the window is bounded by a
  /// cursor rather than by an offset. Nothing below [floor] is loaded until
  /// the reader asks for it.
  ///
  /// Today shows everything cached. `seenInLinger` has no bearing here at all,
  /// and `readFull` only de-emphasises.
  Stream<List<Headline>> watchBriefing({
    String? category,
    ArticleCursor? floor,
    int pageSize = todayPageSize,
  }) {
    final query = _scoped(category: category);

    if (floor == null) {
      // Over-fetch: dedup removes items and the page must still fill.
      query.limit(pageSize * 2);
    } else {
      query.where(_atOrAbove(floor));
    }

    return query.watch().map((rows) => dedupeStories(_headlines(rows)));
  }

  /// The cursor that ends the next page, or null when there is no next page.
  ///
  /// One small query per page turn, and it reads keys only — the content
  /// itself arrives through [watchBriefing]'s stream.
  Future<ArticleCursor?> nextFloor({
    String? category,
    ArticleCursor? floor,
    int pageSize = todayPageSize,
  }) async {
    final query = _scoped(category: category)..limit(pageSize);
    if (floor != null) query.where(_below(floor));

    final page = _headlines(await query.get());
    return page.isEmpty ? null : page.last.cursor;
  }

  /// The finite set Linger is working through: everything not yet seen there
  /// and not yet read.
  ///
  /// A snapshot, deliberately. The filter is applied when the queue is built,
  /// so marking the card in front of the reader as seen does not pull it out
  /// from under them — it simply does not come back next time.
  Future<List<Headline>> buildLingerQueue({
    String? category,
    Set<int>? sourceIds,
    int limit = lingerQueueSize,
  }) async {
    final query = _scoped(category: category)
      ..where(_db.articles.seenInLinger.equals(false))
      ..where(_db.articles.readFull.equals(false))
      ..limit(limit * 2);

    // A null set is "everything in scope"; an empty one is a filter that
    // matches nothing, and saying so beats quietly showing everything.
    if (sourceIds != null) {
      query.where(_db.sources.id.isIn(sourceIds));
    }

    return dedupeStories(_headlines(await query.get())).take(limit).toList();
  }

  /// The enabled, in-scope articles, newest first, as a total order.
  JoinedSelectStatement<HasResultSet, dynamic> _scoped({String? category}) {
    final query =
        _db.select(_db.articles).join([
            innerJoin(
              _db.sources,
              _db.sources.id.equalsExp(_db.articles.sourceId),
            ),
          ])
          ..where(_db.sources.enabled.equals(true))
          ..orderBy([
            OrderingTerm.desc(_db.articles.publishedAt),
            OrderingTerm.desc(_db.articles.id),
          ]);

    if (category != null) {
      query.where(_db.sources.category.equals(category));
    } else {
      query.where(_db.sources.mutedInLatest.equals(false));
    }
    return query;
  }

  Expression<bool> _atOrAbove(ArticleCursor cursor) =>
      _db.articles.publishedAt.isBiggerThanValue(cursor.publishedAt) |
      (_db.articles.publishedAt.equals(cursor.publishedAt) &
          _db.articles.id.isBiggerOrEqualValue(cursor.id));

  Expression<bool> _below(ArticleCursor cursor) =>
      _db.articles.publishedAt.isSmallerThanValue(cursor.publishedAt) |
      (_db.articles.publishedAt.equals(cursor.publishedAt) &
          _db.articles.id.isSmallerThanValue(cursor.id));

  List<Headline> _headlines(List<TypedResult> rows) => rows
      .map((r) => Headline(r.readTable(_db.articles), r.readTable(_db.sources)))
      .toList();

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
      ..where(_db.articles.seenInLinger.equals(false))
      ..where(_db.articles.readFull.equals(false))
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
              canonicalUrl: Value(canonicalUrl(item.link)),
              titleKey: Value(titleFingerprint(item.title)),
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
              canonicalUrl: Value(canonicalUrl(item.link)),
              titleKey: Value(titleFingerprint(item.title)),
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
  /// Records that the reader met an article, in one of two quite different
  /// ways.
  ///
  /// [ReadMode.linger] sets `seenInLinger` and nothing else — seeing a card is
  /// not reading an article, and it has no effect on Today.
  /// [ReadMode.full] sets `readFull`, and is the only thing that does.
  ///
  /// Either way it marks every copy of the story, not just the row that was
  /// tapped: the same article syndicated through two feeds is one thing, and
  /// the other copy must not come round again.
  Future<void> mark(
    int articleId, {
    required ReadMode mode,
    Duration dwell = Duration.zero,
  }) async {
    final update = mode == ReadMode.full
        ? const ArticlesCompanion(readFull: Value(true))
        : const ArticlesCompanion(seenInLinger: Value(true));

    final article = await (_db.select(
      _db.articles,
    )..where((a) => a.id.equals(articleId))).getSingleOrNull();
    if (article == null) return;

    final canonical = article.canonicalUrl;
    await (_db.update(_db.articles)..where(
          (a) => canonical.isEmpty
              ? a.id.equals(articleId)
              : a.id.equals(articleId) | a.canonicalUrl.equals(canonical),
        ))
        .write(update);

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
