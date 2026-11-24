import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:headshorts/core/motion/expand_collapse.dart';
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

/// A chip's hit region adds half of (48 - 32) above and below its visual, so
/// the spacers around a chip run are shortened to keep the sheet as drawn.
const _hitPad = (HsSize.tapTarget - HsSize.chipVisual) / 2;
const _chipLead = HsSpace.x3 - _hitPad;
const _section = 26 - _hitPad;

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
  List<SourceRow> _last = const [];

  List<SourceRow> _shown(List<SourceRow> scope) =>
      scope.isEmpty ? _last : (_last = scope);

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
        const SizedBox(height: _chipLead),
        Wrap(
          spacing: HsSpace.x2,
          runSpacing: HsChip.runSpacing(HsSpace.x2),
          children: [
            for (final category in categories)
              HsChip(
                category,
                selected: category == _draft.category,
                onTap: () => _selectCategory(category),
              ),
          ],
        ),
        const SizedBox(height: _section),
        SectionLabel(
          scope.isEmpty
              ? 'Sources'
              : 'Sources · ${chosen?.length ?? scope.length} of ${scope.length}',
        ),
        const SizedBox(height: _chipLead),
        ExpandCollapse(
          expanded: scope.isEmpty,
          child: Text(
            'Nothing is subscribed under this category.',
            style: HsType.note.copyWith(color: palette.textMuted),
          ),
        ),
        ExpandCollapse(
          expanded: scope.isNotEmpty,
          child: Wrap(
            spacing: HsSpace.x2,
            runSpacing: HsChip.runSpacing(HsSpace.x2),
            children: [
              for (final source in _shown(scope))
                AccentScope(
                  key: ValueKey(source.feedUrl),
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
        ),
        const SizedBox(height: _section),
        Row(
          children: [
            Expanded(
              child: HsButton(
                'Clear filter',
                onPressed:
                    _draft.isDefault && ref.read(lingerFilterProvider).isDefault
                    ? null
                    : () {
                        ref.read(lingerFilterProvider.notifier).clear();
                        Navigator.of(context).pop();
                      },
                kind: HsButtonKind.secondary,
              ),
            ),
            const SizedBox(width: HsSpace.x3),
            Expanded(
              child: HsButton(
                'Apply',
                onPressed: () {
                  ref.read(lingerFilterProvider.notifier).apply(_draft);
                  Navigator.of(context).pop();
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}
