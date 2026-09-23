import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:headshorts/data/db/tables.dart';

part 'database.g.dart';

/// The local database is the source of truth the UI reads from. The network
/// only ever refreshes it, so the app opens instantly from cache and keeps
/// working offline.
@DriftDatabase(tables: [Sources, Articles, ReadEvents, CaughtUpDays, Bookmarks])
class HsDatabase extends _$HsDatabase {
  new() : super(driftDatabase(name: 'headshorts'));

  new forTesting(super.e);

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await _createIndices();
      await _createSearchIndex();
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        // Cross-feed dedup and per-source muting. Existing rows get empty
        // keys and are backfilled on the next refresh.
        await m.addColumn(articles, articles.canonicalUrl);
        await m.addColumn(articles, articles.titleKey);
        await m.addColumn(sources, sources.mutedInLatest);
      }
      if (from < 3) {
        // Seen and read become two independent states. The old flags carry
        // straight over: `read_in_reel` was exactly "seen in Linger", and
        // `read_in_full` was exactly "opened the full article".
        await m.renameColumn(articles, 'read_in_reel', articles.seenInLinger);
        await m.renameColumn(articles, 'read_in_full', articles.readFull);
      }
      if (from < 4) {
        // A language label on each source, and bookmarks as their own table
        // so no prune or cascade can reach a saved article.
        await m.addColumn(sources, sources.language);
        await m.createTable(bookmarks);
      }
      await _createIndices();
      await _createSearchIndex();
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
      await _createIndices();
      await _createSearchIndex();
    },
  );

  /// Creates indexes for fast keyset pagination, deduplication, and
  /// read-state propagation across multiple feeds.
  Future<void> _createIndices() async {
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_articles_published_id '
      'ON articles(published_at DESC, id DESC)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_articles_canonical_url '
      'ON articles(canonical_url)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_articles_title_key '
      'ON articles(title_key)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_articles_source_id '
      'ON articles(source_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_sources_category_enabled '
      'ON sources(category, enabled)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_articles_unread '
      'ON articles(source_id, read_full)',
    );
  }

  /// The full-text index over the cached articles.
  ///
  /// FTS5 in *external content* mode: the index stores no copy of the text,
  /// only the terms, and reads the columns back out of `articles` by rowid.
  /// Three triggers keep it in step with the table, because an external
  /// content table is not maintained by SQLite on its own.
  ///
  /// `unicode61` with `remove_diacritics 2` is what makes a Devanagari or
  /// Tamil headline tokenise at all — the default tokeniser would treat a
  /// whole non-Latin headline as one token.
  Future<void> _createSearchIndex() async {
    final existed = await customSelect(
      "SELECT name FROM sqlite_master WHERE type = 'table'"
      " AND name = 'articles_fts'",
    ).get();

    await customStatement('''
      CREATE VIRTUAL TABLE IF NOT EXISTS articles_fts USING fts5(
        title, summary, content_snippet,
        content = 'articles', content_rowid = 'id',
        tokenize = 'unicode61 remove_diacritics 2'
      )
      ''');
    await customStatement(
      'CREATE TRIGGER IF NOT EXISTS articles_fts_insert '
      'AFTER INSERT ON articles BEGIN '
      'INSERT INTO articles_fts(rowid, title, summary, content_snippet) '
      'VALUES (new.id, new.title, new.summary, new.content_snippet); END',
    );
    await customStatement(
      'CREATE TRIGGER IF NOT EXISTS articles_fts_delete '
      'AFTER DELETE ON articles BEGIN '
      'INSERT INTO articles_fts(articles_fts, rowid, title, summary, '
      'content_snippet) '
      "VALUES ('delete', old.id, old.title, old.summary, "
      'old.content_snippet); END',
    );
    await customStatement(
      'CREATE TRIGGER IF NOT EXISTS articles_fts_update '
      'AFTER UPDATE ON articles BEGIN '
      'INSERT INTO articles_fts(articles_fts, rowid, title, summary, '
      'content_snippet) '
      "VALUES ('delete', old.id, old.title, old.summary, "
      'old.content_snippet); '
      'INSERT INTO articles_fts(rowid, title, summary, content_snippet) '
      'VALUES (new.id, new.title, new.summary, new.content_snippet); END',
    );

    // A fresh index over a table that already has rows — an upgrade, or a
    // database whose index was dropped — has to be told to catch up.
    if (existed.isEmpty) {
      await customStatement(
        "INSERT INTO articles_fts(articles_fts) VALUES ('rebuild')",
      );
    }
  }

  /// Article ids matching [match] (an FTS5 expression), newest first.
  ///
  /// Ids rather than rows: the join back through `sources` is a normal drift
  /// query, so nothing downstream has to read prefixed result columns.
  Future<List<int>> searchArticleIds({
    required String match,
    Set<int>? sourceIds,
    DateTime? from,
    DateTime? to,
    int limit = 200,
  }) async {
    final where = StringBuffer('articles_fts MATCH ?');
    final args = <Object?>[match];
    if (sourceIds != null) {
      if (sourceIds.isEmpty) return const [];
      where.write(
        ' AND a.source_id IN (${List.filled(sourceIds.length, '?').join(',')})',
      );
      args.addAll(sourceIds);
    }
    if (from != null) {
      where.write(' AND a.published_at >= ?');
      args.add(from.millisecondsSinceEpoch ~/ 1000);
    }
    if (to != null) {
      where.write(' AND a.published_at <= ?');
      args.add(to.millisecondsSinceEpoch ~/ 1000);
    }
    args.add(limit);

    final rows = await customSelect(
      'SELECT a.id AS id FROM articles_fts '
      'JOIN articles a ON a.id = articles_fts.rowid '
      'WHERE $where '
      'ORDER BY a.published_at DESC, a.id DESC LIMIT ?',
      variables: [for (final a in args) Variable(a)],
      readsFrom: {articles, sources},
    ).get();
    return [for (final row in rows) row.read<int>('id')];
  }

  /// Empties the article cache, leaving subscriptions and their settings
  /// alone.
  ///
  /// Read state goes with it: the rows that carried it are the ones being
  /// deleted, and pretending otherwise would leave "read" markers pointing at
  /// nothing.
  Future<void> clearCache() async {
    await delete(readEvents).go();
    await customStatement(
      'DELETE FROM articles WHERE link NOT IN (SELECT link FROM bookmarks)',
    );
  }

  /// Keeps the newest [keep] articles per source and drops items older than
  /// [maxAge] (90 days / 3 months), so the database stays fresh and compliant
  /// with News & Magazines freshness policies.
  Future<void> pruneToRetention({
    int keep = 200,
    Duration maxAge = const Duration(days: 90),
  }) async {
    // A saved article is exempt from both limits. That is the whole promise
    // of a bookmark: it outlives the cache it came from.
    final cutoff = DateTime.now().subtract(maxAge);
    await customStatement(
      'DELETE FROM articles WHERE published_at < ? '
      'AND link NOT IN (SELECT link FROM bookmarks)',
      [cutoff.millisecondsSinceEpoch ~/ 1000],
    );
    await customStatement(
      '''
      DELETE FROM articles WHERE id IN (
        SELECT id FROM (
          SELECT id, ROW_NUMBER() OVER (
            PARTITION BY source_id ORDER BY published_at DESC
          ) AS rn FROM articles
        ) WHERE rn > ?
      ) AND link NOT IN (SELECT link FROM bookmarks)
      ''',
      [keep],
    );
  }
}
