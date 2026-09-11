import 'dart:async';

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
    this.finished = false,
  });

  static const idle = RefreshProgress(total: 0, done: 0, added: 0);

  final int total;
  final int done;

  /// How many genuinely new items arrived across the whole refresh.
  final int added;

  /// Source ids still in flight — the bars that have not filled yet.
  final Set<int> pending;

  /// A refresh has run to completion at least once this session.
  ///
  /// Today reads this before it is willing to say "You're caught up": an
  /// empty cache during the very first fetch is not an empty briefing, and
  /// saying so is the difference between "nothing to read" and "not yet".
  final bool finished;

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

  /// How many feeds are in flight at once.
  ///
  /// Forty-five simultaneous requests is not faster than six on a phone — it
  /// exhausts the connection pool, times feeds out that would otherwise have
  /// answered, and turns the first briefing into a minute of nothing. Six
  /// keeps the pipe full and every feed inside its own timeout.
  static const concurrency = 6;

  /// The longest one feed may hold up the run.
  ///
  /// The HTTP client has its own connect and receive timeouts; this is the
  /// ceiling on the whole attempt, retry included, so a feed that stalls
  /// between bytes cannot keep the reader waiting.
  static const perFeedTimeout = Duration(seconds: 15);

  /// Refreshes every enabled source, at most [concurrency] at a time, and
  /// reports progress as each one lands rather than in subscription order —
  /// so one slow feed does not hold up the bars for the rest.
  Stream<RefreshProgress> refreshAll() async* {
    final sources = (await _sources.enabled())
        .where((s) => !s.isAbandoned)
        .toList();
    if (sources.isEmpty) {
      yield const RefreshProgress(total: 0, done: 0, added: 0, finished: true);
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

    await for (final outcome in _pooled(sources)) {
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
    yield RefreshProgress(
      total: sources.length,
      done: sources.length,
      added: added,
      finished: true,
    );
  }

  /// Runs [sources] through a fixed-width pool, emitting each outcome as it
  /// lands. Starting every fetch at once is what made the first run feel
  /// frozen; this keeps [concurrency] in flight and no more.
  Stream<_Outcome> _pooled(List<SourceRow> sources) {
    final controller = StreamController<_Outcome>();
    var next = 0;
    var running = 0;
    var closed = false;

    void pump() {
      if (closed) return;
      while (running < concurrency && next < sources.length) {
        final source = sources[next++];
        running++;
        unawaited(
          _refreshOne(source).then((outcome) {
            running--;
            if (!controller.isClosed) controller.add(outcome);
            pump();
          }),
        );
      }
      if (running == 0 && next >= sources.length) {
        closed = true;
        unawaited(controller.close());
      }
    }

    controller.onListen = pump;
    return controller.stream;
  }

  /// One feed, start to finish. **This never throws and never hangs.**
  ///
  /// A single feed that threw used to take the whole refresh down with it —
  /// the stream carried the error, the remaining feeds were dropped on the
  /// floor, and the reader arrived at an empty briefing that claimed to be
  /// caught up. Every failure is recorded against its own source instead.
  Future<_Outcome> _refreshOne(SourceRow source) async {
    try {
      final adapter = _registry.resolve(source.type);
      final result = await adapter
          .fetch(source.ref)
          .timeout(
            perFeedTimeout,
            onTimeout: () =>
                const FetchResult.failed('The feed took too long to answer.'),
          );

      switch (result) {
        case FetchFresh(:final articles, :final etag, :final lastModified):
          // Items first, validators second. Storing the ETag before the items
          // land means the next refresh answers 304 for content that was
          // never saved — the feed goes quiet and the reader never sees why.
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
    } on Object catch (_) {
      // Whatever it was — a malformed document a parser choked on, a write
      // that failed — it is this source's problem and nobody else's.
      await _sources.recordFailure(source.id, 'The feed could not be read.');
      return _Outcome(source.id, 0);
    }
  }
}

class _Outcome {
  const new(this.sourceId, this.added);
  final int sourceId;
  final int added;
}
