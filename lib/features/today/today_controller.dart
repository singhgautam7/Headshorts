import 'package:flutter/foundation.dart' show immutable, listEquals, setEquals;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:headshorts/app/providers.dart';
import 'package:headshorts/app/refresh_controller.dart';
import 'package:headshorts/app/settings_controller.dart';
import 'package:headshorts/core/util/stream_throttle.dart';
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
const latestScope = 'All';

/// The categories the Filter sheet offers: All, then one per category that has
/// at least one enabled source. Nothing is hard-coded; they appear and
/// disappear as sources are added, removed, disabled or recategorised.
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

/// The language the briefing is narrowed to, or null for all of them.
///
/// Sits above Category in the Filter sheet and narrows the source chips
/// beneath it, exactly as Category already does. A view filter: a paused
/// language is not a thing, and nothing here changes a subscription.
class BriefingLanguage extends Notifier<String?> {
  @override
  String? build() => null;

  /// Records the chosen language.
  ///
  // A setter would read as assigning `state` from outside the notifier.
  // ignore: use_setters_to_change_properties
  void select(String? language) => state = language;
}

final briefingLanguageProvider = NotifierProvider<BriefingLanguage, String?>(
  BriefingLanguage.new,
);

/// The languages the reader's enabled sources are in. One entry means the
/// control hides itself — a filter with a single option is furniture.
final briefingLanguagesProvider = Provider<List<String>>((ref) {
  final sources = ref.watch(sourcesProvider).value ?? const [];
  final tags = sources.where((s) => s.enabled).map((s) => s.language).toSet();
  return [if (tags.contains('en')) 'en', ...tags..remove('en')];
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

  // A setter would read as assigning `state` from outside the notifier.
  // ignore: use_setters_to_change_properties
  void setMuted(Set<int> muted) => state = muted;
}

final mutedSourcesProvider = NotifierProvider<MutedSources, Set<int>>(
  MutedSources.new,
);

final sourcesProvider = StreamProvider<List<SourceRow>>(
  (ref) => ref.watch(sourceRepositoryProvider).watchAll(),
);

/// The sources the language filter is currently excluding.
///
/// Folded in with the reader's own muted set rather than adding a second
/// parameter to every query: to the briefing, "hidden by language" and
/// "hidden by the filter" are the same thing.
final offLanguageSourcesProvider = Provider<Set<int>>((ref) {
  final language = ref.watch(briefingLanguageProvider);
  if (language == null) return const {};
  final sources = ref.watch(sourcesProvider).value ?? const [];
  return {
    for (final source in sources)
      if (source.language != language) source.id,
  };
});

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

/// What the briefing is narrowed to: the category and the sources hidden by
/// the Filter or by language. Equal scopes are the same list.
@immutable
class BriefingScope {
  const new({required this.category, required this.muted});

  /// Null is Latest.
  final String? category;
  final Set<int> muted;

  @override
  bool operator ==(Object other) =>
      other is BriefingScope &&
      other.category == category &&
      setEquals(other.muted, muted);

  @override
  int get hashCode => Object.hash(category, Object.hashAllUnordered(muted));
}

/// The list Today is showing. A change here is a new list — the skeleton,
/// then results — where a page turn or a refresh is the same list growing.
final briefingScopeProvider = Provider<BriefingScope>((ref) {
  final category = ref.watch(activeCategoryProvider);
  return BriefingScope(
    category: category == latestScope ? null : category,
    muted: {
      ...ref.watch(mutedSourcesProvider),
      ...ref.watch(offLanguageSourcesProvider),
    },
  );
});

class TodayPagination extends Notifier<TodayPage> {
  @override
  TodayPage build() {
    // A new filter is a new list; start it at the top.
    ref.watch(briefingScopeProvider);
    return const TodayPage();
  }

  var _loading = false;

  /// Extends the window by one page. Idempotent while a page is in flight.
  Future<void> loadMore() async {
    if (_loading || state.atEnd) return;
    _loading = true;

    final scope = ref.read(briefingScopeProvider);
    final next = await ref
        .read(articleRepositoryProvider)
        .nextFloor(
          category: scope.category,
          mutedSourceIds: scope.muted,
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

/// Where the head of Today is held still, or null while it follows the cache.
///
/// New arrivals prepend to a live list and push everything below them down,
/// under a thumb that is mid-scroll. While the reader is scrolled the screen
/// holds the newest item in view here, and the list shows nothing newer; back
/// at the top, or on tapping "Latest stories", it lets go.
class TodayHold extends Notifier<ArticleCursor?> {
  @override
  ArticleCursor? build() {
    // A different filter is a different list, with nothing to hold.
    ref.watch(briefingScopeProvider);
    return null;
  }

  /// Holds at [newest], unless already holding.
  void hold(ArticleCursor newest) => state ??= newest;

  void release() => state = null;
}

final todayHeldProvider = NotifierProvider<TodayHold, ArticleCursor?>(
  TodayHold.new,
);

/// Whether anything newer than the held head is waiting. A yes or no — the
/// "Latest stories" chip appears on it, and there is no number.
final newerWaitingProvider = StreamProvider<bool>((ref) {
  final ceiling = ref.watch(todayHeldProvider);
  if (ceiling == null) return Stream.value(false);
  final scope = ref.watch(briefingScopeProvider);
  return ref
      .watch(articleRepositoryProvider)
      .watchNewerThan(
        ceiling,
        category: scope.category,
        mutedSourceIds: scope.muted,
      );
});

/// How often the briefing may re-emit while a refresh is writing to it.
const briefingThrottle = Duration(milliseconds: 400);

/// The briefing for the current scope: cached, chronological, deduped, finite
/// and paginated.
///
/// Paging and the held head change this provider's inputs, but not the list's
/// identity: screens keep showing the previous value while it reloads. Only a
/// different [briefingScopeProvider] is a new list.
final briefingProvider = StreamProvider<List<Headline>>((ref) {
  final scope = ref.watch(briefingScopeProvider);
  // The floor alone: `atEnd` flipping is not a reason to re-query.
  final floor = ref.watch(todayPaginationProvider.select((p) => p.floor));
  final ceiling = ref.watch(todayHeldProvider);
  final maxRun = ref.watch(
    settingsProvider.select((s) => s.maxConsecutivePerSource),
  );

  final items = ref
      .watch(articleRepositoryProvider)
      .watchBriefing(
        category: scope.category,
        mutedSourceIds: scope.muted,
        floor: floor,
        ceiling: ceiling,
      )
      .map((items) => capConsecutive(items, maxRun))
      .distinct(listEquals);
  // A refresh writes a hundred times in a few seconds; the list redraws at
  // most every [briefingThrottle], and not at all when nothing changed.
  return throttleLatest(items, briefingThrottle).distinct(listEquals);
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
