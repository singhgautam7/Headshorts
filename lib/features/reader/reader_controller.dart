import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:headshorts/app/providers.dart';
import 'package:headshorts/core/tokens/accents.dart';
import 'package:headshorts/data/db/article_repository.dart';
import 'package:headshorts/data/db/database.dart';
import 'package:headshorts/data/db/source_repository.dart';
import 'package:headshorts/data/feed/feed_parser.dart';
import 'package:headshorts/data/readability/extraction_service.dart';

final articleProvider = StreamProvider.family<Headline?, int>(
  (ref, id) => ref.watch(articleRepositoryProvider).watchOne(id),
);

/// Which article the Reader was asked for.
///
/// Two ways in, because a saved article outlives the row it was saved from:
/// normally an id in `articles`, and for a bookmark whose source has been
/// unsubscribed or whose row has been pruned, an id in `bookmarks`. A record
/// rather than a sealed class, so it is a provider family key for free.
typedef ReaderKey = ({int? articleId, int? bookmarkId});

/// What the Reader renders, from whichever of the two it was given.
///
/// The screen reads this and never touches an article row or a bookmark row
/// directly, so "open a saved article offline" and "open an article" are one
/// path rather than two screens that drift apart.
@immutable
class ReaderDoc {
  const new({
    required this.sourceTitle,
    required this.accent,
    required this.title,
    required this.link,
    required this.publishedAt,
    this.articleId,
    this.summary,
    this.author,
    this.imageUrl,
    this.language = 'en',
    this.savedHtml,
  });

  factory fromHeadline(Headline headline) => ReaderDoc(
    articleId: headline.article.id,
    sourceTitle: headline.source.title,
    accent: headline.source.accent,
    title: headline.article.title,
    link: headline.article.link,
    publishedAt: headline.article.publishedAt,
    summary: headline.article.summary,
    author: headline.article.author,
    imageUrl: headline.article.imageUrl,
    language: headline.source.language,
  );

  factory fromBookmark(BookmarkRow row) => ReaderDoc(
    articleId: row.articleId,
    sourceTitle: row.sourceTitle,
    accent: SourceAccent.fromValues(row.accentDark, row.accentLight),
    title: row.title,
    link: row.link,
    publishedAt: row.publishedAt,
    summary: row.summary,
    author: row.author,
    imageUrl: row.imageUrl,
    language: row.language,
    savedHtml: row.contentHtml,
  );

  /// The row in `articles`, when there still is one. Null for a bookmark
  /// whose article has been pruned or unsubscribed away — read state and
  /// extraction both key off this, and both are simply skipped without it.
  final int? articleId;

  final String sourceTitle;
  final SourceAccent accent;
  final String title;
  final String link;
  final DateTime publishedAt;
  final String? summary;
  final String? author;
  final String? imageUrl;

  /// The source's language tag, which is what read-aloud asks the engine for.
  final String language;

  /// The body a bookmark carried with it. Present means there is nothing to
  /// extract: what was saved is what is shown.
  final String? savedHtml;
}

final _bookmarkDocProvider = FutureProvider.family<ReaderDoc?, int>((
  ref,
  id,
) async {
  final row = await ref.watch(bookmarkRepositoryProvider).byId(id);
  return row == null ? null : ReaderDoc.fromBookmark(row);
});

/// The document the Reader was asked for, from whichever store holds it.
final readerDocProvider = Provider.family<AsyncValue<ReaderDoc?>, ReaderKey>((
  ref,
  key,
) {
  if (key.bookmarkId case final id?) return ref.watch(_bookmarkDocProvider(id));
  final articleId = key.articleId;
  if (articleId == null) return const AsyncValue.data(null);
  return ref
      .watch(articleProvider(articleId))
      .whenData(
        (headline) =>
            headline == null ? null : ReaderDoc.fromHeadline(headline),
      );
});

/// Runs extraction for one article.
///
/// Prefers what the feed already carried; otherwise fetches the page and runs
/// Mozilla's Readability heuristics on the device. Nothing is routed through
/// a server. A successful extraction is cached back into the article so the
/// second visit is instant and works offline.
final extractionProvider = FutureProvider.family<Extraction, int>((
  ref,
  id,
) async {
  final headline = await ref.watch(articleProvider(id).future);
  if (headline == null) {
    return const ThinExtraction('That article is no longer in the cache.');
  }

  final article = headline.article;
  final result = await ref
      .watch(extractionServiceProvider)
      .extract(
        link: article.link,
        feedHtml: article.fullContentHtml,
        imageUrl: article.imageUrl,
      );

  if (result is ExtractedArticle && article.fullContentHtml == null) {
    await ref
        .read(articleRepositoryProvider)
        .cacheExtractedHtml(article.id, result.html);
  }
  return result;
});

/// The body, from wherever this Reader's document came from.
///
/// A bookmark that carried its own body needs no network and no heuristics —
/// the point of saving the text was so that opening it later would not depend
/// on either.
final readerBodyProvider = FutureProvider.family<Extraction, ReaderKey>((
  ref,
  key,
) async {
  if (key.bookmarkId case final id?) {
    final doc = await ref.watch(_bookmarkDocProvider(id).future);
    if (doc == null) {
      return const ThinExtraction('That article is no longer saved.');
    }
    if (doc.savedHtml case final html? when html.isNotEmpty) {
      return ExtractedArticle(
        html: html,
        byline: doc.author,
        wordCount: FeedParser.plainText(html).split(RegExp(r'\s+')).length,
      );
    }
    // Saved before its text could be fetched, but its row is still cached:
    // extraction can still run, exactly as it would from Headlines.
    if (doc.articleId case final articleId?) {
      return await ref.watch(extractionProvider(articleId).future);
    }
    return const ThinExtraction(
      'This one was saved before its text could be fetched.',
    );
  }

  final articleId = key.articleId;
  if (articleId == null) {
    return const ThinExtraction('That article is no longer in the cache.');
  }
  return await ref.watch(extractionProvider(articleId).future);
});
