import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:headshorts/app/nav_visibility.dart';
import 'package:headshorts/app/refresh_controller.dart';
import 'package:headshorts/core/theme/hs_theme.dart';
import 'package:headshorts/core/tokens/dimensions.dart';
import 'package:headshorts/core/tokens/motion.dart';
import 'package:headshorts/core/tokens/typography.dart';
import 'package:headshorts/core/util/relative_time.dart';
import 'package:headshorts/core/widgets/caught_up.dart';
import 'package:headshorts/core/widgets/controls.dart';
import 'package:headshorts/core/widgets/glyphs.dart';
import 'package:headshorts/core/widgets/pull_to_refresh.dart';
import 'package:headshorts/core/widgets/screen.dart';
import 'package:headshorts/data/db/article_repository.dart';
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
  /// The category strip and the pages are one control: tapping a tab and
  /// swiping a page are the same gesture, and this keeps them in step.
  final _pages = PageController();

  @override
  void initState() {
    super.initState();
    // Refresh behind whatever is already on screen — never in front of it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(ref.read(refreshProvider.notifier).refreshIfDue());
    });
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  /// Brings the pages to [index] when the strip, or a vanished category,
  /// moved the selection out from under them.
  void _syncPages(int index) {
    if (!_pages.hasClients || _pages.positions.length != 1) return;
    final showing = (_pages.page ?? _pages.initialPage.toDouble()).round();
    if (showing == index) return;
    // Adjacent tabs slide; a jump across the strip would blur half the
    // categories on the way past.
    if ((showing - index).abs() > 1) {
      _pages.jumpToPage(index);
    } else {
      _pages.animateToPage(
        index,
        duration: HsMotion.page,
        curve: HsMotion.pageCurve,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.hs;
    final categories =
        ref.watch(categoriesProvider).value ?? const [latestScope];
    final selected = ref.watch(activeCategoryProvider);
    // Selected, not watched whole: a refresh emits one progress event per
    // feed, and Today has no business rebuilding forty-five times for a word
    // that only changes twice.
    final refreshing = ref.watch(refreshProvider.select((p) => p.isRunning));
    final offline = ref.watch(offlineProvider);
    final lastUpdated = ref.watch(lastUpdatedProvider).value;

    final index = categories.indexOf(selected).clamp(0, categories.length - 1);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncPages(index);
    });

    return HsScreen(
      title: 'Today',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!offline)
            Text(
              refreshing
                  ? 'updating…'
                  : lastUpdated == null
                  ? ''
                  : 'updated ${clockTime(lastUpdated)}',
              style: HsType.timestamp.copyWith(color: palette.textMuted),
            ),
          const SizedBox(width: 10),
          Transform.translate(
            offset: const Offset(9, 0),
            child: Pressable(
              onTap: () => ref.read(refreshProvider.notifier).refresh(),
              semanticLabel: 'Check for new',
              child: SizedBox(
                width: 40,
                height: 40,
                child: Center(child: HsGlyph.refresh(palette.textSecondary)),
              ),
            ),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SubTabs(
            labels: categories,
            selectedIndex: index,
            onSelected: (i) => ref
                .read(selectedCategoryProvider.notifier)
                .select(categories[i]),
          ),
          if (offline) const _OfflineNote(),
          Expanded(
            child: PageView.builder(
              controller: _pages,
              itemCount: categories.length,
              onPageChanged: (i) => ref
                  .read(selectedCategoryProvider.notifier)
                  .select(categories[i]),
              // Only the category in front of the reader is queried. The one
              // arriving under their thumb shows the skeleton until the swipe
              // settles and it becomes the selection.
              itemBuilder: (context, i) => i == index
                  ? const _BriefingPage()
                  : const _RefreshingSkeleton(),
            ),
          ),
        ],
      ),
    );
  }
}

/// One category page: the briefing, or the skeleton that stands in for it.
class _BriefingPage extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offline = ref.watch(offlineProvider);
    return ref
        .watch(briefingProvider)
        .when(
          loading: () => const _RefreshingSkeleton(),
          error: (_, _) => const _RefreshingSkeleton(),
          data: (headlines) =>
              // An empty cache mid-first-fetch is not an empty briefing.
              headlines.isEmpty && ref.watch(awaitingFirstFetchProvider)
              ? const _RefreshingSkeleton()
              : _Briefing(headlines: headlines, offline: offline),
        );
  }
}

class _Briefing extends ConsumerWidget {
  const new({required this.headlines, required this.offline});

  final List<Headline> headlines;
  final bool offline;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.hs;
    final category = ref.watch(activeCategoryProvider);
    final sources = ref.watch(sourcesProvider).value ?? const [];
    final muted = ref.watch(mutedSourcesProvider);

    final scoped = sources
        .where(
          (s) =>
              s.enabled &&
              (category == latestScope
                  ? !s.mutedInLatest
                  : s.category == category),
        )
        .toList();
    final visible = scoped.where((s) => !muted.contains(s.id)).length;

    return NotificationListener<ScrollNotification>(
      // Today is the only place the pill gets out of the way. Linger keeps
      // its chrome, per the design board.
      onNotification: (notification) {
        final metrics = notification.metrics;
        // The category pager scrolls horizontally through this same listener;
        // only the list itself pages and moves the pill.
        if (metrics.axis != Axis.vertical) return false;
        // Load the next page as the reader nears the end of this one.
        if (metrics.hasContentDimensions &&
            metrics.extentAfter < metrics.viewportDimension) {
          unawaited(ref.read(todayPaginationProvider.notifier).loadMore());
        }
        ref
            .read(navVisibilityProvider.notifier)
            .onScroll(
              notification.metrics,
              delta: notification is ScrollUpdateNotification
                  ? notification.scrollDelta ?? 0
                  : 0,
            );
        return false;
      },
      child: PullToRefresh(
        onRefresh: () => ref.read(refreshProvider.notifier).refresh(),
        padding: const EdgeInsets.only(
          left: HsSpace.x5,
          right: HsSpace.x5,
          bottom: HsSpace.navClearance,
        ),
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    headlines.isEmpty
                        ? 'Nothing here yet'
                        : '${headlines.length} '
                              '${headlines.length == 1 ? 'headline' : 'headlines'} '
                              '· newest first',
                    style: HsType.timestamp.copyWith(color: palette.textMuted),
                  ),
                ),
                _ScopePill(
                  label: category == latestScope
                      ? (visible == scoped.length
                            ? 'All sources'
                            : '$visible of ${scoped.length} sources')
                      : '$category · $visible '
                            '${visible == 1 ? 'source' : 'sources'}',
                  onTap: () => showSourceFilterSheet(context, scoped),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          for (var i = 0; i < headlines.length; i++) ...[
            if (i > 0) const SizedBox(height: 30),
            HeadlineCard(
              headlines[i],
              offline: offline,
              // The optional lead-card wash: paper only, unread only.
              washed: i == 0 && !palette.isDark && !headlines[i].isRead,
              onTap: () => context.push('/reader/${headlines[i].article.id}'),
            ),
          ],
          if (headlines.isNotEmpty) ...[
            const SizedBox(height: 30),
            const HsDivider(),
          ],
          Padding(
            padding: const EdgeInsets.only(top: 40),
            child: _CaughtUp(count: headlines.length, sources: visible),
          ),
        ],
      ),
    );
  }
}

class _CaughtUp extends ConsumerWidget {
  const new({required this.count, required this.sources});

  final int count;
  final int sources;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final oldest = ref.watch(briefingProvider).value?.lastOrNull;

    return CaughtUp(
      detail: count == 0
          ? 'Nothing has arrived from your sources yet. Pull down to check.'
          : 'That is everything from your '
                '$sources ${sources == 1 ? 'source' : 'sources'}'
                '${oldest == null ? '' : ' since '
                          '${clockTime(oldest.article.publishedAt)}'}. '
                'Nothing more will load here.',
      actionLabel: 'Check for new',
      onAction: () => ref.read(refreshProvider.notifier).refresh(),
    );
  }
}

class _ScopePill extends StatelessWidget {
  const new({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.hs;
    return Pressable(
      onTap: onTap,
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: HsSpace.x3),
        decoration: BoxDecoration(
          border: Border.all(color: palette.stroke),
          borderRadius: HsRadius.pillBorder,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: HsType.chipSelected.copyWith(color: palette.textSecondary),
            ),
            const SizedBox(width: HsSpace.x2),
            HsGlyph.chevron(
              palette.textSecondary,
              direction: AxisDirection.down,
              size: 6,
            ),
          ],
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
      padding: const EdgeInsets.fromLTRB(HsSpace.x5, HsSpace.x4, HsSpace.x5, 2),
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
      SizedBox(height: 30),
      Opacity(opacity: 0.55, child: HeadlineSkeleton(widths: [0.7, 0.3])),
    ],
  );
}
