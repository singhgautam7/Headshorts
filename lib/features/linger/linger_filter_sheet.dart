import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:headshorts/core/theme/hs_theme.dart';
import 'package:headshorts/core/tokens/accents.dart';
import 'package:headshorts/core/tokens/dimensions.dart';
import 'package:headshorts/core/tokens/typography.dart';
import 'package:headshorts/core/widgets/controls.dart';
import 'package:headshorts/core/widgets/sheet.dart';
import 'package:headshorts/data/db/database.dart';
import 'package:headshorts/data/db/source_repository.dart';
import 'package:headshorts/features/linger/linger_controller.dart';
import 'package:headshorts/features/today/today_controller.dart';

/// Scopes Linger's queue by category and by source.
///
/// The same shape as Today's "All sources" sheet, and the same promise: this
/// is a filter. Only sources the reader is already subscribed to appear, and
/// nothing here adds, removes or pauses one.
Future<void> showLingerFilterSheet(BuildContext context) =>
    showHsSheet<void>(context, (context) => const _LingerFilterSheet());

class _LingerFilterSheet extends ConsumerStatefulWidget {
  const new();

  @override
  ConsumerState<_LingerFilterSheet> createState() => _LingerFilterSheetState();
}

class _LingerFilterSheetState extends ConsumerState<_LingerFilterSheet> {
  /// Edited in the sheet and committed on Apply, so a half-made choice never
  /// rebuilds the queue under the reader.
  late LingerFilter _draft = ref.read(lingerFilterProvider);

  List<SourceRow> _inScope(List<SourceRow> sources) => sources
      .where(
        (s) =>
            s.enabled &&
            (_draft.category == latestScope
                ? !s.mutedInLatest
                : s.category == _draft.category),
      )
      .toList();

  void _selectCategory(String category) => setState(() {
    // Source picks belong to the category they were made in; carrying them
    // across would leave a filter matching nothing.
    _draft = LingerFilter(category: category);
  });

  void _toggleSource(List<SourceRow> scope, int id, {required bool on}) =>
      setState(() {
        final chosen = {..._draft.sourceIds ?? scope.map((s) => s.id)};
        if (on) {
          chosen.add(id);
        } else {
          chosen.remove(id);
        }
        _draft = LingerFilter(
          category: _draft.category,
          // Back to "all of them" rather than an equivalent explicit set, so
          // a source added later is included without being re-picked.
          sourceIds: chosen.length == scope.length ? null : chosen,
        );
      });

  @override
  Widget build(BuildContext context) {
    final palette = context.hs;
    final categories =
        ref.watch(categoriesProvider).value ?? const [latestScope];
    final sources = ref.watch(sourcesProvider).value ?? const [];
    final scope = _inScope(sources);
    final chosen = _draft.sourceIds;

    return HsSheet(
      title: 'Filter',
      subtitle: 'Narrows this queue. It does not change what you subscribe to.',
      children: [
        const SectionLabel('Category'),
        const SizedBox(height: HsSpace.x3),
        Wrap(
          spacing: HsSpace.x2,
          runSpacing: HsSpace.x2,
          children: [
            for (final category in categories)
              HsChip(
                category,
                selected: category == _draft.category,
                onTap: () => _selectCategory(category),
              ),
          ],
        ),
        const SizedBox(height: 26),
        SectionLabel(
          scope.isEmpty
              ? 'Sources'
              : 'Sources · ${chosen?.length ?? scope.length} of ${scope.length}',
        ),
        const SizedBox(height: HsSpace.x3),
        if (scope.isEmpty)
          Text(
            'Nothing is subscribed under this category.',
            style: HsType.note.copyWith(color: palette.textMuted),
          )
        else
          Wrap(
            spacing: HsSpace.x2,
            runSpacing: HsSpace.x2,
            children: [
              for (final source in scope)
                AccentScope(
                  accent: source.accent,
                  child: HsChip(
                    source.title,
                    selected: chosen == null || chosen.contains(source.id),
                    onTap: () => _toggleSource(
                      scope,
                      source.id,
                      on: !(chosen == null || chosen.contains(source.id)),
                    ),
                  ),
                ),
            ],
          ),
        const SizedBox(height: 26),
        HsButton(
          'Apply',
          onPressed: () {
            ref.read(lingerFilterProvider.notifier).apply(_draft);
            Navigator.of(context).pop();
          },
        ),
        const SizedBox(height: HsSpace.x3),
        HsButton(
          'Clear filter',
          // Behind a scrim, an action that leaves the sheet open looks like it
          // did nothing.
          onPressed:
              _draft.isDefault && ref.read(lingerFilterProvider).isDefault
              ? null
              : () {
                  ref.read(lingerFilterProvider.notifier).clear();
                  Navigator.of(context).pop();
                },
          kind: HsButtonKind.secondary,
        ),
      ],
    );
  }
}
