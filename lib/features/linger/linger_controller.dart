import 'dart:async';

import 'package:flutter/foundation.dart' show immutable, setEquals;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:headshorts/app/providers.dart';
import 'package:headshorts/app/refresh_controller.dart';
import 'package:headshorts/data/db/article_repository.dart';
import 'package:headshorts/features/today/today_controller.dart';

/// What Linger is working through: a category, and which of that category's
/// sources are in play.
///
/// A **filter**, not source management. Nothing here subscribes, unsubscribes
/// or pauses anything — it narrows the queue the way Today's "All sources"
/// sheet narrows the list, and it lasts for the session.
@immutable
class LingerFilter {
  const new({this.category = latestScope, this.sourceIds});

  /// [latestScope] means every enabled source, minus the ones muted there.
  final String category;

  /// Null means every source in [category]. A set names the ones to keep.
  final Set<int>? sourceIds;

  bool get isDefault => category == latestScope && sourceIds == null;

  LingerFilter copyWith({
    String? category,
    Set<int>? sourceIds,
    bool clearSources = false,
  }) => LingerFilter(
    category: category ?? this.category,
    sourceIds: clearSources ? null : (sourceIds ?? this.sourceIds),
  );

  @override
  bool operator ==(Object other) =>
      other is LingerFilter &&
      other.category == category &&
      setEquals(other.sourceIds, sourceIds);

  @override
  int get hashCode => Object.hash(
    category,
    sourceIds == null ? null : Object.hashAllUnordered(sourceIds!),
  );
}

/// The filter Linger is working under. Held for the session, and the only
/// thing that decides what the queue is built from.
class LingerFilterController extends Notifier<LingerFilter> {
  @override
  LingerFilter build() => const LingerFilter();

  /// Applies a whole filter at once — the sheet's "Apply".
  // ignore: use_setters_to_change_properties
  void apply(LingerFilter filter) => state = filter;

  /// Back to Latest, every enabled source.
  void clear() => state = const LingerFilter();
}

final lingerFilterProvider =
    NotifierProvider<LingerFilterController, LingerFilter>(
      LingerFilterController.new,
    );

/// The queue and where the reader is in it.
@immutable
class LingerQueue {
  const new({this.items = const [], this.index = 0, this.loading = true});

  final List<Headline> items;

  /// The card in front of the reader. Held here so a refresh can keep it
  /// under them while items are inserted above.
  final int index;
  final bool loading;

  bool get isEmpty => items.isEmpty;
}

/// Builds and maintains Linger's finite queue.
///
/// The unseen-and-unread filter is applied **when the queue is built**, never
/// live. Marking the card in front of the reader as seen must not pull it out
/// from under them; it simply does not come back next time.
class LingerQueueController extends Notifier<LingerQueue> {
  @override
  LingerQueue build() {
    final filter = ref.watch(lingerFilterProvider);

    // A finished refresh brings new items in; merge them rather than
    // rebuilding, so the reader keeps their place.
    ref.listen(refreshProvider, (previous, next) {
      if (previous != null && previous.isRunning && !next.isRunning) {
        unawaited(_merge());
      }
    });

    unawaited(_load(filter));
    return const LingerQueue();
  }

  Future<List<Headline>> _fetch() {
    final filter = ref.read(lingerFilterProvider);
    return ref
        .read(articleRepositoryProvider)
        .buildLingerQueue(
          category: filter.category == latestScope ? null : filter.category,
          sourceIds: filter.sourceIds,
        );
  }

  Future<void> _load(LingerFilter filter) async {
    final items = await _fetch();
    // The reader changed the filter while this one was running; that load owns
    // the queue now.
    if (ref.read(lingerFilterProvider) != filter) return;
    state = LingerQueue(items: items, loading: false);
  }

  /// Folds newly arrived items into the queue at their chronological place,
  /// leaving everything the reader has already worked through alone.
  ///
  /// Items already in the queue stay, even if they are now seen — yanking the
  /// card someone is reading is exactly what the snapshot exists to prevent.
  Future<void> _merge() async {
    final incoming = await _fetch();
    final current = state;
    final known = {for (final item in current.items) item.article.id};

    final fresh = incoming
        .where((item) => !known.contains(item.article.id))
        .toList();
    if (fresh.isEmpty) return;

    final merged = [...current.items, ...fresh]
      ..sort((a, b) => b.article.publishedAt.compareTo(a.article.publishedAt));

    // Keep the reader on the same card, wherever it has moved to.
    final anchor =
        current.items.isEmpty || current.index >= current.items.length
        ? null
        : current.items[current.index].article.id;
    final index = anchor == null
        ? current.index
        : merged.indexWhere((item) => item.article.id == anchor);

    state = LingerQueue(
      items: merged,
      index: index < 0 ? current.index : index,
      loading: false,
    );
  }

  /// Records where the reader is, so a merge can keep them there.
  void moveTo(int index) {
    if (index == state.index) return;
    state = LingerQueue(
      items: state.items,
      index: index,
      loading: state.loading,
    );
  }

  /// Rebuilds from scratch — used when the reader comes back to a queue they
  /// have already worked through.
  Future<void> rebuild() => _load(ref.read(lingerFilterProvider));
}

final lingerQueueProvider =
    NotifierProvider<LingerQueueController, LingerQueue>(
      LingerQueueController.new,
    );
