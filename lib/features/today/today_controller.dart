import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:headshorts/app/providers.dart';
import 'package:headshorts/app/refresh_controller.dart';
import 'package:headshorts/app/settings_controller.dart';
import 'package:headshorts/data/db/article_repository.dart';
import 'package:headshorts/data/db/database.dart';

/// Categories offered when the reader has not created any of their own. A
/// category is only ever a label on a source, so these are suggestions, not a
/// fixed taxonomy.
const defaultCategories = [
  'General',
  'India',
  'World',
  'Technology',
  'Business',
];

/// The label for the merged view. Not a category — a category tab filters
/// `sources.category`, this one is everything.
const latestScope = 'Latest';

/// The sub-tabs: Latest, then one tab per category that has at least one
/// enabled source. Nothing is hard-coded; tabs appear and disappear as sources
/// are added, removed, disabled or recategorised.
final categoriesProvider = StreamProvider<List<String>>(
  (ref) => ref
      .watch(sourceRepositoryProvider)
      .watchCategories()
      .map((categories) => [latestScope, ...categories]),
);

/// Which sub-tab is showing.
class SelectedCategory extends Notifier<String> {
  @override
  String build() => latestScope;

  /// Switches the visible sub-tab.
  ///
  // A setter here would read as assigning `state` from outside the notifier,
  // which is exactly what the encapsulation is for.
  // ignore: use_setters_to_change_properties
  void select(String category) => state = category;
}

final selectedCategoryProvider = NotifierProvider<SelectedCategory, String>(
  SelectedCategory.new,
);

/// The tab actually showing.
///
/// The reader's choice, unless it has gone. Categories appear and disappear
/// as sources are subscribed, paused and recategorised, and a selection left
/// pointing at a category nothing is filed under any more would filter the
/// briefing down to nothing and read as a bug. Everything downstream — the
/// query, the pagination, the tab strip — derives from this, so the tab set
/// and the list can never disagree.
final activeCategoryProvider = Provider<String>((ref) {
  final categories = ref.watch(categoriesProvider).value ?? const [latestScope];
  final selected = ref.watch(selectedCategoryProvider);
  return categories.contains(selected) ? selected : latestScope;
});

/// Sources hidden from the current view only — the "All sources" filter.
///
/// A lens on the briefing, not a subscription change: nothing here alters
/// what is fetched.
class MutedSources extends Notifier<Set<int>> {
  @override
  Set<int> build() => const {};

  void toggle(int sourceId, {required bool visible}) {
    final next = {...state};
    if (visible) {
      next.remove(sourceId);
    } else {
      next.add(sourceId);
    }
    state = next;
  }

  void showAll() => state = const {};
}

final mutedSourcesProvider = NotifierProvider<MutedSources, Set<int>>(
  MutedSources.new,
);

final sourcesProvider = StreamProvider<List<SourceRow>>(
  (ref) => ref.watch(sourceRepositoryProvider).watchAll(),
);

/// How much of Today is loaded.
///
/// Keyset paging: the window is bounded by the cursor of the last item on the
/// last page, never by an offset, so a refresh that prepends new items cannot
/// make the list skip or repeat one under the reader.
@immutable
class TodayPage {
  const new({this.floor, this.atEnd = false});

  /// The oldest item loaded. Null means only the first page is loaded.
  final ArticleCursor? floor;

  /// The cache is exhausted. The list is finite, and this is where it ends.
  final bool atEnd;
}

class TodayPagination extends Notifier<TodayPage> {
  @override
  TodayPage build() {
    // A new sub-tab is a new list; start it at the top.
    ref.watch(activeCategoryProvider);
    return const TodayPage();
  }

  var _loading = false;

  /// Extends the window by one page. Idempotent while a page is in flight.
  Future<void> loadMore() async {
    if (_loading || state.atEnd) return;
    _loading = true;

    final category = ref.read(activeCategoryProvider);
    final next = await ref
        .read(articleRepositoryProvider)
        .nextFloor(
          category: category == latestScope ? null : category,
          floor: state.floor,
        );

    if (next == null && state.floor == null) {
      // Nothing below a window that has not been opened yet. That is an empty
      // cache, not the end of a list — latching "at end" here is what stopped
      // Today ever paging again after a first run that arrived empty.
    } else if (next == null || next == state.floor) {
      state = TodayPage(floor: state.floor, atEnd: true);
    } else {
      state = TodayPage(floor: next);
    }
    _loading = false;
  }
}

final todayPaginationProvider = NotifierProvider<TodayPagination, TodayPage>(
  TodayPagination.new,
);

/// The briefing for the selected sub-tab: cached, chronological, deduped,
/// finite, and paginated.
final briefingProvider = StreamProvider<List<Headline>>((ref) {
  final category = ref.watch(activeCategoryProvider);
  final muted = ref.watch(mutedSourcesProvider);
  final page = ref.watch(todayPaginationProvider);
  final maxRun = ref.watch(
    settingsProvider.select((s) => s.maxConsecutivePerSource),
  );

  return ref
      .watch(articleRepositoryProvider)
      .watchBriefing(
        category: category == latestScope ? null : category,
        floor: page.floor,
      )
      .map(
        (items) => capConsecutive(
          items.where((h) => !muted.contains(h.source.id)).toList(),
          maxRun,
        ),
      );
});

/// True until a refresh has run to completion this session.
///
/// An empty cache during the very first fetch is not an empty briefing.
/// Today waits for this before it is willing to say "You're caught up" —
/// otherwise the first run reads as "there is no news" for as long as the
/// fetch takes.
final awaitingFirstFetchProvider = Provider<bool>(
  (ref) => !ref.watch(refreshProvider.select((p) => p.finished)),
);

/// True when every enabled source last failed to connect — the cue for the
/// "No connection" note above a cached briefing.
final offlineProvider = Provider<bool>((ref) {
  final sources = ref.watch(sourcesProvider).value ?? const [];
  final enabled = sources.where((s) => s.enabled).toList();
  if (enabled.isEmpty) return false;
  return enabled.every(
    (s) => (s.lastError ?? '').toLowerCase().contains('connection'),
  );
});
