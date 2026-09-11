import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:headshorts/app/providers.dart';
import 'package:headshorts/core/theme/hs_theme.dart';
import 'package:headshorts/core/tokens/accents.dart';
import 'package:headshorts/core/tokens/dimensions.dart';
import 'package:headshorts/core/tokens/typography.dart';
import 'package:headshorts/core/widgets/controls.dart';
import 'package:headshorts/core/widgets/glyphs.dart';
import 'package:headshorts/core/widgets/screen.dart';
import 'package:headshorts/core/widgets/search_field.dart';
import 'package:headshorts/features/sources/category_sheet.dart';
import 'package:headshorts/features/sources/sources_controller.dart';
import 'package:headshorts/features/today/today_controller.dart';

final unseenBySourceProvider = StreamProvider<Map<int, int>>(
  (ref) => ref.watch(articleRepositoryProvider).watchUnseenBySource(),
);

/// Sources — the whole catalog, plus whatever the reader added themselves.
///
/// The same list the onboarding picker shows, so the place you chose sources
/// is the place you change them. A toggle turns a source on or off; the quiet
/// state line says what it is doing. No unread counts on the nav, ever.
class SourcesScreen extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.hs;
    final grouped = ref.watch(manageableSourcesProvider);
    final loading = ref.watch(sourceCatalogProvider).isLoading;
    final subscribed = (ref.watch(sourcesProvider).value ?? const [])
        .where((s) => s.enabled)
        .length;

    // Headers and rows in one flat list, so the whole catalog builds lazily
    // rather than forty-five rows deep on every keystroke.
    final rows = <Object>[
      for (final entry in grouped.entries) ...[
        _CategoryHeader(entry.key, entry.value),
        ...entry.value,
      ],
    ];

    return HsScreen(
      title: 'Sources',
      titlePadding: const EdgeInsets.fromLTRB(HsSpace.x5, 6, HsSpace.x5, 18),
      trailing: Pressable(
        onTap: () => context.push('/sources/add-url'),
        semanticLabel: 'Add a source by address',
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border.all(color: palette.stroke),
            borderRadius: HsRadius.pillBorder,
          ),
          child: Text(
            'Add',
            style: HsType.buttonSmall.copyWith(color: palette.textSecondary),
          ),
        ),
      ),
      child: ListView.builder(
        padding: const EdgeInsets.only(
          left: HsSpace.x5,
          right: HsSpace.x5,
          bottom: HsSpace.navClearance,
        ),
        // The header block, then the rows — or the skeleton standing in for
        // them while the catalog asset is being read.
        itemCount: 1 + (loading ? _skeletonRows : rows.length) + 1,
        itemBuilder: (context, i) {
          if (i == 0) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                HsSearchField(
                  hint: 'Search publishers and categories',
                  onChanged: ref.read(sourcesQueryProvider.notifier).set,
                ),
                const SizedBox(height: HsSpace.x3),
                Text(
                  subscribed == 0
                      ? 'Nothing on yet. Turn a few on and the briefing starts '
                            'filling.'
                      : '$subscribed on · turning one off keeps it, and its '
                            'items, for later',
                  style: HsType.note.copyWith(color: palette.textMuted),
                ),
              ],
            );
          }
          if (loading) return const _RowSkeleton();

          final index = i - 1;
          if (index == rows.length) {
            return rows.isEmpty
                ? _NoMatches(onAddByUrl: () => context.push('/sources/add-url'))
                : const SizedBox.shrink();
          }

          final row = rows[index];
          if (row is _CategoryHeader) return row;

          final entry = row as SourceEntry;
          final group = grouped[entry.category] ?? const <SourceEntry>[];
          return SourceRowTile(
            entry: entry,
            showDivider: entry.feedUrl != group.last.feedUrl,
            onTap: () {
              final id = entry.subscription?.id;
              if (id != null) unawaited(context.push('/sources/$id'));
            },
            onToggle: (on) => unawaited(setSourceOn(ref, entry, on: on)),
          );
        },
      ),
    );
  }
}

/// How many placeholder rows stand in while the catalog asset is read. Enough
/// to fill a phone screen, and no more — a skeleton is a shape, not a guess at
/// the answer.
const _skeletonRows = 7;

/// A category heading, doubling as the rename affordance.
class _CategoryHeader extends StatelessWidget {
  const new(this.category, this.entries);

  final String category;
  final List<SourceEntry> entries;

  @override
  Widget build(BuildContext context) {
    final palette = context.hs;
    return Padding(
      padding: const EdgeInsets.only(bottom: HsSpace.x3, top: HsSpace.x5),
      child: Pressable(
        // Renaming is the whole of category management: rename onto a new
        // name to create one, onto an existing name to merge.
        onTap: () => showRenameCategorySheet(context, category),
        semanticLabel: 'Rename $category',
        child: Row(
          children: [
            SectionLabel(
              '$category · ${entries.where((s) => s.isOn).length}'
              ' of ${entries.length}',
            ),
            const SizedBox(width: HsSpace.x2),
            HsGlyph.chevron(
              palette.textMuted,
              direction: AxisDirection.right,
              size: 6,
            ),
          ],
        ),
      ),
    );
  }
}

/// A source row with nothing in it yet. Flat, like every skeleton here.
class _RowSkeleton extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final fill = context.hs.skeleton;
    Widget bar(double factor, double height) => FractionallySizedBox(
      alignment: Alignment.centerLeft,
      widthFactor: factor,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );

    return SizedBox(
      height: HsSize.sourceRowHeight,
      child: Row(
        children: [
          Container(
            width: HsSize.accentBar,
            height: 28,
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [bar(0.5, 12), const SizedBox(height: 8), bar(0.2, 8)],
            ),
          ),
        ],
      ),
    );
  }
}

/// A source row: accent rule, title, quiet state, toggle.
///
/// The design board's anatomy, with one addition — a row the reader has not
/// subscribed to yet shows no state line, because it is not doing anything.
class SourceRowTile extends StatelessWidget {
  const new({
    required this.entry,
    required this.onTap,
    required this.onToggle,
    this.showDivider = true,
    super.key,
  });

  final SourceEntry entry;
  final VoidCallback onTap;
  final ValueChanged<bool> onToggle;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final palette = context.hs;
    final accent = entry.accent.resolve(isDark: palette.isDark);
    final state = entry.state;

    return AccentScope(
      accent: entry.accent,
      child: Opacity(
        // An untaken source is quieter than a paused one, which is quieter
        // than a working one.
        opacity: entry.isOn ? 1 : (entry.isSubscribed ? 0.55 : 0.75),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: showDivider
                ? Border(bottom: BorderSide(color: palette.divider))
                : null,
          ),
          child: SizedBox(
            height: HsSize.sourceRowHeight,
            child: Row(
              children: [
                Expanded(
                  child: Pressable(
                    onTap: entry.isSubscribed ? onTap : null,
                    child: Row(
                      children: [
                        Container(
                          width: HsSize.accentBar,
                          height: 28,
                          decoration: BoxDecoration(
                            color: accent,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                entry.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: HsType.row.copyWith(
                                  color: palette.textPrimary,
                                ),
                              ),
                              if (state != null) ...[
                                const SizedBox(height: HsSpace.x1),
                                Text(
                                  state,
                                  style: HsType.rowSub.copyWith(
                                    color: palette.textMuted,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                HsToggle(value: entry.isOn, onChanged: onToggle),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NoMatches extends StatelessWidget {
  const new({required this.onAddByUrl});

  final VoidCallback onAddByUrl;

  @override
  Widget build(BuildContext context) {
    final palette = context.hs;
    return Padding(
      padding: const EdgeInsets.only(top: HsSpace.x6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Nothing here matches',
            style: HsType.stepTitle.copyWith(color: palette.textPrimary),
          ),
          const SizedBox(height: HsSpace.x2),
          Text(
            'The built-in list is deliberately small. Almost any site with a '
            'feed can be added by pasting its address.',
            style: HsType.caughtUpBody.copyWith(color: palette.textSecondary),
          ),
          const SizedBox(height: HsSpace.x5),
          HsButton(
            'Add by URL',
            onPressed: onAddByUrl,
            kind: HsButtonKind.secondary,
          ),
        ],
      ),
    );
  }
}
