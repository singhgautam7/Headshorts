import 'dart:async';

import 'package:flutter/material.dart' show Icons, Tooltip;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:headshorts/app/nav_visibility.dart';
import 'package:headshorts/app/providers.dart';
import 'package:headshorts/app/refresh_controller.dart';
import 'package:headshorts/app/settings_controller.dart';
import 'package:headshorts/core/motion/haptics.dart';
import 'package:headshorts/core/theme/hs_theme.dart';
import 'package:headshorts/core/tokens/dimensions.dart';
import 'package:headshorts/core/tokens/motion.dart';
import 'package:headshorts/core/tokens/typography.dart';
import 'package:headshorts/core/util/relative_time.dart';
import 'package:headshorts/core/widgets/app_header.dart';
import 'package:headshorts/core/widgets/caught_up.dart';
import 'package:headshorts/core/widgets/controls.dart';
import 'package:headshorts/core/widgets/glyphs.dart';
import 'package:headshorts/core/widgets/pull_to_refresh.dart';
import 'package:headshorts/core/widgets/screen.dart';
import 'package:headshorts/data/db/article_repository.dart';
import 'package:headshorts/data/prefs/settings.dart';
import 'package:headshorts/features/today/headline_card.dart';
import 'package:headshorts/features/today/source_filter_sheet.dart';
import 'package:headshorts/features/today/today_controller.dart';

/// Today — the browse view.
///
/// Opens instantly from cache and refreshes behind the content. The list is
/// chronological within the category the reader picked, nothing reorders
/// while they read, and it ends in "You're caught up".
class TodayScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends ConsumerState<TodayScreen> {
  @override
  void initState() {
    super.initState();
    // Refresh behind whatever is already on screen — never in front of it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(ref.read(refreshProvider.notifier).refreshIfDue());
    });
  }

  @override
  Widget build(BuildContext context) {
    // The list scrolls under the floating header; the offline note and the
    // filter row are its first rows and scroll away with it.
    return const HsScreen(
      title: 'Headlines',
      underHeader: true,
      child: _BriefingPage(),
    );
  }
}

/// The sources the current scope covers and how many of them show — what the
/// Filter label and the "caught up" line say. A value, so a refresh stamping
/// every source changes nothing here.
final _scopeCountsProvider = Provider<({int scoped, int visible})>((ref) {
  final category = ref.watch(activeCategoryProvider);
  final sources = ref.watch(sourcesProvider).value ?? const [];
  final muted = ref.watch(mutedSourcesProvider);
  final scoped = sources.where(
    (s) =>
        s.enabled &&
        (category == latestScope ? !s.mutedInLatest : s.category == category),
  );
  return (
    scoped: scoped.length,
    visible: scoped.where((s) => !muted.contains(s.id)).length,
  );
});

/// The briefing, or the skeleton that stands in for it.
///
/// The skeleton stands in only for **a different list**: first load, and an
/// Apply or Clear in Filter. A page turn, the held head letting go and a
/// refresh all reload the same list, and the list stays mounted through them
/// — swapping it for the skeleton unmounted the scroll view and threw the
/// reader's place away on every page.
class _BriefingPage extends ConsumerStatefulWidget {
  const new();

  @override
  ConsumerState<_BriefingPage> createState() => _BriefingPageState();
}

class _BriefingPageState extends ConsumerState<_BriefingPage> {
  /// The scope the list on screen belongs to.
  BriefingScope? _settled;

  @override
  Widget build(BuildContext context) {
    final offline = ref.watch(offlineProvider);
    final scope = ref.watch(briefingScopeProvider);
    final briefing = ref.watch(briefingProvider);
    final awaitingFirst = ref.watch(awaitingFirstFetchProvider);

    // `value` carries the previous list while a reload is in flight.
    final headlines = briefing.value;
    if (headlines != null && !briefing.isLoading) _settled = scope;
    final newList = briefing.isLoading && scope != _settled;

    if (headlines == null ||
        briefing.hasError ||
        newList ||
        // An empty cache mid-first-fetch is not an empty briefing.
        (headlines.isEmpty && awaitingFirst)) {
      return const _RefreshingSkeleton();
    }
    return _Briefing(headlines: headlines, offline: offline);
  }
}

/// Past this far down, new arrivals are held back rather than pushed in above
/// the reader.
const _holdBelow = 48.0;

/// Back at (nearly) the top, where new arrivals are welcome.
const _releaseAbove = 8.0;

class _Briefing extends ConsumerStatefulWidget {
  const new({required this.headlines, required this.offline});

  final List<Headline> headlines;
  final bool offline;

  @override
  ConsumerState<_Briefing> createState() => _BriefingState();
}

class _BriefingState extends ConsumerState<_Briefing> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  bool _onScroll(ScrollNotification notification) {
    final metrics = notification.metrics;
    // Today is the only place the pill gets out of the way. Linger keeps
    // its chrome, per the design board.
    if (metrics.axis != Axis.vertical) return false;
    // Load the next page as the reader nears the end of this one.
    if (metrics.hasContentDimensions &&
        metrics.extentAfter < metrics.viewportDimension) {
      unawaited(ref.read(todayPaginationProvider.notifier).loadMore());
    }
    // Hold the head still while the reader is down the page; let it go when
    // they are back at the top.
    final hold = ref.read(todayHeldProvider.notifier);
    if (metrics.pixels > _holdBelow && widget.headlines.isNotEmpty) {
      hold.hold(widget.headlines.first.cursor);
    } else if (metrics.pixels <= _releaseAbove) {
      hold.release();
    }
    ref
        .read(navVisibilityProvider.notifier)
        .onScroll(
          metrics,
          delta: notification is ScrollUpdateNotification
              ? notification.scrollDelta ?? 0
              : 0,
        );
    return false;
  }

  void _showLatest() {
    ref.read(todayHeldProvider.notifier).release();
    if (_scroll.hasClients) {
      _scroll.animateTo(0, duration: HsMotion.page, curve: HsMotion.pageCurve);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.hs;
    final headlines = widget.headlines;
    final offline = widget.offline;
    final size = ref.watch(settingsProvider.select((s) => s.listSize));
    final visible = ref.watch(_scopeCountsProvider.select((c) => c.visible));
    final latestWaiting =
        ref.watch(todayHeldProvider) != null &&
        (ref.watch(newerWaitingProvider).value ?? false);

    return Stack(
      children: [
        NotificationListener<ScrollNotification>(
          onNotification: _onScroll,
          child: PullToRefresh.builder(
            controller: _scroll,
            onRefresh: () => ref.read(refreshProvider.notifier).refresh(),
            padding: const EdgeInsets.only(
              left: HsSpace.x5,
              right: HsSpace.x5,
              bottom: HsSpace.navClearance,
            ),
            itemCount: headlines.isEmpty ? 2 : headlines.length + 3,
            // Rows are found by article id, so a refresh that prepends items
            // moves the elements already built instead of re-binding every
            // one of them (and its image) to a different story.
            findChildIndexCallback: (key) {
              if (key is! ValueKey<int>) return null;
              final at = headlines.indexWhere((h) => h.article.id == key.value);
              return at < 0 ? null : at + 1;
            },
            itemBuilder: (context, index) {
              if (index == 0) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    HeaderPage.gap(),
                    if (offline) const _OfflineNote(),
                    const _Header(),
                  ],
                );
              }
              if (headlines.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.only(top: 40),
                  child: _CaughtUp(count: 0, sources: visible),
                );
              }
              if (index <= headlines.length) {
                final i = index - 1;
                final headline = headlines[i];
                return Padding(
                  key: ValueKey(headline.article.id),
                  padding: EdgeInsets.only(bottom: listGapFor(size)),
                  child: HeadlineCard(
                    ArticleView.fromHeadline(headline),
                    size: size,
                    offline: offline,
                    // The optional lead-card wash: paper only, unread only,
                    // and only at the size that has room for it.
                    washed:
                        i == 0 &&
                        size == ListSize.large &&
                        !palette.isDark &&
                        !headline.isRead,
                    onTap: () => context.push('/reader/${headline.article.id}'),
                  ),
                );
              }
              if (index == headlines.length + 1) {
                return const Padding(
                  padding: EdgeInsets.only(bottom: 40),
                  child: HsDivider(),
                );
              }
              return _CaughtUp(count: headlines.length, sources: visible);
            },
          ),
        ),
        if (latestWaiting)
          PositionedDirectional(
            top: HeaderPage.insetOf(context) + HsSpace.x2,
            start: 0,
            end: 0,
            child: Center(child: _LatestChip(onTap: _showLatest)),
          ),
      ],
    );
  }
}

/// "Latest stories": scrolls to the top and lets the held arrivals in.
/// A word, not a count — there is nothing here to fall behind on.
class _LatestChip extends StatelessWidget {
  const new({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.hs;
    return Pressable(
      onTap: onTap,
      semanticLabel: 'Show latest stories',
      child: Container(
        height: HsSize.tapTarget,
        alignment: Alignment.center,
        child: Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: HsSpace.x4),
          decoration: BoxDecoration(
            color: palette.surfaceVariant,
            border: Border.all(color: palette.stroke),
            borderRadius: HsRadius.pillBorder,
          ),
          alignment: Alignment.center,
          child: Text(
            'Latest stories',
            style: HsType.chipSelected.copyWith(color: palette.textPrimary),
          ),
        ),
      ),
    );
  }
}

/// The line above the list: when it was last fetched, and the Filter and
/// list-size controls. Its own widget so a refresh ticking over rebuilds this
/// and not the list beneath it.
class _Header extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.hs;
    final offline = ref.watch(offlineProvider);
    final category = ref.watch(activeCategoryProvider);
    final muted = ref.watch(mutedSourcesProvider);
    final counts = ref.watch(_scopeCountsProvider);
    // Selected, not watched whole: a refresh emits one progress event per
    // feed, and Today has no business rebuilding forty-five times for a word
    // that only changes twice.
    final refreshing = ref.watch(refreshProvider.select((p) => p.isRunning));
    final lastUpdated = ref.watch(lastUpdatedProvider).value;
    final away = ref.watch(awayNoticeProvider);
    final newest = ref.watch(
      briefingProvider.select((b) => b.value?.firstOrNull?.article.publishedAt),
    );
    // A cache that is days old, being brought up to date.
    final stale =
        newest != null && DateTime.now().difference(newest) > awayThreshold;

    final isFiltered = category != latestScope || muted.isNotEmpty;
    final String filterLabel;
    if (!isFiltered) {
      filterLabel = 'Filter';
    } else if (category != latestScope && muted.isEmpty) {
      filterLabel = 'Filter · $category';
    } else if (category != latestScope && muted.isNotEmpty) {
      filterLabel = 'Filter · $category (${counts.visible})';
    } else {
      filterLabel = 'Filter · ${counts.visible} of ${counts.scoped}';
    }

    final style = HsType.timestamp.copyWith(color: palette.textMuted);
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                // When the list was last fetched — not how long it is.
                // The tab already says how many; a second count here
                // that disagreed with it (the loaded page versus the
                // whole category) read as a bug.
                child: Text(
                  offline
                      ? 'Offline · showing what is saved'
                      : refreshing
                      ? (stale ? 'Getting the latest stories…' : 'updating…')
                      : lastUpdated == null
                      ? 'Not fetched yet'
                      : updatedLabel(lastUpdated),
                  style: style,
                ),
              ),
              _ScopePill(
                label: filterLabel,
                isFiltered: isFiltered,
                onTap: () => showSourceFilterSheet(context),
              ),
              const SizedBox(width: HsSpace.x2),
              // Beside Filter, in Filter's dress: both narrow what this
              // list shows, so they belong to each other rather than to
              // the title. An anchored menu, not a sheet — the list has
              // to stay visible behind the choice.
              const _ListSizeButton(),
            ],
          ),
          if (away && !refreshing)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                'Showing the latest stories. Feeds only carry recent items.',
                style: style,
              ),
            ),
        ],
      ),
    );
  }
}

class _CaughtUp extends ConsumerStatefulWidget {
  const new({required this.count, required this.sources});

  final int count;
  final int sources;

  @override
  ConsumerState<_CaughtUp> createState() => _CaughtUpState();
}

class _CaughtUpState extends ConsumerState<_CaughtUp> {
  var _marked = false;

  @override
  Widget build(BuildContext context) {
    final oldest = ref.watch(briefingProvider).value?.lastOrNull;
    final atEnd = ref.watch(todayPaginationProvider.select((p) => p.atEnd));

    if (widget.count > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (!atEnd) {
          // The row sits at the end of what is loaded, which is not the end
          // of the cache until a page turn says so. Ask, and mark the day
          // only once it has.
          unawaited(ref.read(todayPaginationProvider.notifier).loadMore());
        } else if (!_marked) {
          _marked = true;
          HsHaptics.confirm();
          unawaited(ref.read(statsRepositoryProvider).markCaughtUpToday());
        }
      });
    }

    return CaughtUp(
      detail: widget.count == 0
          ? 'Nothing has arrived from your sources yet. Pull down to check.'
          : 'That is everything from your '
                '${widget.sources} ${widget.sources == 1 ? 'source' : 'sources'}'
                '${oldest == null ? '' : ' since '
                          '${clockTime(oldest.article.publishedAt)}'}. '
                'Nothing more will load here.',
      actionLabel: 'Check for new',
      onAction: () => ref.read(refreshProvider.notifier).refresh(),
    );
  }
}

/// The list-size control, beside Filter.
///
/// Icon only, so it carries its name on a long press rather than in a label
/// the row has no room for. 32 visual to match the chip it sits next to, in
/// a 44 target.
class _ListSizeButton extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.hs;
    final size = ref.watch(settingsProvider.select((s) => s.listSize));

    return Tooltip(
      message: 'Change view',
      child: Builder(
        builder: (anchorContext) => Pressable(
          onTap: () async {
            final picked = await showHsMenu<ListSize>(
              context: context,
              anchorContext: anchorContext,
              minWidth: 260,
              entries: [
                for (final option in ListSize.values)
                  HsMenuEntry(
                    value: option,
                    label: option.label,
                    sub: option.description,
                    icon: switch (option) {
                      ListSize.large => Icons.view_agenda_outlined,
                      ListSize.medium => Icons.view_list_outlined,
                      ListSize.small => Icons.reorder_rounded,
                    },
                    selected: option == size,
                  ),
              ],
            );
            if (picked != null) {
              await ref.read(settingsProvider.notifier).setListSize(picked);
            }
          },
          semanticLabel: 'Change view, ${size.label}',
          child: SizedBox(
            height: HsSize.tapTarget,
            child: Center(
              child: Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  border: Border.all(color: palette.stroke),
                  borderRadius: HsRadius.pillBorder,
                ),
                child: Icon(
                  Icons.view_agenda_outlined,
                  size: 16,
                  color: palette.textSecondary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ScopePill extends StatelessWidget {
  const new({
    required this.label,
    required this.isFiltered,
    required this.onTap,
  });

  final String label;
  final bool isFiltered;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.hs;
    return Pressable(
      onTap: onTap,
      semanticLabel: 'Filter headlines',
      child: Container(
        height: HsSize.tapTarget,
        alignment: Alignment.center,
        child: Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: HsSpace.x3),
          decoration: BoxDecoration(
            border: Border.all(
              color: isFiltered ? palette.textMuted : palette.stroke,
            ),
            borderRadius: HsRadius.pillBorder,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: HsType.chipSelected.copyWith(
                  color: isFiltered
                      ? palette.textPrimary
                      : palette.textSecondary,
                ),
              ),
              const SizedBox(width: HsSpace.x2),
              HsGlyph.chevron(
                isFiltered ? palette.textPrimary : palette.textSecondary,
                direction: AxisDirection.down,
                size: 6,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OfflineNote extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final palette = context.hs;
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, HsSpace.x4, 0, 2),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: HsSpace.x3,
        ),
        decoration: BoxDecoration(
          color: palette.surfaceVariant,
          borderRadius: HsRadius.buttonBorder,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'No connection',
              style: HsType.buttonSmall.copyWith(color: palette.textPrimary),
            ),
            const SizedBox(height: 3),
            Text(
              'Showing what was cached. Everything here still opens in the '
              'Reader.',
              style: HsType.note.copyWith(color: palette.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _RefreshingSkeleton extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(
      HsSpace.x5,
      0,
      HsSpace.x5,
      HsSpace.navClearance,
    ),
    children: [
      HeaderPage.gap(),
      const SizedBox(height: HsSpace.x5),
      const HeadlineSkeleton(),
      const SizedBox(height: 30),
      const HeadlineSkeleton(widths: [0.64, 0.4], withThumbnail: true),
      const SizedBox(height: 30),
      const HeadlineSkeleton(widths: [0.86, 0.46]),
      const SizedBox(height: 30),
      const Opacity(opacity: 0.55, child: HeadlineSkeleton(widths: [0.7, 0.3])),
    ],
  );
}
