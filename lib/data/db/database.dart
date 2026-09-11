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
    onCreate: (m) => m.createAll(),
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
    },
  );

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

  /// Keeps the newest [keep] articles per source and drops the rest, so the
  /// database stays light however long the app runs.
  Future<void> pruneToRetention({int keep = 200}) async {
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
