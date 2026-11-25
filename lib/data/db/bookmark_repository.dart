import 'package:drift/drift.dart';
import 'package:headshorts/core/tokens/accents.dart';
import 'package:headshorts/data/db/article_repository.dart';
import 'package:headshorts/data/db/database.dart';

/// Saved articles.
///
/// A bookmark is a **copy**, not a reference: the article it was made from is
/// pruned to 200 per source and to 90 days, and the source it came from can
/// be unsubscribed, which takes its rows with it. Everything the Reader needs
/// is written into the bookmark at save time, so a saved article opens months
/// later, offline, whatever has happened to the cache.
class BookmarkRepository {
  const new(this._db);

  final HsDatabase _db;

  /// Bodies of bookmarks removed this session, so Undo can put them back: the
  /// list below does not carry bodies, so the row Undo is handed has none.
  static final _removed = <String, String?>{};

  /// Most recently saved first — the order the list is in.
  ///
  /// Without [BookmarkRow.contentHtml]: the list never draws it, and every
  /// saved body would otherwise cross the isolate on each change. Open one
  /// with [byId] to get the body.
  Stream<List<BookmarkRow>> watchAll() {
    final b = _db.bookmarks;
    return (_db.selectOnly(b)
          ..addColumns([
            b.id,
            b.articleId,
            b.link,
            b.canonicalUrl,
            b.title,
            b.summary,
            b.author,
            b.imageUrl,
            b.sourceTitle,
            b.language,
            b.accentDark,
            b.accentLight,
            b.publishedAt,
            b.savedAt,
          ])
          ..orderBy([OrderingTerm.desc(b.savedAt)]))
        .watch()
        .map(
          (rows) => [
            for (final r in rows)
              BookmarkRow(
                id: r.read(b.id)!,
                articleId: r.read(b.articleId),
                link: r.read(b.link)!,
                canonicalUrl: r.read(b.canonicalUrl)!,
                title: r.read(b.title)!,
                summary: r.read(b.summary),
                author: r.read(b.author),
                imageUrl: r.read(b.imageUrl),
                sourceTitle: r.read(b.sourceTitle)!,
                language: r.read(b.language)!,
                accentDark: r.read(b.accentDark)!,
                accentLight: r.read(b.accentLight)!,
                publishedAt: r.read(b.publishedAt)!,
                savedAt: r.read(b.savedAt)!,
              ),
          ],
        );
  }

  Stream<int> watchCount() {
    final count = _db.bookmarks.id.count();
    return (_db.selectOnly(
      _db.bookmarks,
    )..addColumns([count])).watchSingle().map((row) => row.read(count) ?? 0);
  }

  /// Whether this article's link is saved. Keyed on the link rather than the
  /// id, so the second feed's copy of the same story reads as saved too.
  Stream<bool> watchIsSaved(String link) =>
      (_db.select(_db.bookmarks)..where((b) => b.link.equals(link)))
          .watchSingleOrNull()
          .map((row) => row != null);

  Future<BookmarkRow?> byId(int id) => (_db.select(
    _db.bookmarks,
  )..where((b) => b.id.equals(id))).getSingleOrNull();

  Future<BookmarkRow?> byLink(String link) => (_db.select(
    _db.bookmarks,
  )..where((b) => b.link.equals(link))).getSingleOrNull();

  /// Saves [headline], taking the extracted body with it when there is one.
  ///
  /// Keyed on the link rather than the row id, so saving the same story from
  /// a second feed — or saving it again after the first copy was pruned —
  /// updates the one bookmark instead of failing on the unique index.
  Future<void> save(Headline headline, {String? contentHtml}) async {
    final article = headline.article;
    final source = headline.source;
    // A list row carries no body; the article's own is still in the cache.
    var body = contentHtml ?? article.fullContentHtml;
    if (body == null) {
      final a = _db.articles;
      final cached =
          await (_db.selectOnly(a)
                ..addColumns([a.fullContentHtml])
                ..where(a.id.equals(article.id)))
              .getSingleOrNull();
      body = cached?.read(a.fullContentHtml);
    }
    final entry = BookmarksCompanion.insert(
      articleId: Value(article.id),
      link: article.link,
      canonicalUrl: Value(article.canonicalUrl),
      title: article.title,
      summary: Value(article.summary),
      contentHtml: Value(body),
      author: Value(article.author),
      imageUrl: Value(article.imageUrl),
      sourceTitle: source.title,
      language: Value(source.language),
      accentDark: source.accentDark,
      accentLight: source.accentLight,
      publishedAt: article.publishedAt,
      savedAt: Value(DateTime.now()),
    );
    await _db
        .into(_db.bookmarks)
        .insert(
          entry,
          onConflict: DoUpdate((_) => entry, target: [_db.bookmarks.link]),
        );
  }

  Future<void> removeByLink(String link) async {
    await _remember(
      _db.select(_db.bookmarks)..where((b) => b.link.equals(link)),
    );
    await (_db.delete(_db.bookmarks)..where((b) => b.link.equals(link))).go();
  }

  Future<void> removeById(int id) async {
    await _remember(_db.select(_db.bookmarks)..where((b) => b.id.equals(id)));
    await (_db.delete(_db.bookmarks)..where((b) => b.id.equals(id))).go();
  }

  Future<void> _remember(
    SimpleSelectStatement<$BookmarksTable, BookmarkRow> q,
  ) async {
    final row = await q.getSingleOrNull();
    if (row != null) _removed[row.link] = row.contentHtml;
  }

  /// Puts a removed row back exactly as it was — what Undo calls.
  Future<void> restore(BookmarkRow row) {
    final kept = _removed.remove(row.link);
    final restored = row.contentHtml == null && kept != null
        ? row.copyWith(contentHtml: Value(kept))
        : row;
    return _db.into(_db.bookmarks).insertOnConflictUpdate(restored);
  }

  /// Fills a body in after the fact, when extraction finishes while the
  /// article is open and already saved.
  Future<void> attachBody(String link, String html) =>
      (_db.update(_db.bookmarks)..where((b) => b.link.equals(link))).write(
        BookmarksCompanion(contentHtml: Value(html)),
      );
}

extension BookmarkRowAccent on BookmarkRow {
  SourceAccent get accent => SourceAccent.fromValues(accentDark, accentLight);
}
