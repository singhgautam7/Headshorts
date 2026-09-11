import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:headshorts/data/db/tables.dart';

part 'source_adapter.freezed.dart';

/// One item as a source handed it to us, before it becomes a database row.
@freezed
abstract class ParsedArticle with _$ParsedArticle {
  const factory({
    required String guid,
    required String title,
    required String link,
    required DateTime publishedAt,
    String? summary,
    String? contentSnippet,
    String? fullContentHtml,
    String? author,
    String? imageUrl,
  }) = _ParsedArticle;
}

/// The minimum a fetch needs to know about a source. Deliberately not the
/// database row, so an adapter can be exercised without a database.
@freezed
abstract class SourceRef with _$SourceRef {
  const factory({
    required int id,
    required String feedUrl,
    required SourceType type,
    String? etag,
    String? lastModified,
  }) = _SourceRef;
}

/// The outcome of one conditional GET.
@freezed
sealed class FetchResult with _$FetchResult {
  /// The feed returned items — possibly an empty list, if it has none.
  const factory fresh({
    required List<ParsedArticle> articles,
    String? etag,
    String? lastModified,
  }) = FetchFresh;

  /// 304 — what we hold is still current. Costs almost nothing.
  const factory unchanged() = FetchUnchanged;

  /// The feed did not answer, or answered with something we cannot read.
  const factory failed(String message) = FetchFailed;
}

/// The single extension point for source kinds.
///
/// A JSON-Feed reader, a search-query source or a publisher API becomes a new
/// class implementing this interface plus one line in [SourceAdapterRegistry].
/// The fetch pipeline, the database and the UI do not change.
abstract interface class SourceAdapter {
  bool canHandle(SourceType type);

  Future<FetchResult> fetch(SourceRef ref);
}

/// The one place adapters are registered.
class SourceAdapterRegistry {
  new(this._adapters);

  final List<SourceAdapter> _adapters;

  SourceAdapter resolve(SourceType type) => _adapters.firstWhere(
    (a) => a.canHandle(type),
    orElse: () => throw StateError('No adapter registered for $type'),
  );
}
