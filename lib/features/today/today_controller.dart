import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:headshorts/app/providers.dart';
import 'package:headshorts/data/db/article_repository.dart';
import 'package:headshorts/data/db/database.dart';

/// The category sub-tabs: "Top" plus whatever categories the reader's own
/// sources fall into. Nothing is hard-coded.
final categoriesProvider = StreamProvider<List<String>>(
  (ref) => ref
      .watch(sourceRepositoryProvider)
      .watchCategories()
      .map((categories) => ['Top', ...categories]),
);

/// Which sub-tab is showing.
class SelectedCategory extends Notifier<String> {
  @override
  String build() => 'Top';

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

/// The briefing for the selected sub-tab: cached, chronological, finite.
final briefingProvider = StreamProvider<List<Headline>>((ref) {
  final category = ref.watch(selectedCategoryProvider);
  final muted = ref.watch(mutedSourcesProvider);
  return ref
      .watch(articleRepositoryProvider)
      .watchBriefing(category: category == 'Top' ? null : category)
      .map(
        (items) => items.where((h) => !muted.contains(h.source.id)).toList(),
      );
});

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
