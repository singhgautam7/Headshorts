import 'dart:async';

import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:headshorts/app/providers.dart';
import 'package:headshorts/core/motion/cross_fade.dart';
import 'package:headshorts/core/theme/hs_theme.dart';
import 'package:headshorts/core/tokens/accents.dart';
import 'package:headshorts/core/tokens/dimensions.dart';
import 'package:headshorts/core/tokens/typography.dart';
import 'package:headshorts/core/util/language.dart';
import 'package:headshorts/core/widgets/app_header.dart';
import 'package:headshorts/core/widgets/caught_up.dart';
import 'package:headshorts/core/widgets/controls.dart';
import 'package:headshorts/core/widgets/glyphs.dart';
import 'package:headshorts/core/widgets/screen.dart';
import 'package:headshorts/core/widgets/search_field.dart';
import 'package:headshorts/data/db/database.dart';
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
///
/// The structure (which rows, in which groups) is built from
/// [sourceEntriesProvider], which carries no unseen counts. The counts stream
/// out of `articles` and tick on every refresh, so each row reads its own
/// through a `select` and only that row's state line rebuilds.
class SourcesScreen extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.hs;
    final language = ref.watch(sourcesLanguageProvider);
    final grouped = _group(
      ref.watch(sourceEntriesProvider),
      language,
      ref.watch(sourcesQueryProvider),
    );
    final loading =
        ref.watch(sourceCatalogProvider).isLoading ||
        (ref.watch(sourcesProvider).isLoading && grouped.isEmpty);
    final subscribed = ref.watch(
      sourcesProvider.select(
        (s) => (s.value ?? const <SourceRow>[]).where((r) => r.enabled).length,
      ),
    );
    // A string, so the list rebuilds when the languages change and not each
    // time the counts behind them tick.
    final languageKey = ref.watch(
      sourceLanguagesProvider.select((l) => l.join('|')),
    );
    final languages = languageKey.isEmpty
        ? const <String>[]
        : languageKey.split('|');

    // Headers and rows in one flat list, so the whole catalog builds lazily
    // rather than forty-five rows deep on every keystroke.
    final rows = <Object>[
      for (final entry in grouped.entries) ...[
        _CategoryHeader(entry.key, entry.value, key: ValueKey(entry.key)),
        ...entry.value,
      ],
    ];
    final indexOfKey = <Key, int>{
      for (var i = 0; i < rows.length; i++)
        if (rows[i] case _CategoryHeader(:final key?))
          key: i + 1
        else if (rows[i] case final SourceEntry e)
          ValueKey(e.feedUrl): i + 1,
    };

    // The search field, language filter and state line are the list's first
    // row, under the header's gap: they scroll away with the rows, and only
    // the title header becomes the pill.
    Widget top() => Column(
      key: const ValueKey('sources-top'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HeaderPage.gap(),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            HsSpace.x5,
            HsSpace.x2,
            HsSpace.x5,
            0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              HsSearchField(
                hint: 'Search publishers and categories',
                initialText: ref.read(sourcesQueryProvider),
                onChanged: ref.read(sourcesQueryProvider.notifier).set,
              ),
              // Only when there is more than one to choose between, and
              // each language names itself in its own script.
              if (languages.length > 1) ...[
                const SizedBox(height: HsSpace.x3),
                LanguageChips(
                  languages: languages,
                  value: language,
                  onChanged: ref.read(sourcesLanguageProvider.notifier).select,
                ),
              ],
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
          ),
        ),
      ],
    );

    return HsScreen(
      title: 'Sources',
      underHeader: true,
      trailing: HsIconButton(
        icon: Icons.add_rounded,
        onPressed: () => context.push('/sources/add-url'),
        semanticLabel: 'Add a source by address',
      ),
      child: SkeletonCrossFade(
        loading: loading,
        // The skeleton standing in for the rows while the catalog asset is
        // being read. Flat, like every skeleton here.
        placeholder: ListView.builder(
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _skeletonRows + 1,
          itemBuilder: (context, i) => i == 0
              ? top()
              : const Padding(
                  padding: EdgeInsets.symmetric(horizontal: HsSpace.x5),
                  child: _RowSkeleton(),
                ),
        ),
        child: ListView.builder(
          padding: const EdgeInsets.only(bottom: HsSpace.navClearance),
          itemCount: rows.length + 2,
          findChildIndexCallback: (key) =>
              key == const ValueKey('sources-top') ? 0 : indexOfKey[key],
          itemBuilder: (context, index) {
            if (index == 0) return top();
            if (index == rows.length + 1) {
              return rows.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: HsSpace.x5,
                      ),
                      child: _NoMatches(
                        onAddByUrl: () => context.push('/sources/add-url'),
                      ),
                    )
                  : const SizedBox.shrink();
            }

            final row = rows[index - 1];
            if (row is _CategoryHeader) {
              return Padding(
                key: row.key,
                padding: const EdgeInsets.symmetric(horizontal: HsSpace.x5),
                child: row,
              );
            }

            final entry = row as SourceEntry;
            final group = grouped[entry.category] ?? const <SourceEntry>[];
            return Padding(
              key: ValueKey(entry.feedUrl),
              padding: const EdgeInsets.symmetric(horizontal: HsSpace.x5),
              child: _LiveRow(
                entry: entry,
                showLanguage: languages.length > 1,
                showDivider: entry.feedUrl != group.last.feedUrl,
                onTap: () {
                  final id = entry.subscription?.id;
                  if (id != null) unawaited(context.push('/sources/$id'));
                },
                onToggle: (on) => unawaited(setSourceOn(ref, entry, on: on)),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// The catalog, narrowed by language and query, grouped by category in the
/// order the entries arrive. The same rule as [manageableSourcesProvider],
/// over the list that carries no counts.
Map<String, List<SourceEntry>> _group(
  List<SourceEntry> entries,
  String? language,
  String query,
) {
  final terms = query
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .where((t) => t.isNotEmpty)
      .toList();
  final grouped = <String, List<SourceEntry>>{};
  for (final entry in entries) {
    if (language != null && entry.language != language) continue;
    final haystack = '${entry.title} ${entry.category}'.toLowerCase();
    if (!terms.every(haystack.contains)) continue;
    grouped.putIfAbsent(entry.category, () => []).add(entry);
  }
  return grouped;
}

/// One row, reading its own unseen count so a refresh rebuilds this row's
/// state line and nothing around it.
class _LiveRow extends ConsumerWidget {
  const new({
    required this.entry,
    required this.showLanguage,
    required this.showDivider,
    required this.onTap,
    required this.onToggle,
  });

  final SourceEntry entry;
  final bool showLanguage;
  final bool showDivider;
  final VoidCallback onTap;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = entry.subscription?.id;
    final unseen = id == null
        ? 0
        : ref.watch(unseenBySourceProvider.select((m) => m.value?[id] ?? 0));
    return SourceRowTile(
      entry: entry.withUnseen(unseen),
      showLanguage: showLanguage,
      showDivider: showDivider,
      onTap: onTap,
      onToggle: onToggle,
    );
  }
}

/// How many placeholder rows stand in while the catalog asset is read. Enough
/// to fill a phone screen, and no more — a skeleton is a shape, not a guess at
/// the answer.
const _skeletonRows = 7;

/// A category heading, doubling as the rename affordance.
class _CategoryHeader extends StatelessWidget {
  const new(this.category, this.entries, {super.key});

  final String category;
  final List<SourceEntry> entries;

  @override
  Widget build(BuildContext context) {
    final palette = context.hs;
    return Padding(
      padding: const EdgeInsets.only(top: HsSpace.x2),
      child: Pressable(
        // Renaming is the whole of category management: rename onto a new
        // name to create one, onto an existing name to merge.
        kind: PressKind.chip,
        morphCorners: false,
        onTap: () => showRenameCategorySheet(context, category),
        semanticLabel: 'Rename $category',
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: HsSize.tapTarget),
          child: Row(
            children: [
              Flexible(
                child: SectionLabel(
                  '$category · ${entries.where((s) => s.isOn).length}'
                  ' of ${entries.length}',
                ),
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
      ),
    );
  }
}

/// A source row with nothing in it yet. Flat, like every skeleton here.
class _RowSkeleton extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: HsSize.sourceRowHeight,
      child: Row(
        children: [
          Container(
            width: HsSize.accentBar,
            height: 28,
            decoration: BoxDecoration(
              color: context.hs.skeleton,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                SkeletonBar(widthFactor: 0.5, height: 12),
                SizedBox(height: 8),
                SkeletonBar(widthFactor: 0.2, height: 8),
              ],
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
    this.showLanguage = false,
    super.key,
  });

  final SourceEntry entry;
  final VoidCallback onTap;
  final ValueChanged<bool> onToggle;
  final bool showDivider;

  /// The two-letter tag. Shown only when the reader actually has more than
  /// one language — on an English-only list it says nothing.
  final bool showLanguage;

  @override
  Widget build(BuildContext context) {
    final palette = context.hs;
    final accent = entry.accent.resolve(isDark: palette.isDark);
    final state = entry.state;

    // An untaken source is quieter than a paused one, which is quieter than a
    // working one. Alpha on the colours rather than an `Opacity` layer: sixty
    // rows would otherwise each paint into an offscreen buffer.
    final fade = entry.isOn ? 1.0 : (entry.isSubscribed ? 0.55 : 0.75);

    return AccentScope(
      accent: entry.accent,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: showDivider
              ? Border(bottom: BorderSide(color: palette.divider))
              : null,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: HsSize.sourceRowHeight),
          child: Row(
            children: [
              Expanded(
                child: Pressable(
                  kind: PressKind.row,
                  enabled: entry.isSubscribed,
                  onTap: entry.isSubscribed ? onTap : null,
                  semanticLabel: state == null
                      ? entry.title
                      : '${entry.title}, $state',
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: HsSpace.x2),
                    child: Row(
                      children: [
                        Container(
                          width: HsSize.accentBar,
                          height: 28,
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: fade),
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
                                style: HsType.forText(HsType.row, entry.title)
                                    .copyWith(
                                      color: palette.textPrimary.withValues(
                                        alpha: fade,
                                      ),
                                    ),
                              ),
                              if (state != null || showLanguage) ...[
                                const SizedBox(height: HsSpace.x1),
                                Row(
                                  children: [
                                    if (showLanguage) ...[
                                      LanguageTag(entry.language),
                                      const SizedBox(width: 6),
                                    ],
                                    if (state != null)
                                      Flexible(
                                        child: Text(
                                          state,
                                          style: HsType.rowSub.copyWith(
                                            color: palette.textMuted.withValues(
                                              alpha: fade,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              HsToggle(value: entry.isOn, onChanged: onToggle),
            ],
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

/// A source's language as a two-letter code on a hairline.
///
/// Read out in full by TalkBack — "Hindi", never "H I" — because a screen
/// reader spelling a code is worse than no label at all.
class LanguageTag extends StatelessWidget {
  const new(this.tag, {super.key});

  final String tag;

  @override
  Widget build(BuildContext context) {
    final palette = context.hs;
    final language = HsLanguage.of(tag);
    return Semantics(
      label: language.englishName,
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
        decoration: BoxDecoration(
          border: Border.all(color: palette.stroke),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          language.code,
          style: HsType.languageTag.copyWith(color: palette.textSecondary),
        ),
      ),
    );
  }
}
