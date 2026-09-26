import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:headshorts/app/providers.dart';
import 'package:headshorts/app/settings_controller.dart';
import 'package:headshorts/core/tokens/accents.dart';
import 'package:headshorts/core/util/canonical_url.dart';
import 'package:headshorts/data/db/article_repository.dart';
import 'package:headshorts/data/db/tables.dart';
import 'package:headshorts/data/feed/google_news_search.dart';
import 'package:headshorts/data/sources/source_adapter.dart';
import 'package:headshorts/features/sources/sources_controller.dart';
import 'package:headshorts/features/today/headline_card.dart';

/// The presets the date chip offers, plus the pair of dates behind
/// [DateRangePreset.between].
enum DateRangePreset {
  // Not "Any time": there is no archive behind it. It is the whole of what
  // the last refreshes brought in, which is a corpus rather than a period,
  // and naming it as one is what stops it reading as a promise.
  anyTime('Everything cached'),
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

  /// What Search opens on. A week, not everything, because a week is about as
  /// deep as a cache search usefully reaches for a daily publisher — so the
  /// first thing the reader sees states the scope instead of implying there
  /// is none. See "Search looks through the cache" in CLAUDE.md.
  static const initial = SearchDateRange(DateRangePreset.week);

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

  /// No time constraint at all — every cached item is in range. Drives the
  /// copy and the widening offer, both of which are about the *constraint*.
  bool get isUnbounded => preset == DateRangePreset.anyTime;

  /// Untouched since Search opened. Drives the chip's active dress, which is
  /// about whether the reader has narrowed anything.
  bool get isInitial => preset == DateRangePreset.week;

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

  factory fromWeb(WebResult result) => SearchHit(
    view: ArticleView(
      sourceTitle: result.publisher,
      // A stable tone per publisher, the same way a pasted feed gets one.
      // Nothing here is subscribed, so there is no accent of the reader's.
      accent: SourceAccent.fromKey(result.publisher),
      title: result.title,
      publishedAt: result.publishedAt,
    ),
    link: result.link,
  );

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
    this.webHits = const [],
    this.fetchedLive = 0,
    this.truncated = false,
  });

  static const empty = SearchOutcome(hits: [], sourcesSearched: 0);

  final List<SearchHit> hits;

  /// Results from Google News, kept in their own list rather than mixed in.
  /// They are not the reader's sources and must never read as though they
  /// are — the screen gives them their own heading and their own note.
  final List<SearchHit> webHits;

  /// Nothing was found anywhere, which is the only case the "nothing for…"
  /// screen should appear for.
  bool get isEmpty => hits.isEmpty && webHits.isEmpty;

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
  SearchDateRange build() => SearchDateRange.initial;

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
  // The count-free list: unseen counts change constantly and have nothing to
  // do with which sources a search covers.
  final entries = ref.watch(sourceEntriesProvider);
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
  // Read before the first await. `ref.watch` past an await registers a
  // dependency on a provider that may already have moved on, and Riverpod is
  // entitled to throw for it.
  final alsoWeb = ref.watch(settingsProvider.select((s) => s.searchTheWeb));
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
  //
  // Keyed on **having a cache**, not on being subscribed. The two are not the
  // same: a source added a minute ago, one the prune has emptied, or one
  // paused long enough to lose its items is subscribed and has nothing to
  // search, and skipping it would return nothing while looking like it
  // looked.
  final withCache = await ref.watch(articleRepositoryProvider).sourcesWithCache(
    {
      for (final entry in scope)
        if (entry.subscription case final row?) row.id,
    },
  );
  final needFetching = [
    for (final entry in scope)
      if (!withCache.contains(entry.subscription?.id ?? -1)) entry,
  ];

  // In parallel, and bounded: a search that has to fetch eight feeds must
  // not take eight feeds' worth of waiting one after another. The same
  // ceiling the refresh pipeline uses, for the same reason — a phone does
  // not go faster by opening more sockets.
  for (var i = 0; i < needFetching.length; i += searchFetchConcurrency) {
    final batch = needFetching.skip(i).take(searchFetchConcurrency);
    final fetched = await Future.wait([
      for (final entry in batch) _searchLive(ref, entry, query, range),
    ]);
    fetched.forEach(hits.addAll);
  }

  hits.sort((a, b) => b.view.publishedAt.compareTo(a.view.publishedAt));
  final capped = hits.length > searchResultLimit
      ? hits.sublist(0, searchResultLimit)
      : hits;

  return SearchOutcome(
    hits: capped,
    webHits: alsoWeb ? await _searchWeb(ref, query, range, capped) : const [],
    sourcesSearched: scope.length,
    fetchedLive: needFetching.length,
    truncated: hits.length > searchResultLimit,
  );
});

/// Asks Google News, when the reader has left that switched on.
///
/// Runs **after** their own sources and lands in its own list: the reader's
/// publishers are the answer, and this is the wider net under it. A story
/// their own feeds already carried is dropped rather than shown twice —
/// matched on the headline fingerprint, because a Google News link is a
/// redirect and shares no address with the publisher's own.
Future<List<SearchHit>> _searchWeb(
  Ref ref,
  String query,
  SearchDateRange range,
  List<SearchHit> own,
) async {
  final results = await ref
      .read(googleNewsSearchProvider)
      .search(query, since: range.start)
      .timeout(GoogleNewsSearch.timeout, onTimeout: () => const []);

  final seen = {for (final hit in own) titleFingerprint(hit.view.title)}
    ..remove('');
  final end = range.end;

  return [
    for (final result in results)
      if (end == null || result.publishedAt.isBefore(end))
        if (seen.add(titleFingerprint(result.title))) SearchHit.fromWeb(result),
  ];
}

/// How many feeds a search fetches at once, and how long it waits for each.
///
/// The ceiling matches the refresh pipeline's. The timeout is shorter: a
/// refresh happens behind the content and can afford fifteen seconds, while a
/// search has somebody watching a skeleton. A feed that has not answered in
/// eight seconds is one fewer source searched, said in the footer, rather
/// than a spinner that never ends.
const searchFetchConcurrency = 6;
const searchFetchTimeout = Duration(seconds: 8);

/// Feeds fetched for a search, kept for a few minutes.
///
/// A source in scope with nothing cached is fetched on every search, and a
/// reader refining a query runs several — so "The Guardian, added to the
/// scope but not followed" was re-downloaded on each one. The items are the
/// same either way; only the filtering changes. Deliberately in memory and
/// not in the database: a search must not quietly subscribe anybody to
/// anything.
final _fetchedFeedsProvider = Provider<Map<String, _FetchedFeed>>((ref) => {});

/// How long a fetched feed stands in for the real thing. Long enough to cover
/// refining a query, short enough that a search started later is current.
const _fetchedFeedTtl = Duration(minutes: 5);

class _FetchedFeed {
  new(this.articles) : at = DateTime.now();

  final List<ParsedArticle> articles;
  final DateTime at;

  bool get isFresh => DateTime.now().difference(at) < _fetchedFeedTtl;
}

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
    final cache = ref.read(_fetchedFeedsProvider);
    final remembered = cache[entry.feedUrl];

    final List<ParsedArticle> fetched;
    if (remembered != null && remembered.isFresh) {
      fetched = remembered.articles;
    } else {
      final result = await ref
          .read(adapterRegistryProvider)
          .resolve(SourceType.rss)
          .fetch(
            SourceRef(id: -1, feedUrl: entry.feedUrl, type: SourceType.rss),
          )
          .timeout(
            searchFetchTimeout,
            onTimeout: () => const FetchResult.failed('Took too long.'),
          );
      if (result is! FetchFresh) return const [];
      fetched = result.articles;
      cache[entry.feedUrl] = _FetchedFeed(fetched);
    }

    final start = range.start;
    final end = range.end;

    return [
      for (final item in fetched)
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
