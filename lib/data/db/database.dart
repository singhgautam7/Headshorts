import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:headshorts/data/db/tables.dart';

part 'database.g.dart';

/// The local database is the source of truth the UI reads from. The network
/// only ever refreshes it, so the app opens instantly from cache and keeps
/// working offline.
@DriftDatabase(tables: [Sources, Articles, ReadEvents, CaughtUpDays])
class HsDatabase extends _$HsDatabase {
  new() : super(driftDatabase(name: 'headshorts'));

  new forTesting(super.e);

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await _createIndices();
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
      await _createIndices();
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
      await _createIndices();
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

  /// Empties the article cache, leaving subscriptions and their settings
  /// alone.
  ///
  /// Read state goes with it: the rows that carried it are the ones being
  /// deleted, and pretending otherwise would leave "read" markers pointing at
  /// nothing.
  Future<void> clearCache() async {
    await delete(readEvents).go();
    await delete(articles).go();
  }

  /// Keeps the newest [keep] articles per source and drops items older than
  /// [maxAge] (90 days / 3 months), so the database stays fresh and compliant
  /// with News & Magazines freshness policies.
  Future<void> pruneToRetention({
    int keep = 200,
    Duration maxAge = const Duration(days: 90),
  }) async {
    final cutoff = DateTime.now().subtract(maxAge);
    await (delete(articles)
          ..where((a) => a.publishedAt.isSmallerThanValue(cutoff)))
        .go();
    await customStatement(
      '''
      DELETE FROM articles WHERE id IN (
        SELECT id FROM (
          SELECT id, ROW_NUMBER() OVER (
            PARTITION BY source_id ORDER BY published_at DESC
          ) AS rn FROM articles
        ) WHERE rn > ?
      )
      ''',
      [keep],
    );
  }
}
