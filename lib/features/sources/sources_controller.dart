import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:headshorts/app/providers.dart';
import 'package:headshorts/app/refresh_controller.dart';
import 'package:headshorts/core/tokens/accents.dart';
import 'package:headshorts/data/db/database.dart';
import 'package:headshorts/data/db/source_repository.dart';
import 'package:headshorts/data/sources/source_catalog.dart';
import 'package:headshorts/features/sources/sources_screen.dart';
import 'package:headshorts/features/today/today_controller.dart';

/// One row on the Sources screen: a publisher, and whether the reader has it.
///
/// The screen shows the **same list the onboarding picker showed** — the whole
/// catalog — with the reader's own additions folded in. Subscribing is a
/// toggle rather than a separate screen, so there is one place to see what is
/// available and one place to change it.
@immutable
class SourceEntry {
  const new({
    required this.title,
    required this.feedUrl,
    required this.category,
    required this.accent,
    this.siteUrl,
    this.subscription,
    this.unseen = 0,
  });

  final String title;
  final String feedUrl;
  final String category;
  final SourceAccent accent;
  final String? siteUrl;

  /// The row in `sources`, when the reader has subscribed. Null means this is
  /// a catalog entry they have not taken up.
  final SourceRow? subscription;

  final int unseen;

  bool get isSubscribed => subscription != null;

  /// Whether it is currently feeding the briefing.
  bool get isOn => subscription?.enabled ?? false;

  /// The quiet line under the title. A state, never a score.
  String? get state {
    final row = subscription;
    if (row == null) return null;
    if (!row.enabled) return 'paused';
    if (row.failingSince != null) return 'not responding';
    return unseen > 0 ? '$unseen new' : 'caught up';
  }
}

/// What the reader has typed into the Sources search.
class SourcesQuery extends Notifier<String> {
  @override
  String build() => '';

  /// Records the current query.
  ///
  // A setter would read as assigning `state` from outside the notifier.
  // ignore: use_setters_to_change_properties
  void set(String query) => state = query;
}

final sourcesQueryProvider = NotifierProvider<SourcesQuery, String>(
  SourcesQuery.new,
);

/// The catalog and the reader's subscriptions, merged and grouped.
///
/// A source the reader added by URL is not in the catalog, so it is appended
/// to its category; a catalog source they subscribed to shows its live state
/// rather than appearing twice.
final manageableSourcesProvider = Provider<Map<String, List<SourceEntry>>>((
  ref,
) {
  final catalog = ref.watch(sourceCatalogProvider).value ?? SourceCatalog.empty;
  final subscribed = ref.watch(sourcesProvider).value ?? const [];
  final unseen = ref.watch(unseenBySourceProvider).value ?? const {};
  final query = ref.watch(sourcesQueryProvider);

  final byFeed = {for (final row in subscribed) row.feedUrl: row};
  final entries = <SourceEntry>[
    for (final source in catalog.sources)
      SourceEntry(
        title: source.title,
        feedUrl: source.feedUrl,
        category: byFeed[source.feedUrl]?.category ?? source.category,
        accent: byFeed[source.feedUrl]?.accent ?? source.accent,
        siteUrl: source.siteUrl,
        subscription: byFeed[source.feedUrl],
        unseen: unseen[byFeed[source.feedUrl]?.id] ?? 0,
      ),
    // Anything the reader added themselves, which the catalog knows
    // nothing about.
    for (final row in subscribed)
      if (!catalog.sources.any((s) => s.feedUrl == row.feedUrl))
        SourceEntry(
          title: row.title,
          feedUrl: row.feedUrl,
          category: row.category,
          accent: row.accent,
          siteUrl: row.siteUrl,
          subscription: row,
          unseen: unseen[row.id] ?? 0,
        ),
  ];

  final terms = query
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .where((t) => t.isNotEmpty)
      .toList();

  final grouped = <String, List<SourceEntry>>{};
  for (final entry in entries) {
    final haystack = '${entry.title} ${entry.category}'.toLowerCase();
    if (!terms.every(haystack.contains)) continue;
    grouped.putIfAbsent(entry.category, () => []).add(entry);
  }
  return grouped;
});

/// Subscribes, pauses or resumes a source, and refreshes when that changes
/// what the briefing should contain.
///
/// Turning a source off **pauses** it rather than unsubscribing: the
/// subscription and its cached items survive, so turning it back on is
/// instant. Unsubscribing is a deliberate, destructive action and lives on the
/// source's own screen.
Future<void> setSourceOn(
  WidgetRef ref,
  SourceEntry entry, {
  required bool on,
}) async {
  final repository = ref.read(sourceRepositoryProvider);
  final existing = entry.subscription;

  if (existing == null) {
    if (!on) return;
    await repository.add(
      title: entry.title,
      feedUrl: entry.feedUrl,
      siteUrl: entry.siteUrl,
      category: entry.category,
      accent: entry.accent,
    );
  } else {
    await repository.setEnabled(existing.id, enabled: on);
  }

  // Only a source that is now feeding the briefing needs fetching.
  if (on) await ref.read(refreshProvider.notifier).refresh();
}
