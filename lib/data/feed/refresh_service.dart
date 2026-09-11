import 'package:headshorts/data/db/article_repository.dart';
import 'package:headshorts/data/db/database.dart';
import 'package:headshorts/data/db/source_repository.dart';
import 'package:headshorts/data/sources/source_adapter.dart';

/// Progress of one refresh. Onboarding draws this as one bar per feed; Today
/// draws it as a quiet "updating…". No spinner, no percentage.
class RefreshProgress {
  const new({
    required this.total,
    required this.done,
    required this.added,
    this.pending = const {},
  });

  static const idle = RefreshProgress(total: 0, done: 0, added: 0);

  final int total;
  final int done;

  /// How many genuinely new items arrived across the whole refresh.
  final int added;

  /// Source ids still in flight — the bars that have not filled yet.
  final Set<int> pending;

  bool get isRunning => total > 0 && done < total;
}

/// Fetch, parse, dedupe, store.
///
/// The network never touches the UI directly: it refreshes the database, and
/// the database is what every screen watches. Nothing here throws — a dead
/// feed is a state recorded against the source, not an error dialog.
class RefreshService {
  const new({
    required HsDatabase database,
    required this._sources,
    required this._articles,
    required this._registry,
  }) : _db = database;

  final HsDatabase _db;
  final SourceRepository _sources;
  final ArticleRepository _articles;
  final SourceAdapterRegistry _registry;

  /// Refreshes every enabled source concurrently, reporting progress as each
  /// one lands rather than in subscription order — so one slow feed does not
  /// hold up the bars for the rest.
  Stream<RefreshProgress> refreshAll() async* {
    final sources = (await _sources.enabled())
        .where((s) => !s.isAbandoned)
        .toList();
    if (sources.isEmpty) {
      yield RefreshProgress.idle;
      return;
    }

    final pending = {for (final s in sources) s.id};
    var done = 0;
    var added = 0;

    yield RefreshProgress(
      total: sources.length,
      done: 0,
      added: 0,
      pending: {...pending},
    );

    // Stream.fromFutures emits in completion order, which is exactly the
    // order the reader sees the bars fill in.
    final outcomes = Stream<_Outcome>.fromFutures(sources.map(_refreshOne));
    await for (final outcome in outcomes) {
      done++;
      added += outcome.added;
      pending.remove(outcome.sourceId);
      yield RefreshProgress(
        total: sources.length,
        done: done,
        added: added,
        pending: {...pending},
      );
    }

    await _db.pruneToRetention();
  }

  Future<_Outcome> _refreshOne(SourceRow source) async {
    final adapter = _registry.resolve(source.type);
    final result = await adapter.fetch(source.ref);

    switch (result) {
      case FetchFresh(:final articles, :final etag, :final lastModified):
        final added = await _articles.upsert(source.id, articles);
        await _sources.recordSuccess(
          source.id,
          etag: etag,
          lastModified: lastModified,
        );
        return _Outcome(source.id, added);
      case FetchUnchanged():
        await _sources.recordSuccess(
          source.id,
          etag: source.etag,
          lastModified: source.lastModified,
        );
        return _Outcome(source.id, 0);
      case FetchFailed(:final message):
        await _sources.recordFailure(source.id, message);
        return _Outcome(source.id, 0);
    }
  }
}

class _Outcome {
  const new(this.sourceId, this.added);
  final int sourceId;
  final int added;
}
