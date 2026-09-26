import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show immutable;
import 'package:headshorts/core/util/canonical_url.dart';
import 'package:headshorts/data/db/database.dart';
import 'package:headshorts/data/db/tables.dart';
import 'package:headshorts/data/feed/feed_parser.dart';
import 'package:headshorts/data/sources/source_adapter.dart';

/// How many items Today loads at a time.
const todayPageSize = 25;

/// The most items Linger will queue in one sitting.
const lingerQueueSize = 60;

/// The maximum age of articles displayed or retained (90 days / 3 months),
/// enforcing Google Play News & Magazines policy freshness requirements.
const maxArticleAge = Duration(days: 90);

/// The most results one search returns. Finite, like every other list: a
/// search that matches more than this says so rather than growing a cursor.
const searchResultLimit = 200;

/// Turns what the reader typed into an FTS5 MATCH expression.
///
/// Every term is quoted and given a prefix star, so `heat wav` finds
/// "heatwave warning" while a stray quote, hyphen or `AND` cannot become
/// syntax and throw. Returns null when there is nothing to search for —
/// a query of punctuation alone is not a query.
String? ftsQuery(String raw) {
  final terms = raw
      .split(RegExp(r'\s+'))
      .map((t) => t.replaceAll('"', '').trim())
      .where((t) => t.isNotEmpty)
      .toList();
  if (terms.isEmpty) return null;
  return terms.map((t) => '"$t"*').join(' ');
}

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
    Set<int>? sourceIds,
    Set<int>? mutedSourceIds,
    ArticleCursor? floor,
    int pageSize = todayPageSize,
  }) {
    final query = _scoped(
      category: category,
      sourceIds: sourceIds,
      mutedSourceIds: mutedSourceIds,
    );

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
    Set<int>? sourceIds,
    Set<int>? mutedSourceIds,
    ArticleCursor? floor,
    int pageSize = todayPageSize,
  }) async {
    final query = _scoped(
      category: category,
      sourceIds: sourceIds,
      mutedSourceIds: mutedSourceIds,
    )..limit(pageSize);
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
    final query = _scoped(category: category, sourceIds: sourceIds)
      ..where(_db.articles.seenInLinger.equals(false))
      ..where(_db.articles.readFull.equals(false))
      ..limit(limit * 2);

    return dedupeStories(_headlines(await query.get())).take(limit).toList();
  }

  /// Full-text search over the cache.
  ///
  /// The index is FTS5 in external-content mode (see `_createSearchIndex`),
  /// so this costs a term lookup rather than a scan of every article, and it
  /// works with no network at all.
  ///
  /// Deliberately **not ranked**. FTS5 will happily order by bm25 relevance;
  /// this orders by publication date like every other list in the app, and
  /// the result count is stated rather than paginated. Unlike the briefing,
  /// a paused source is still searchable — the scope decides what is in, and
  /// the scope is the reader's, not the subscription's.
  Future<List<Headline>> search({
    required String query,
    Set<int>? sourceIds,
    DateTime? from,
    DateTime? to,
    int limit = searchResultLimit,
  }) async {
    final match = ftsQuery(query);
    if (match == null) return const [];

    final ids = await _db.searchArticleIds(
      match: match,
      sourceIds: sourceIds,
      from: from,
      to: to,
      limit: limit,
    );
    if (ids.isEmpty) return const [];

    final rows = await (_db.select(_db.articles).join([
      innerJoin(_db.sources, _db.sources.id.equalsExp(_db.articles.sourceId)),
    ])..where(_db.articles.id.isIn(ids))).get();

    final found = _headlines(rows);
    // The ids came back in date order; the join did not promise to keep it.
    final byId = {for (final item in found) item.article.id: item};
    return dedupeStories([for (final id in ids) ?byId[id]]);
  }

  /// Which of [sourceIds] have anything cached at all.
  ///
  /// What decides whether Search has to go and fetch a source: a subscription
  /// is not the same thing as a cache. A source added a minute ago, one whose
  /// items the prune has taken, or one paused long enough to be emptied, is
  /// subscribed and has nothing to search.
  Future<Set<int>> sourcesWithCache(Set<int> sourceIds) async {
    if (sourceIds.isEmpty) return const {};
    final rows =
        await (_db.selectOnly(_db.articles)
              ..addColumns([_db.articles.sourceId])
              ..where(_db.articles.sourceId.isIn(sourceIds))
              ..groupBy([_db.articles.sourceId]))
            .get();
    return {for (final row in rows) row.read(_db.articles.sourceId)!};
  }

  /// The enabled, in-scope articles, newest first, as a total order.
  /// Enforces a strict 90-day (< 3 months) freshness limit.
  JoinedSelectStatement<HasResultSet, dynamic> _scoped({
    String? category,
    Set<int>? sourceIds,
    Set<int>? mutedSourceIds,
  }) {
    final cutoff = DateTime.now().subtract(maxArticleAge);
    final query =
        _db.select(_db.articles).join([
            innerJoin(
              _db.sources,
              _db.sources.id.equalsExp(_db.articles.sourceId),
            ),
          ])
          ..where(_db.sources.enabled.equals(true))
          ..where(_db.articles.publishedAt.isBiggerOrEqualValue(cutoff))
          ..orderBy([
            OrderingTerm.desc(_db.articles.publishedAt),
            OrderingTerm.desc(_db.articles.id),
          ]);

    if (category != null) {
      query.where(_db.sources.category.equals(category));
    } else {
      query.where(_db.sources.mutedInLatest.equals(false));
    }

    if (sourceIds != null) {
      query.where(_db.sources.id.isIn(sourceIds));
    }
    if (mutedSourceIds != null && mutedSourceIds.isNotEmpty) {
      query.where(_db.sources.id.isNotIn(mutedSourceIds));
    }

    return query;
  }

  /// Watches unread article count by category and overall ('All').
  Stream<Map<String, int>> watchUnreadCountByCategory() {
    final cutoff = DateTime.now().subtract(maxArticleAge);
    final count = _db.articles.id.count();
    final query =
        _db.selectOnly(_db.articles).join([
            innerJoin(
              _db.sources,
              _db.sources.id.equalsExp(_db.articles.sourceId),
            ),
          ])
          ..addColumns([_db.sources.category, count])
          ..where(_db.sources.enabled.equals(true))
          ..where(_db.articles.readFull.equals(false))
          ..where(_db.articles.publishedAt.isBiggerOrEqualValue(cutoff))
          ..groupBy([_db.sources.category]);

    return query.watch().map((rows) {
      final map = <String, int>{};
      var total = 0;
      for (final row in rows) {
        final cat = row.read(_db.sources.category);
        final cnt = row.read(count) ?? 0;
        if (cat != null) {
          map[cat] = cnt;
          total += cnt;
        }
      }
      map['All'] = total;
      return map;
    });
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
    final cutoff = DateTime.now().subtract(maxArticleAge);
    final query =
        _db.select(_db.articles).join([
            innerJoin(
              _db.sources,
              _db.sources.id.equalsExp(_db.articles.sourceId),
            ),
          ])
          ..where(_db.articles.id.equals(articleId))
          ..where(_db.articles.publishedAt.isBiggerOrEqualValue(cutoff));

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
    final cutoff = DateTime.now().subtract(maxArticleAge);
    final count = _db.articles.id.count();
    final query = _db.selectOnly(_db.articles)
      ..addColumns([_db.articles.sourceId, count])
      ..where(_db.articles.seenInLinger.equals(false))
      ..where(_db.articles.readFull.equals(false))
      ..where(_db.articles.publishedAt.isBiggerOrEqualValue(cutoff))
      ..groupBy([_db.articles.sourceId]);

    return query.watch().map(
      (rows) => {
        for (final row in rows)
          row.read(_db.articles.sourceId)!: row.read(count)!,
      },
    );
  }

  /// Upserts a batch of parsed items, deduplicating on `(sourceId, guid)`.
  /// Excludes items older than [maxArticleAge] (90 days).
  /// Returns how many were genuinely new.
  Future<int> upsert(int sourceId, List<ParsedArticle> parsed) async {
    if (parsed.isEmpty) return 0;

    final cutoff = DateTime.now().subtract(maxArticleAge);
    final fresh = parsed
        .where(
          (p) =>
              p.publishedAt.isAfter(cutoff) ||
              p.publishedAt.isAtSameMomentAs(cutoff),
        )
        .toList();
    if (fresh.isEmpty) return 0;

    final existing =
        await (_db.select(_db.articles)
              ..where((a) => a.sourceId.equals(sourceId))
              ..where((a) => a.guid.isIn(fresh.map((p) => p.guid))))
            .get();
    final known = {for (final row in existing) row.guid: row};

    var added = 0;
    await _db.batch((batch) {
      for (final item in fresh) {
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
              author: Value(item.author ?? prior.author),
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

  Future<void> cacheExtractedHtml(
    int articleId,
    String html, {
    String? snippet,
  }) async {
    // Blocks joined, not the whole document collapsed: a teaser that reads
    // "…clash.Star Indian weightlifter…" is the block boundary going missing.
    final text = FeedParser.blockText(html).join(' ');
    final derivedSnippet =
        snippet ?? (text.length > 300 ? '${text.substring(0, 300)}…' : text);
    final prior = await (_db.select(
      _db.articles,
    )..where((a) => a.id.equals(articleId))).getSingleOrNull();
    final needSnippet =
        prior != null &&
        (prior.contentSnippet == null || prior.contentSnippet!.isEmpty);
    await (_db.update(
      _db.articles,
    )..where((a) => a.id.equals(articleId))).write(
      ArticlesCompanion(
        fullContentHtml: Value(html),
        contentSnippet: needSnippet
            ? Value(derivedSnippet.isEmpty ? null : derivedSnippet)
            : const Value.absent(),
      ),
    );
  }

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
