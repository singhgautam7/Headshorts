import 'dart:async';

import 'package:flutter/material.dart' show Icons, Tooltip;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:headshorts/app/nav_visibility.dart';
import 'package:headshorts/app/providers.dart';
import 'package:headshorts/app/refresh_controller.dart';
import 'package:headshorts/app/settings_controller.dart';
import 'package:headshorts/core/theme/hs_theme.dart';
import 'package:headshorts/core/tokens/dimensions.dart';
import 'package:headshorts/core/tokens/typography.dart';
import 'package:headshorts/core/util/relative_time.dart';
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
    final offline = ref.watch(offlineProvider);

    return HsScreen(
      title: 'Headlines',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (offline) const _OfflineNote(),
          const Expanded(child: _BriefingPage()),
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
          skipLoadingOnReload: false,
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
    // Selected, not watched whole: a refresh emits one progress event per
    // feed, and Today has no business rebuilding forty-five times for a word
    // that only changes twice.
    final refreshing = ref.watch(refreshProvider.select((p) => p.isRunning));
    final lastUpdated = ref.watch(lastUpdatedProvider).value;
    final size = ref.watch(settingsProvider.select((s) => s.listSize));

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
    final isFiltered = category != latestScope || muted.isNotEmpty;

    final String filterLabel;
    if (!isFiltered) {
      filterLabel = 'Filter';
    } else if (category != latestScope && muted.isEmpty) {
      filterLabel = 'Filter · $category';
    } else if (category != latestScope && muted.isNotEmpty) {
      filterLabel = 'Filter · $category ($visible)';
    } else {
      filterLabel = 'Filter · $visible of ${scoped.length}';
    }

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
      child: PullToRefresh.builder(
        onRefresh: () => ref.read(refreshProvider.notifier).refresh(),
        padding: const EdgeInsets.only(
          left: HsSpace.x5,
          right: HsSpace.x5,
          bottom: HsSpace.navClearance,
        ),
        itemCount: headlines.isEmpty ? 2 : headlines.length + 3,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 14),
              child: Row(
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
                          ? 'updating…'
                          : lastUpdated == null
                          ? 'Not fetched yet'
                          : 'updated ${clockTime(lastUpdated)}',
                      style: HsType.timestamp.copyWith(
                        color: palette.textMuted,
                      ),
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
            return Padding(
              padding: EdgeInsets.only(bottom: listGapFor(size)),
              child: HeadlineCard(
                ArticleView.fromHeadline(headlines[i]),
                size: size,
                offline: offline,
                // The optional lead-card wash: paper only, unread only, and
                // only at the size that has room for it.
                washed:
                    i == 0 &&
                    size == ListSize.large &&
                    !palette.isDark &&
                    !headlines[i].isRead,
                onTap: () => context.push('/reader/${headlines[i].article.id}'),
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
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.count > 0) {
        unawaited(HapticFeedback.mediumImpact());
        unawaited(ref.read(statsRepositoryProvider).markCaughtUpToday());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final oldest = ref.watch(briefingProvider).value?.lastOrNull;

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
            height: HsSize.navItem,
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
        height: HsSize.navItem,
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
