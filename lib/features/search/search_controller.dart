import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:headshorts/app/providers.dart';
import 'package:headshorts/data/db/article_repository.dart';
import 'package:headshorts/data/db/tables.dart';
import 'package:headshorts/data/sources/source_adapter.dart';
import 'package:headshorts/features/sources/sources_controller.dart';
import 'package:headshorts/features/today/headline_card.dart';

/// The presets the date chip offers, plus the pair of dates behind
/// [DateRangePreset.between].
enum DateRangePreset {
  anyTime('Any time'),
  day('Past 24 hours'),
  week('Past week'),
  month('Past month'),
  between('Between dates');

  new(this.label);

  final String label;
}

/// What the date chip is set to.
///
/// By publication date, never by when the item was fetched: a feed that
/// arrives late is still the day's news, and a reader searching "past week"
/// means the week the stories happened in.
@immutable
class SearchDateRange {
  const new(this.preset, {this.from, this.to});

  static const any = SearchDateRange(DateRangePreset.anyTime);

  final DateRangePreset preset;

  /// Only meaningful for [DateRangePreset.between]. A null [to] is "today".
  final DateTime? from;
  final DateTime? to;

  DateTime? get start => switch (preset) {
    DateRangePreset.anyTime => null,
    DateRangePreset.day => DateTime.now().subtract(const Duration(days: 1)),
    DateRangePreset.week => DateTime.now().subtract(const Duration(days: 7)),
    DateRangePreset.month => DateTime.now().subtract(const Duration(days: 30)),
    DateRangePreset.between => from,
  };

  DateTime? get end => preset == DateRangePreset.between && to != null
      // The whole of the chosen day, not the instant it began.
      ? DateTime(to!.year, to!.month, to!.day, 23, 59, 59)
      : null;

  bool get isDefault => preset == DateRangePreset.anyTime;

  /// What the chip says. "14 Sep – today" rather than a pair of full dates:
  /// the chip is a statement of scope, not a field.
  String get chipLabel {
    if (preset != DateRangePreset.between) return preset.label;
    final start = from;
    if (start == null) return DateRangePreset.between.label;
    final finish = to == null ? 'today' : shortDate(to!);
    return '${shortDate(start)} – $finish';
  }

  static String shortDate(DateTime when) =>
      '${when.day} ${_months[when.month - 1]}';

  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  @override
  bool operator ==(Object other) =>
      other is SearchDateRange &&
      other.preset == preset &&
      other.from == from &&
      other.to == to;

  @override
  int get hashCode => Object.hash(preset, from, to);
}

/// One result.
///
/// [articleId] is null when the item came from a feed fetched for this search
/// rather than out of the cache — there is no row to open, so the publisher's
/// own page is where it goes.
@immutable
class SearchHit {
  const new({required this.view, required this.link, this.articleId});

  final ArticleView view;
  final String link;
  final int? articleId;
}

/// What one search came back with, and what had to be said about it.
@immutable
class SearchOutcome {
  const new({
    required this.hits,
    required this.sourcesSearched,
    this.fetchedLive = 0,
    this.truncated = false,
  });

  static const empty = SearchOutcome(hits: [], sourcesSearched: 0);

  final List<SearchHit> hits;
  final int sourcesSearched;

  /// How many in-scope sources had to be fetched because nothing of theirs is
  /// cached. Those results reach back only as far as the feed does.
  final int fetchedLive;

  /// The result limit was reached. The list still ends; it just says so.
  final bool truncated;
}

/// What the reader typed. Debounced by the field itself.
class SearchQuery extends Notifier<String> {
  @override
  String build() => '';

  // A setter would read as assigning `state` from outside the notifier.
  // ignore: use_setters_to_change_properties
  void set(String query) => state = query;
}

final searchQueryProvider = NotifierProvider<SearchQuery, String>(
  SearchQuery.new,
);

class SearchDateFilter extends Notifier<SearchDateRange> {
  @override
  SearchDateRange build() => SearchDateRange.any;

  /// Records the chosen range.
  ///
  // A setter would read as assigning `state` from outside the notifier.
  // ignore: use_setters_to_change_properties
  void set(SearchDateRange range) => state = range;
}

final searchDateProvider = NotifierProvider<SearchDateFilter, SearchDateRange>(
  SearchDateFilter.new,
);

/// The sources this search looks through, by feed address.
///
/// Null means "whatever I follow and have switched on" — the default, and
/// deliberately not a snapshot of it: a source enabled tomorrow is in scope
/// tomorrow without the reader having to come back here and add it.
///
/// A lens, like Filter. Adding an unfollowed source searches it once; it does
/// not subscribe, fetch on a schedule, or appear in the briefing.
class SearchScope extends Notifier<Set<String>?> {
  @override
  Set<String>? build() => null;

  /// Records the chosen scope.
  ///
  // A setter would read as assigning `state` from outside the notifier.
  // ignore: use_setters_to_change_properties
  void set(Set<String> feedUrls) => state = feedUrls;

  /// Back to what the reader follows.
  void reset() => state = null;
}

final searchScopeProvider = NotifierProvider<SearchScope, Set<String>?>(
  SearchScope.new,
);

/// The scope resolved against what actually exists: the chosen feed addresses
/// as source entries, or the enabled subscriptions when nothing was chosen.
final searchScopeEntriesProvider = Provider<List<SourceEntry>>((ref) {
  final entries = ref.watch(allSourceEntriesProvider);
  final chosen = ref.watch(searchScopeProvider);
  if (chosen == null) {
    return [
      for (final e in entries)
        if (e.isOn) e,
    ];
  }
  return [
    for (final e in entries)
      if (chosen.contains(e.feedUrl)) e,
  ];
});

/// The results: the cache first, then whatever had to be fetched.
final searchResultsProvider = FutureProvider<SearchOutcome>((ref) async {
  final query = ref.watch(searchQueryProvider).trim();
  final range = ref.watch(searchDateProvider);
  final scope = ref.watch(searchScopeEntriesProvider);
  if (query.isEmpty || scope.isEmpty) return SearchOutcome.empty;

  // Cached first: an indexed lookup, offline, over everything ever fetched
  // from these sources — including the ones that are currently paused.
  final cached = await ref
      .watch(articleRepositoryProvider)
      .search(
        query: query,
        sourceIds: {
          for (final entry in scope)
            if (entry.subscription case final row?) row.id,
        },
        from: range.start,
        to: range.end,
      );

  final hits = <SearchHit>[
    for (final headline in cached)
      SearchHit(
        view: ArticleView.fromHeadline(headline),
        link: headline.article.link,
        articleId: headline.article.id,
      ),
  ];

  // Then the sources with nothing in the cache to look through. One fetch
  // each, nothing stored: this is a search, not a subscription.
  final unsubscribed = [
    for (final entry in scope)
      if (!entry.isSubscribed) entry,
  ];
  for (final entry in unsubscribed) {
    hits.addAll(await _searchLive(ref, entry, query, range));
  }

  hits.sort((a, b) => b.view.publishedAt.compareTo(a.view.publishedAt));
  final capped = hits.length > searchResultLimit
      ? hits.sublist(0, searchResultLimit)
      : hits;

  return SearchOutcome(
    hits: capped,
    sourcesSearched: scope.length,
    fetchedLive: unsubscribed.length,
    truncated: hits.length > searchResultLimit,
  );
});

/// Fetches one feed and filters it in memory.
///
/// Nothing is written to the database. That is the honest shape of it: the
/// reader asked to look inside a source, not to follow it, and a feed only
/// ever exposes its most recent items — so a date range reaches back exactly
/// as far as the publisher's current feed does, and no further. The screen
/// says so rather than implying an archive.
Future<List<SearchHit>> _searchLive(
  Ref ref,
  SourceEntry entry,
  String query,
  SearchDateRange range,
) async {
  final terms = query.toLowerCase().split(RegExp(r'\s+'))
    ..removeWhere((t) => t.isEmpty);

  try {
    final result = await ref
        .read(adapterRegistryProvider)
        .resolve(SourceType.rss)
        .fetch(SourceRef(id: -1, feedUrl: entry.feedUrl, type: SourceType.rss));
    if (result is! FetchFresh) return const [];

    final start = range.start;
    final end = range.end;

    return [
      for (final item in result.articles)
        if (_matches(item, terms) &&
            (start == null || item.publishedAt.isAfter(start)) &&
            (end == null || item.publishedAt.isBefore(end)))
          SearchHit(
            view: ArticleView(
              sourceTitle: entry.title,
              accent: entry.accent,
              title: item.title,
              publishedAt: item.publishedAt,
              summary: item.summary,
              imageUrl: item.imageUrl,
              author: item.author,
            ),
            link: item.link,
          ),
    ];
  } on Object catch (_) {
    // A source that will not answer is one fewer source searched, not a
    // failed search. The others already came back.
    return const [];
  }
}

bool _matches(ParsedArticle item, List<String> terms) {
  final haystack = [
    item.title,
    item.summary ?? '',
    item.contentSnippet ?? '',
  ].join(' ').toLowerCase();
  return terms.every(haystack.contains);
}
