import 'dart:async';

import 'package:flutter/material.dart' show InputDecoration, TextField;
import 'package:flutter/services.dart' show TextInputAction;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:headshorts/app/settings_controller.dart';
import 'package:headshorts/core/theme/hs_theme.dart';
import 'package:headshorts/core/tokens/accents.dart';
import 'package:headshorts/core/tokens/dimensions.dart';
import 'package:headshorts/core/tokens/typography.dart';
import 'package:headshorts/core/util/open_in_web.dart';
import 'package:headshorts/core/util/relative_time.dart';
import 'package:headshorts/core/widgets/caught_up.dart';
import 'package:headshorts/core/widgets/controls.dart';
import 'package:headshorts/core/widgets/glyphs.dart';
import 'package:headshorts/core/widgets/screen.dart';
import 'package:headshorts/features/search/cache_explainer.dart';
import 'package:headshorts/features/search/date_range_sheet.dart';
import 'package:headshorts/features/search/search_controller.dart';
import 'package:headshorts/features/search/search_scope_sheet.dart';
import 'package:headshorts/features/today/headline_card.dart';

/// Search — the sources you choose, in date order, and then it stops.
///
/// Finite like every other list here, and **not ranked**: results come back
/// newest first, under day headings, with the count stated once. There are no
/// recent searches, no trending terms and no suggestions — the field is
/// empty because nothing has been asked yet, not because something is missing.
class SearchScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  @override
  Widget build(BuildContext context) {
    final query = ref.watch(searchQueryProvider);
    final range = ref.watch(searchDateProvider);
    final scope = ref.watch(searchScopeEntriesProvider);
    final results = ref.watch(searchResultsProvider);

    return HsScreen(
      title: 'Search',
      titlePadding: const EdgeInsets.fromLTRB(HsSpace.x5, 6, HsSpace.x5, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SearchBar(
                  onChanged: ref.read(searchQueryProvider.notifier).set,
                ),
                const SizedBox(height: HsSpace.x2 + 2),
                Row(
                  children: [
                    _FilterChip(
                      label: range.chipLabel,
                      active: !range.isInitial,
                      onTap: () => showDateRangeSheet(context),
                      semanticLabel: 'Date range, ${range.chipLabel}',
                    ),
                    const SizedBox(width: HsSpace.x2),
                    _FilterChip(
                      label:
                          '${scope.length} '
                          '${scope.length == 1 ? 'source' : 'sources'}',
                      active: ref.watch(searchScopeProvider) != null,
                      onTap: () => showSearchScopeSheet(context),
                      semanticLabel: 'Sources in scope, ${scope.length}',
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: query.trim().isEmpty
                ? const _EmptyState()
                : _resultsFor(
                    results,
                    query: query,
                    scope: scope.length,
                    range: range,
                  ),
          ),
        ],
      ),
    );
  }
}

/// Which of the three states the results area is in.
///
/// Asked directly rather than through `AsyncValue.when`, because an errored
/// future does not leave the loading state in this version of Riverpod: it
/// stays `isLoading` and merely *carries* the error, so `when`'s `error`
/// branch never runs and a failed search would show its skeleton for ever.
/// `skipError` does not change that either — both were checked.
Widget _resultsFor(
  AsyncValue<SearchOutcome> results, {
  required String query,
  required int scope,
  required SearchDateRange range,
}) {
  final nothing = _NoResults(query: query, scope: scope, range: range);
  if (results.hasError) return nothing;

  // Still working — including a reload, where the previous results must not
  // stand in for the new query's.
  final outcome = results.value;
  if (results.isLoading || outcome == null) return const _ResultsSkeleton();

  return outcome.isEmpty ? nothing : _Results(outcome: outcome, query: query);
}

/// The field. Its own widget so the debounce and the clear button live with
/// the text rather than in the screen.
class _SearchBar extends StatefulWidget {
  const new({required this.onChanged});

  final ValueChanged<String> onChanged;

  @override
  State<_SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends State<_SearchBar> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    // The focused ring is part of the field's dress, so the field has to hear
    // about focus rather than waiting for the next keystroke to notice.
    _focus.addListener(() {
      if (mounted) setState(() {});
    });
  }

  /// Long enough that a search does not run on every keystroke, short enough
  /// that the results feel like they are following the typing.
  static const _debounceFor = Duration(milliseconds: 300);

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(_debounceFor, () => widget.onChanged(value));
  }

  void _clear() {
    _controller.clear();
    _debounce?.cancel();
    setState(() {});
    widget.onChanged('');
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.hs;
    final hasText = _controller.text.isNotEmpty;
    final focused = _focus.hasFocus;

    return Container(
      height: 48,
      padding: EdgeInsets.only(left: 14, right: hasText ? 4 : 14),
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border.all(
          color: focused ? palette.textPrimary : palette.stroke,
          width: focused ? 1.5 : 1,
        ),
        borderRadius: const BorderRadius.all(Radius.circular(14)),
      ),
      child: Row(
        children: [
          HsGlyph.search(palette.textMuted),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focus,
              onChanged: _onChanged,
              onTapOutside: (_) => _focus.unfocus(),
              textInputAction: TextInputAction.search,
              cursorColor: palette.textPrimary,
              style: HsType.buttonLarge.copyWith(color: palette.textPrimary),
              decoration: InputDecoration.collapsed(
                hintText: 'Search your sources',
                hintStyle: HsType.buttonLarge.copyWith(
                  color: palette.textMuted,
                ),
              ),
            ),
          ),
          if (hasText)
            Pressable(
              onTap: _clear,
              semanticLabel: 'Clear',
              child: SizedBox(
                width: 40,
                height: 40,
                child: Center(
                  child: Text(
                    '×',
                    style: HsType.buttonLarge.copyWith(
                      color: palette.textMuted,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A chip that opens a sheet. 34 visual, 44 target.
class _FilterChip extends StatelessWidget {
  const new({
    required this.label,
    required this.active,
    required this.onTap,
    required this.semanticLabel,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final palette = context.hs;
    return Pressable(
      onTap: onTap,
      semanticLabel: semanticLabel,
      child: SizedBox(
        height: HsSize.navItem,
        child: Center(
          child: Container(
            height: 34,
            padding: const EdgeInsets.symmetric(horizontal: HsSpace.x3),
            decoration: BoxDecoration(
              color: active ? palette.surfaceVariant : null,
              border: Border.all(color: palette.stroke),
              borderRadius: HsRadius.pillBorder,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: HsType.chipSelected.copyWith(
                    fontSize: 12,
                    color: active ? palette.textPrimary : palette.textSecondary,
                  ),
                ),
                const SizedBox(width: HsSpace.x2),
                HsGlyph.chevron(
                  active ? palette.textPrimary : palette.textSecondary,
                  direction: AxisDirection.down,
                  size: 6,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Before the first search: what the scope is, shown rather than described,
/// so the first result is never a surprise.
class _EmptyState extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.hs;
    final entries = ref.watch(searchScopeEntriesProvider);
    final web = ref.watch(settingsProvider.select((s) => s.searchTheWeb));

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        HsSpace.x5,
        40,
        HsSpace.x5,
        HsSpace.navClearance,
      ),
      children: [
        Text(
          'Search looks through the sources you choose',
          style: HsType.stepTitle.copyWith(
            fontSize: 20,
            color: palette.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          entries.isEmpty
              ? 'Nothing is in scope yet. Add a source to search, or switch '
                    'one on in Sources.'
              : 'By default that is the ${entries.length} you follow and have '
                    'switched on. Add any source from the catalog to widen a '
                    'search; it will not be followed.',
          style: HsType.caughtUpBody.copyWith(color: palette.textSecondary),
        ),
        if (web) ...[
          const SizedBox(height: 12),
          Text(
            'Your sources carry only what their feeds still list, so Google '
            'News is searched as well and its results are grouped on their '
            'own. Your search term is sent to Google; nothing else is, and '
            'those results open in your browser.',
            style: HsType.note.copyWith(color: palette.textMuted),
          ),
        ],
        if (entries.isNotEmpty) ...[
          const SizedBox(height: 22),
          SectionLabel('In scope · ${entries.length}'),
          const SizedBox(height: HsSpace.x3),
          Wrap(
            spacing: HsSpace.x2,
            runSpacing: HsSpace.x2,
            children: [
              for (final entry in entries)
                AccentScope(
                  accent: entry.accent,
                  child: HsChip(entry.title, accentDot: true),
                ),
            ],
          ),
        ],
        const SizedBox(height: 22),
        Align(
          alignment: Alignment.centerLeft,
          child: HsButton(
            'Change sources',
            onPressed: () => showSearchScopeSheet(context),
            kind: HsButtonKind.secondary,
            height: HsSize.buttonCompact,
          ),
        ),
      ],
    );
  }
}

/// The results, under day headings, ending in a plain count.
class _Results extends ConsumerWidget {
  const new({required this.outcome, required this.query});

  final SearchOutcome outcome;
  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.hs;
    final size = ref.watch(settingsProvider.select((s) => s.listSize));
    final linkMode = ref.watch(settingsProvider.select((s) => s.linkOpenMode));
    final hits = outcome.hits;

    // Headings and rows flattened into one lazy list, as the Sources screen
    // does: two hundred results must not build two hundred deep.
    final rows = <Object>[];
    String? lastDay;
    for (final hit in hits) {
      final day = dayHeading(hit.view.publishedAt);
      if (day != lastDay) {
        rows.add(day);
        lastDay = day;
      }
      rows.add(hit);
    }

    // Google News last and under its own heading, never mixed into the day
    // groups above: these are not the reader's publishers.
    if (outcome.webHits.isNotEmpty) {
      rows
        ..add(_WebHeading(tight: hits.isEmpty))
        ..addAll(outcome.webHits);
    }

    final all = [...hits, ...outcome.webHits];
    final oldest = all
        .map((h) => h.view.publishedAt)
        .reduce((a, b) => a.isBefore(b) ? a : b);
    final newest = all
        .map((h) => h.view.publishedAt)
        .reduce((a, b) => a.isAfter(b) ? a : b);

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
        HsSpace.x5,
        18,
        HsSpace.x5,
        HsSpace.navClearance,
      ),
      itemCount: rows.length + 2,
      itemBuilder: (context, index) {
        if (index == 0) {
          final count = hits.length + outcome.webHits.length;
          return Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: Semantics(
              liveRegion: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$count ${count == 1 ? 'result' : 'results'} · '
                    'newest first',
                    style: HsType.timestamp.copyWith(color: palette.textMuted),
                  ),
                  // Everything below is from the web. Said here rather than
                  // left as a gap, so the heading further down is not the
                  // first hint that the reader's own sources came up empty.
                  if (hits.isEmpty) ...[
                    const SizedBox(height: 10),
                    // A Wrap rather than a Row: at a large font size, or with
                    // a three-digit source count, the link drops to its own
                    // line instead of overflowing the sentence.
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: HsSpace.x2,
                      children: [
                        Text(
                          'Nothing from your ${outcome.sourcesSearched} '
                          '${outcome.sourcesSearched == 1 ? 'source' : 'sources'}.',
                          style: HsType.caughtUpBody.copyWith(
                            color: palette.textSecondary,
                          ),
                        ),
                        const _SeeWhy(),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          );
        }
        if (index == rows.length + 1) {
          return _EndOfResults(outcome: outcome, from: oldest, to: newest);
        }

        final row = rows[index - 1];
        if (row is _WebHeading) return row;
        if (row is String) {
          return Padding(
            padding: EdgeInsets.only(
              top: index == 1 ? 0 : HsSpace.x4,
              bottom: HsSpace.x3,
            ),
            child: Semantics(header: true, child: SectionLabel(row)),
          );
        }

        final hit = row as SearchHit;
        final id = hit.articleId;
        return Padding(
          padding: EdgeInsets.only(bottom: listGapFor(size)),
          child: HeadlineCard(
            hit.view,
            size: size,
            highlight: query.trim(),
            // A cached item has a row to open; one fetched for this search
            // or found on the web does not, so it goes to the publisher —
            // through the reader's own "Open links" choice, as every other
            // hand-off in the app does. Passing nothing here forced a Custom
            // Tab on somebody who had asked for their own browser.
            onTap: () => id == null
                ? unawaited(openInWeb(hit.link, mode: linkMode))
                : context.push('/reader/$id'),
          ),
        );
      },
    );
  }
}

/// Where the reader's own sources stop and the wider net begins.
///
/// Its own heading, its own words, and the one place in the app that says
/// something left the device. Not a warning and not an apology — a label, so
/// nobody has to wonder where a result came from.
class _WebHeading extends StatelessWidget {
  const new({this.tight = false});

  /// Straight after the count, with no results of the reader's above it. The
  /// divider is there to separate two groups; with only one group it is just
  /// a gap.
  final bool tight;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(top: tight ? 0 : HsSpace.x6, bottom: HsSpace.x3),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!tight) ...[const HsDivider(), const SizedBox(height: HsSpace.x4)],
        Semantics(header: true, child: const SectionLabel('From Google News')),
      ],
    ),
  );
}

/// "See why?", beside the line saying the reader's own sources found nothing.
///
/// The same mastheads appear in the Google group below, which reads as a
/// fault rather than an explanation. This is where the question gets asked,
/// so it is where the answer is offered.
///
/// Underlined rather than a button: it is a footnote on the sentence beside
/// it, not a third action competing with the two real ones further down. The
/// padding is what carries it to a 44dp target — the text alone is 16.
class _SeeWhy extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final palette = context.hs;
    return GestureDetector(
      onTap: () => showCacheExplainer(context),
      child: Semantics(
        button: true,
        label: 'See why your sources found nothing',
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 13),
          child: Text(
            'See why?',
            style: HsType.caughtUpBody.copyWith(
              color: palette.textSecondary,
              decoration: TextDecoration.underline,
              decorationColor: palette.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}

/// The plain count that ends the list. Never a "load more".
class _EndOfResults extends StatelessWidget {
  const new({required this.outcome, required this.from, required this.to});

  final SearchOutcome outcome;
  final DateTime from;
  final DateTime to;

  @override
  Widget build(BuildContext context) {
    final palette = context.hs;
    // Everything the reader was shown, the web group included — the line at
    // the top counts the same way, and two different totals on one screen
    // read as a bug.
    final count = outcome.hits.length + outcome.webHits.length;

    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        children: [
          const HsDivider(),
          const SizedBox(height: 14),
          Text(
            outcome.truncated
                ? 'The first $count'
                : 'That is all ${count == 1 ? 'one' : count}',
            style: HsType.buttonSmall.copyWith(color: palette.textPrimary),
          ),
          const SizedBox(height: HsSpace.x2),
          Text(
            'From ${outcome.sourcesSearched} '
            '${outcome.sourcesSearched == 1 ? 'source' : 'sources'}'
            '${outcome.webHits.isEmpty ? '' : ' and Google News'}, '
            '${SearchDateRange.shortDate(from)} – '
            '${SearchDateRange.shortDate(to)}',
            textAlign: TextAlign.center,
            style: HsType.note.copyWith(color: palette.textMuted),
          ),
          if (outcome.fetchedLive > 0) ...[
            const SizedBox(height: HsSpace.x2),
            Text(
              // The honest caveat, stated where it matters rather than in a
              // help screen: a feed only carries its recent items, so a
              // source with nothing cached cannot be searched back very far.
              '${outcome.fetchedLive} of those are not followed, so only '
              'what their feed carries right now was searched.',
              textAlign: TextAlign.center,
              style: HsType.note.copyWith(color: palette.textMuted),
            ),
          ],
        ],
      ),
    );
  }
}

/// Nothing matched. Says what was searched, and offers the two levers the
/// reader already has. No spelling suggestions, no "people also searched".
class _NoResults extends ConsumerWidget {
  const new({required this.query, required this.scope, required this.range});

  final String query;
  final int scope;
  final SearchDateRange range;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.hs;
    final web = ref.watch(settingsProvider.select((s) => s.searchTheWeb));

    return ListView(
      padding: const EdgeInsets.fromLTRB(32, 56, 32, HsSpace.navClearance),
      children: [
        Text(
          'Nothing for “${query.trim()}”',
          style: HsType.stepTitle.copyWith(
            fontSize: 20,
            color: palette.textPrimary,
          ),
        ),
        const SizedBox(height: HsSpace.x3),
        Text(
          scope == 0
              ? 'No sources are in scope, so there was nothing to look '
                    'through.'
              : 'None of your $scope ${scope == 1 ? 'source' : 'sources'} '
                    'published a match'
                    '${range.isUnbounded ? '' : ' in the '
                              '${range.chipLabel.toLowerCase()}'}'
                    // Said plainly, so nobody wonders whether the wider net
                    // was cast: with it on, this really is the end of it.
                    '${web ? ', and Google News had nothing either.' : '. '
                              'A wider range or more sources may find it.'}',
          style: HsType.caughtUpBody.copyWith(color: palette.textSecondary),
        ),
        const SizedBox(height: 14),
        if (!range.isUnbounded) ...[
          HsButton(
            'Search everything cached',
            onPressed: () =>
                ref.read(searchDateProvider.notifier).set(SearchDateRange.any),
            kind: HsButtonKind.secondary,
            height: 46,
          ),
          const SizedBox(height: 10),
        ],
        // Offered where it is missed, rather than left to be found in More.
        if (!web) ...[
          HsButton(
            'Also search Google News',
            onPressed: () => ref
                .read(settingsProvider.notifier)
                .setSearchTheWeb(enabled: true),
            kind: HsButtonKind.secondary,
            height: 46,
          ),
          const SizedBox(height: 10),
        ],
        HsButton(
          'Add sources to this search',
          onPressed: () => showSearchScopeSheet(context),
          kind: HsButtonKind.secondary,
          height: 46,
        ),
      ],
    );
  }
}

class _ResultsSkeleton extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(
      HsSpace.x5,
      HsSpace.x5,
      HsSpace.x5,
      HsSpace.navClearance,
    ),
    children: const [
      HeadlineSkeleton(),
      SizedBox(height: 30),
      HeadlineSkeleton(widths: [0.64, 0.4], withThumbnail: true),
      SizedBox(height: 30),
      HeadlineSkeleton(widths: [0.86, 0.46]),
    ],
  );
}
