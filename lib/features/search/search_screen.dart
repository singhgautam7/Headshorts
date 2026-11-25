import 'dart:async';

import 'package:flutter/material.dart' show Icons, InputDecoration, TextField;
import 'package:flutter/services.dart' show TextInputAction;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:headshorts/app/nav_visibility.dart';
import 'package:headshorts/app/settings_controller.dart';
import 'package:headshorts/core/motion/motion_level.dart';
import 'package:headshorts/core/theme/hs_theme.dart';
import 'package:headshorts/core/tokens/accents.dart';
import 'package:headshorts/core/tokens/dimensions.dart';
import 'package:headshorts/core/tokens/motion.dart';
import 'package:headshorts/core/tokens/typography.dart';
import 'package:headshorts/core/util/open_in_web.dart';
import 'package:headshorts/core/util/relative_time.dart';
import 'package:headshorts/core/widgets/app_header.dart';
import 'package:headshorts/core/widgets/caught_up.dart';
import 'package:headshorts/core/widgets/controls.dart';
import 'package:headshorts/core/widgets/glyphs.dart';
import 'package:headshorts/core/widgets/screen.dart';
import 'package:headshorts/features/search/cache_explainer.dart';
import 'package:headshorts/features/search/date_range_sheet.dart';
import 'package:headshorts/features/search/search_controller.dart';
import 'package:headshorts/features/today/headline_card.dart';

/// A chip's hit region adds half of (48 - 32) above and below its visual.
const _hitPad = (HsSize.tapTarget - HsSize.chipVisual) / 2;

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
  /// Held here so the header can mark focus on the pill's hairline.
  final _focus = FocusNode();

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(searchQueryProvider);
    final range = ref.watch(searchDateProvider);
    final scope = ref.watch(searchScopeEntriesProvider);
    final results = ref.watch(searchResultsProvider);

    // The title header scrolls away and the search bar itself becomes the
    // pill; the filters and the results scroll with the page.
    return HsScreen(
      title: 'Search',
      underHeader: true,
      scrollAway: true,
      child: CustomScrollView(
        slivers: [
          HeaderSearchBar.sliverGap(),
          HeaderSearchBar(
            focusNode: _focus,
            child: _SearchBar(
              focusNode: _focus,
              onChanged: ref.read(searchQueryProvider.notifier).set,
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: HsSpace.x5),
              child: Wrap(
                spacing: HsSpace.x2,
                runSpacing: HsChip.runSpacing(HsSpace.x2),
                children: [
                  _FilterChip(
                    label: range.chipLabel,
                    icon: Icons.calendar_today_outlined,
                    active: !range.isInitial,
                    onTap: () => showDateRangeSheet(context),
                    semanticLabel: 'Date range, ${range.chipLabel}',
                  ),
                ],
              ),
            ),
          ),
          if (query.trim().isEmpty)
            const _FadeIn(
              key: ValueKey('empty'),
              sliver: SliverToBoxAdapter(child: _EmptyState()),
            )
          else
            _resultsFor(
              results,
              query: query,
              scope: scope.length,
              range: range,
            ),
        ],
      ),
    );
  }
}

/// Which of the states the results area is in, as a sliver.
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
  if (results.hasError) {
    return _FadeIn(
      key: const ValueKey('failed'),
      sliver: SliverToBoxAdapter(
        child: _NoResults(
          query: query,
          scope: scope,
          range: range,
          failed: true,
        ),
      ),
    );
  }

  // Still working, including a reload, where the previous results must not
  // stand in for the new query's.
  final outcome = results.value;
  if (results.isLoading || outcome == null) {
    return const _FadeIn(
      key: ValueKey('loading'),
      sliver: SliverToBoxAdapter(child: _ResultsSkeleton()),
    );
  }
  if (outcome.isEmpty) {
    return _FadeIn(
      key: const ValueKey('none'),
      sliver: SliverToBoxAdapter(
        child: _NoResults(query: query, scope: scope, range: range),
      ),
    );
  }
  return _FadeIn(
    key: const ValueKey('results'),
    sliver: _Results(outcome: outcome, query: query),
  );
}

/// A sliver that fades in when it is first built. Keyed by the state it
/// shows, so each change of state (skeleton, results, nothing) arrives the
/// way the box cross-fade used to, now that the area is one scroll view.
class _FadeIn extends StatefulWidget {
  const new({required this.sliver, super.key});

  final Widget sliver;

  @override
  State<_FadeIn> createState() => _FadeInState();
}

class _FadeInState extends State<_FadeIn> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this);
  var _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final off = HsMotion.levelOf(context) == MotionLevel.off;
    _c.animateTo(
      1,
      duration: off ? HsMotion.fxInstant : HsMotion.fxDefault,
      curve: HsMotion.curveEffects,
    );
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      SliverFadeTransition(opacity: _c, sliver: widget.sliver);
}

/// The field, bare: the header draws its pill (fill, hairline, radius), and
/// the whole of it, not just the line of text, takes the tap. Its own widget
/// so the debounce and the clear button live with the text rather than in
/// the screen.
class _SearchBar extends StatefulWidget {
  const new({required this.focusNode, required this.onChanged});

  final FocusNode focusNode;
  final ValueChanged<String> onChanged;

  @override
  State<_SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends State<_SearchBar> {
  final _controller = TextEditingController();
  Timer? _debounce;

  /// Long enough that a search does not run on every keystroke, short enough
  /// that the results feel like they are following the typing.
  static const _debounceFor = Duration(milliseconds: 300);

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
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

    return SizedBox.expand(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.focusNode.requestFocus,
        child: Padding(
          padding: EdgeInsets.only(left: 18, right: hasText ? 4 : 18),
          child: Row(
            children: [
              HsGlyph.search(palette.textMuted),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: widget.focusNode,
                  onChanged: _onChanged,
                  onTapOutside: (_) => widget.focusNode.unfocus(),
                  textInputAction: TextInputAction.search,
                  cursorColor: palette.textPrimary,
                  style: HsType.buttonLarge.copyWith(
                    color: palette.textPrimary,
                  ),
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
                  kind: PressKind.iconButton,
                  morphCorners: false,
                  onTap: _clear,
                  semanticLabel: 'Clear search',
                  child: SizedBox(
                    width: HsSize.tapTarget,
                    height: HsSize.tapTarget,
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
        ),
      ),
    );
  }
}

/// The chip that opens the date sheet, in the shared chip dress: selected
/// while the range differs from its default.
class _FilterChip extends StatelessWidget {
  const new({
    required this.label,
    required this.active,
    required this.onTap,
    required this.semanticLabel,
    required this.icon,
  });

  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) => Semantics(
    label: semanticLabel,
    button: true,
    excludeSemantics: true,
    onTap: onTap,
    child: HsChip(label, icon: icon, selected: active, onTap: onTap),
  );
}

/// To the Sources tab, where what is searched is decided.
void _toSources(BuildContext context, WidgetRef ref) {
  ref.read(navVisibilityProvider.notifier).show();
  context.go('/sources');
}

/// Before the first search: which sources it covers, then two short notes.
class _EmptyState extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(searchScopeEntriesProvider);
    final web = ref.watch(settingsProvider.select((s) => s.searchTheWeb));

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        HsSpace.x5,
        HsSpace.x3,
        HsSpace.x5,
        HsSpace.navClearance,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (entries.isNotEmpty) ...[
            SectionLabel('In scope · ${entries.length}'),
            const SizedBox(height: HsSpace.x3 - _hitPad),
            Wrap(
              spacing: HsSpace.x2,
              runSpacing: HsChip.runSpacing(HsSpace.x2),
              children: [
                for (final entry in entries)
                  AccentScope(
                    key: ValueKey(entry.feedUrl),
                    accent: entry.accent,
                    child: HsChip(entry.title, accentDot: true),
                  ),
              ],
            ),
            const SizedBox(height: HsSpace.x4),
          ],
          _Note(
            points: [
              _Point(
                entries.isEmpty
                    ? 'No sources are on. Turn some on in '
                    : 'To search other sources, turn them on in ',
                link: 'Sources',
                onLink: () => _toSources(context, ref),
              ),
              // The one thing that leaves the device, said before it happens.
              if (web)
                const _Point(
                  'Google News and all its sources are searched too. Only '
                  'your search term is sent.',
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A quoted note, as Markdown draws one: a bar, a title, then its points,
/// numbered when there is more than one.
class _Note extends StatelessWidget {
  const new({required this.points});

  final List<_Point> points;

  @override
  Widget build(BuildContext context) {
    final palette = context.hs;
    return Container(
      padding: const EdgeInsetsDirectional.only(start: HsSpace.x3),
      decoration: BoxDecoration(
        border: BorderDirectional(
          start: BorderSide(color: palette.stroke, width: HsSize.accentBar),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Note',
            style: HsType.statTitle.copyWith(color: palette.textPrimary),
          ),
          for (final (i, point) in points.indexed)
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                if (points.length > 1) ...[
                  Text(
                    '${i + 1}.',
                    style: HsType.caughtUpBody.copyWith(
                      color: palette.textMuted,
                    ),
                  ),
                  const SizedBox(width: HsSpace.x2),
                ],
                Expanded(child: point),
              ],
            ),
        ],
      ),
    );
  }
}

/// One point of a [_Note]. With a [link] the whole point is the target.
class _Point extends StatelessWidget {
  const new(this.text, {this.link, this.onLink});

  final String text;
  final String? link;
  final VoidCallback? onLink;

  @override
  Widget build(BuildContext context) {
    final palette = context.hs;
    final style = HsType.caughtUpBody.copyWith(color: palette.textSecondary);
    final body = Padding(
      padding: EdgeInsets.symmetric(
        vertical: link == null ? HsSpace.x1 : HsSpace.x3,
      ),
      child: Text.rich(
        TextSpan(
          text: text,
          style: style,
          children: [
            if (link != null)
              TextSpan(
                text: '$link.',
                style: style.copyWith(
                  color: palette.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
      ),
    );
    if (onLink == null) return body;
    return Pressable(
      kind: PressKind.row,
      onTap: onLink,
      semanticLabel: '$text$link',
      child: ExcludeSemantics(child: body),
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

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(
        HsSpace.x5,
        18,
        HsSpace.x5,
        HsSpace.navClearance,
      ),
      sliver: SliverList.builder(
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
                      style: HsType.timestamp.copyWith(
                        color: palette.textMuted,
                      ),
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
      ),
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
    return Pressable(
      kind: PressKind.chip,
      morphCorners: false,
      onTap: () => showCacheExplainer(context),
      semanticLabel: 'See why your sources found nothing',
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: HsSize.tapTarget),
        child: Center(
          widthFactor: 1,
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
            '${SearchDateRange.shortDate(from)} to '
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
              '${outcome.fetchedLive} of those had nothing saved yet, so only '
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
  const new({
    required this.query,
    required this.scope,
    required this.range,
    this.failed = false,
  });

  final String query;
  final int scope;
  final SearchDateRange range;

  /// The search itself errored, as opposed to finding nothing.
  final bool failed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.hs;
    final web = ref.watch(settingsProvider.select((s) => s.searchTheWeb));

    if (failed) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(32, 56, 32, HsSpace.navClearance),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'The search did not finish',
              style: HsType.stepTitle.copyWith(
                fontSize: 20,
                color: palette.textPrimary,
              ),
            ),
            const SizedBox(height: HsSpace.x3),
            Text(
              'Something went wrong while looking through your sources. '
              'Nothing was changed.',
              style: HsType.caughtUpBody.copyWith(color: palette.textSecondary),
            ),
            const SizedBox(height: 14),
            HsButton(
              'Try again',
              onPressed: () => ref.invalidate(searchResultsProvider),
              kind: HsButtonKind.secondary,
              height: HsSize.buttonSmall,
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 56, 32, HsSpace.navClearance),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
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
                ? 'No sources are on, so there was nothing to look through.'
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
              onPressed: () => ref
                  .read(searchDateProvider.notifier)
                  .set(SearchDateRange.any),
              kind: HsButtonKind.secondary,
              height: HsSize.buttonSmall,
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
              height: HsSize.buttonSmall,
            ),
            const SizedBox(height: 10),
          ],
          HsButton(
            'Go to Sources',
            onPressed: () => _toSources(context, ref),
            kind: HsButtonKind.secondary,
            height: HsSize.buttonSmall,
          ),
        ],
      ),
    );
  }
}

class _ResultsSkeleton extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.fromLTRB(
      HsSpace.x5,
      HsSpace.x5,
      HsSpace.x5,
      HsSpace.navClearance,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HeadlineSkeleton(),
        SizedBox(height: 30),
        HeadlineSkeleton(widths: [0.64, 0.4], withThumbnail: true),
        SizedBox(height: 30),
        HeadlineSkeleton(widths: [0.86, 0.46]),
      ],
    ),
  );
}
