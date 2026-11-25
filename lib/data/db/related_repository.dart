import 'package:drift/drift.dart' show QueryRow, Variable;
import 'package:flutter/foundation.dart' show compute;
import 'package:headshorts/data/db/database.dart';
import 'package:headshorts/features/reader/related/related_matcher.dart';

/// The most candidates one lookup reads. Newest first inside the window, so
/// a firehose cannot push the article's own day out.
const relatedCandidateLimit = 3000;

/// Finds other publishers' copies of a story, from the cache alone.
class RelatedRepository {
  const new(this._db);

  final HsDatabase _db;

  Future<List<RelatedStory>> related(int articleId) async {
    final input = await inputFor(articleId);
    if (input == null) return const [];
    final hits = await compute(relatedMatches, input);
    return [
      for (final c in hits)
        RelatedStory(
          articleId: c.id,
          title: c.title,
          sourceTitle: c.sourceTitle,
          accentDark: c.accentDark,
          accentLight: c.accentLight,
          publishedAt: DateTime.fromMillisecondsSinceEpoch(c.publishedAtMs),
        ),
    ];
  }

  /// The article plus the same-language, enabled-source headlines within the
  /// window. No bodies: id, title, a short summary and the keys.
  Future<RelatedInput?> inputFor(int articleId) async {
    final base = await _db
        .customSelect(
          'SELECT a.id, a.title, substr(a.summary, 1, 240) AS summary, '
          'a.source_id, a.canonical_url, a.title_key, a.published_at, '
          's.title AS st, s.accent_dark, s.accent_light, s.language '
          'FROM articles a JOIN sources s ON s.id = a.source_id '
          'WHERE a.id = ?',
          variables: [Variable(articleId)],
          readsFrom: {_db.articles, _db.sources},
        )
        .getSingleOrNull();
    if (base == null) return null;

    final article = _row(base);
    final from = (article.publishedAtMs - relatedWindow.inMilliseconds) ~/ 1000;
    final to = (article.publishedAtMs + relatedWindow.inMilliseconds) ~/ 1000;
    final rows = await _db
        .customSelect(
          'SELECT a.id, a.title, substr(a.summary, 1, 240) AS summary, '
          'a.source_id, a.canonical_url, a.title_key, a.published_at, '
          's.title AS st, s.accent_dark, s.accent_light '
          'FROM articles a JOIN sources s ON s.id = a.source_id '
          'WHERE s.enabled = 1 AND s.language = ? AND a.id != ? '
          'AND a.published_at BETWEEN ? AND ? '
          'ORDER BY a.published_at DESC LIMIT ?',
          variables: [
            Variable(base.read<String>('language')),
            Variable(articleId),
            Variable(from),
            Variable(to),
            const Variable<int>(relatedCandidateLimit),
          ],
          readsFrom: {_db.articles, _db.sources},
        )
        .get();
    return RelatedInput(
      article: article,
      candidates: rows.map<RelatedCandidate>(_row).toList(),
    );
  }

  static RelatedCandidate _row(QueryRow r) => RelatedCandidate(
    id: r.read<int>('id'),
    title: r.read<String>('title'),
    summary: r.readNullable<String>('summary') ?? '',
    sourceId: r.read<int>('source_id'),
    canonicalUrl: r.read<String>('canonical_url'),
    titleKey: r.read<String>('title_key'),
    publishedAtMs: r.read<int>('published_at') * 1000,
    sourceTitle: r.read<String>('st'),
    accentDark: r.read<int>('accent_dark'),
    accentLight: r.read<int>('accent_light'),
  );
}
