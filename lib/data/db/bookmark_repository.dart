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

  /// Most recently saved first — the order the list is in.
  Stream<List<BookmarkRow>> watchAll() => (_db.select(
    _db.bookmarks,
  )..orderBy([(b) => OrderingTerm.desc(b.savedAt)])).watch();

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
    final entry = BookmarksCompanion.insert(
      articleId: Value(article.id),
      link: article.link,
      canonicalUrl: Value(article.canonicalUrl),
      title: article.title,
      summary: Value(article.summary),
      contentHtml: Value(contentHtml ?? article.fullContentHtml),
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

  Future<void> removeByLink(String link) =>
      (_db.delete(_db.bookmarks)..where((b) => b.link.equals(link))).go();

  Future<void> removeById(int id) =>
      (_db.delete(_db.bookmarks)..where((b) => b.id.equals(id))).go();

  /// Puts a removed row back exactly as it was — what Undo calls.
  Future<void> restore(BookmarkRow row) =>
      _db.into(_db.bookmarks).insertOnConflictUpdate(row);

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
