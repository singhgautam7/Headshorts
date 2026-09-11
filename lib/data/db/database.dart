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
  int get schemaVersion => 1;

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
