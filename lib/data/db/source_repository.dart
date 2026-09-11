import 'dart:ui' show Color;

import 'package:drift/drift.dart';
import 'package:headshorts/core/tokens/accents.dart';
import 'package:headshorts/data/db/database.dart';
import 'package:headshorts/data/db/tables.dart';
import 'package:headshorts/data/sources/source_adapter.dart';

/// Reads and writes subscriptions. Adding a feed is a row — no code.
class SourceRepository {
  const new(this._db);

  final HsDatabase _db;

  Stream<List<SourceRow>> watchAll() =>
      (_db.select(_db.sources)..orderBy([
            (s) => OrderingTerm(expression: s.sortOrder),
            (s) => OrderingTerm(expression: s.title),
          ]))
          .watch();

  Stream<SourceRow?> watchById(int id) => (_db.select(
    _db.sources,
  )..where((s) => s.id.equals(id))).watchSingleOrNull();

  Future<List<SourceRow>> enabled() =>
      (_db.select(_db.sources)..where((s) => s.enabled.equals(true))).get();

  Future<List<SourceRow>> all() => _db.select(_db.sources).get();

  /// Distinct categories in display order, so Today's sub-tabs follow the
  /// reader's own grouping rather than a fixed list.
  Stream<List<String>> watchCategories() => watchAll().map(
    (rows) =>
        rows.where((r) => r.enabled).map((r) => r.category).toSet().toList(),
  );

  /// Inserts a subscription, or quietly does nothing if the feed is already
  /// subscribed. Returns the row id either way.
  Future<int> add({
    required String title,
    required String feedUrl,
    required String category,
    String? siteUrl,
    SourceAccent? accent,
    SourceType type = SourceType.rss,
  }) async {
    final existing = await (_db.select(
      _db.sources,
    )..where((s) => s.feedUrl.equals(feedUrl))).getSingleOrNull();
    if (existing != null) return existing.id;

    final tone = accent ?? SourceAccent.fromKey(feedUrl);
    return await _db
        .into(_db.sources)
        .insert(
          SourcesCompanion.insert(
            title: title,
            feedUrl: feedUrl,
            category: category,
            accentDark: tone.darkValue,
            accentLight: tone.lightValue,
            type: type,
            siteUrl: Value(siteUrl),
          ),
        );
  }

  Future<void> setEnabled(int id, {required bool enabled}) =>
      (_db.update(_db.sources)..where((s) => s.id.equals(id))).write(
        SourcesCompanion(enabled: Value(enabled)),
      );

  Future<void> setAccent(int id, SourceAccent accent) =>
      (_db.update(_db.sources)..where((s) => s.id.equals(id))).write(
        SourcesCompanion(
          accentDark: Value(accent.darkValue),
          accentLight: Value(accent.lightValue),
        ),
      );

  Future<void> setCategory(int id, String category) =>
      (_db.update(_db.sources)..where((s) => s.id.equals(id))).write(
        SourcesCompanion(category: Value(category)),
      );

  /// Keeps a source out of the merged Latest list while leaving it in its own
  /// category. For a firehose the reader wants, but not in with everything
  /// else.
  Future<void> setMutedInLatest(int id, {required bool muted}) =>
      (_db.update(_db.sources)..where((s) => s.id.equals(id))).write(
        SourcesCompanion(mutedInLatest: Value(muted)),
      );

  /// Renames a category across every source in it, and returns how many moved.
  ///
  /// A category is only ever a label on a source, so this is the whole model:
  /// renaming onto a name that already exists merges the two, and a name that
  /// does not exist yet is created by using it.
  Future<int> renameCategory(String from, String to) {
    final name = to.trim();
    if (name.isEmpty || name == from) return Future.value(0);
    return (_db.update(_db.sources)..where((s) => s.category.equals(from)))
        .write(SourcesCompanion(category: Value(name)));
  }

  Future<void> reorder(List<int> idsInOrder) => _db.batch((b) {
    for (var i = 0; i < idsInOrder.length; i++) {
      b.update(
        _db.sources,
        SourcesCompanion(sortOrder: Value(i)),
        where: (s) => s.id.equals(idsInOrder[i]),
      );
    }
  });

  Future<void> remove(int id) =>
      (_db.delete(_db.sources)..where((s) => s.id.equals(id))).go();

  Future<void> recordSuccess(int id, {String? etag, String? lastModified}) =>
      (_db.update(_db.sources)..where((s) => s.id.equals(id))).write(
        SourcesCompanion(
          etag: Value(etag),
          lastModified: Value(lastModified),
          lastFetchedAt: Value(DateTime.now()),
          failingSince: const Value(null),
          lastError: const Value(null),
        ),
      );

  /// Records a failure without clearing [Sources.failingSince], so the source
  /// screen can say "has not responded for six days" rather than "just now".
  Future<void> recordFailure(int id, String message) async {
    final row = await (_db.select(
      _db.sources,
    )..where((s) => s.id.equals(id))).getSingleOrNull();
    if (row == null) return;
    await (_db.update(_db.sources)..where((s) => s.id.equals(id))).write(
      SourcesCompanion(
        lastError: Value(message),
        failingSince: Value(row.failingSince ?? DateTime.now()),
      ),
    );
  }
}

extension SourceRowAccent on SourceRow {
  SourceAccent get accent =>
      SourceAccent(Color(accentDark), Color(accentLight));

  SourceRef get ref => SourceRef(
    id: id,
    feedUrl: feedUrl,
    type: type,
    etag: etag,
    lastModified: lastModified,
  );

  /// The app stops retrying a feed after a fortnight of silence.
  static const retryHorizon = Duration(days: 14);

  bool get isAbandoned =>
      failingSince != null &&
      DateTime.now().difference(failingSince!) > retryHorizon;
}
