import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:headshorts/app/providers.dart';
import 'package:headshorts/data/db/article_repository.dart';
import 'package:headshorts/data/readability/extraction_service.dart';

final articleProvider = StreamProvider.family<Headline?, int>(
  (ref, id) => ref.watch(articleRepositoryProvider).watchOne(id),
);

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
