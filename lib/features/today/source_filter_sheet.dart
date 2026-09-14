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
import 'package:headshorts/features/today/today_controller.dart';

/// Narrows the Headlines view by category and sources.
///
/// A lens on the briefing, not a subscription change — nothing here alters
/// what is fetched, only what this list shows.
Future<void> showSourceFilterSheet(BuildContext context) =>
    showHsSheet<void>(context, (context) => const _SourceFilterSheet());

class _SourceFilterSheet extends ConsumerStatefulWidget {
  const new();

  @override
  ConsumerState<_SourceFilterSheet> createState() => _SourceFilterSheetState();
}

class _SourceFilterSheetState extends ConsumerState<_SourceFilterSheet> {
  late String _draftCategory = ref.read(activeCategoryProvider);
  late final Set<int> _draftMuted = {...ref.read(mutedSourcesProvider)};

  List<SourceRow> _inScope(List<SourceRow> sources) => sources
      .where(
        (s) =>
            s.enabled &&
            (_draftCategory == latestScope
                ? !s.mutedInLatest
                : s.category == _draftCategory),
      )
      .toList();

  void _selectCategory(String category) {
    setState(() {
      _draftCategory = category;
    });
  }

  void _toggleSource(int id, {required bool visible}) {
    setState(() {
      if (visible) {
        _draftMuted.remove(id);
      } else {
        _draftMuted.add(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.hs;
    final categories =
        ref.watch(categoriesProvider).value ?? const [latestScope];
    final sources = ref.watch(sourcesProvider).value ?? const [];
    final scope = _inScope(sources);
    final visibleCount = scope.where((s) => !_draftMuted.contains(s.id)).length;

    return HsSheet(
      title: 'Filter',
      subtitle:
          'Narrows this briefing. It does not change what you subscribe to.',
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
                selected: category == _draftCategory,
                onTap: () => _selectCategory(category),
              ),
          ],
        ),
        const SizedBox(height: 26),
        SectionLabel(
          scope.isEmpty
              ? 'Sources'
              : 'Sources · $visibleCount of ${scope.length}',
        ),
        const SizedBox(height: HsSpace.x3),
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOutCubic,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            layoutBuilder: (currentChild, previousChildren) => Stack(
              alignment: Alignment.topLeft,
              children: [...previousChildren, ?currentChild],
            ),
            transitionBuilder: (child, animation) =>
                FadeTransition(opacity: animation, child: child),
            child: KeyedSubtree(
              key: ValueKey(_draftCategory),
              child: scope.isEmpty
                  ? Text(
                      'Nothing is subscribed under this category.',
                      style: HsType.note.copyWith(color: palette.textMuted),
                    )
                  : Wrap(
                      spacing: HsSpace.x2,
                      runSpacing: HsSpace.x2,
                      children: [
                        for (final source in scope)
                          AccentScope(
                            accent: source.accent,
                            child: HsChip(
                              source.title,
                              selected: !_draftMuted.contains(source.id),
                              onTap: () => _toggleSource(
                                source.id,
                                visible: _draftMuted.contains(source.id),
                              ),
                            ),
                          ),
                      ],
                    ),
            ),
          ),
        ),
        const SizedBox(height: 26),
        Row(
          children: [
            Expanded(
              child: HsButton(
                'Clear filter',
                onPressed: _draftCategory == latestScope &&
                        _draftMuted.isEmpty &&
                        ref.read(activeCategoryProvider) == latestScope &&
                        ref.read(mutedSourcesProvider).isEmpty
                    ? null
                    : () {
                        ref
                            .read(selectedCategoryProvider.notifier)
                            .select(latestScope);
                        ref.read(mutedSourcesProvider.notifier).showAll();
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
                  if (_draftCategory != ref.read(activeCategoryProvider)) {
                    ref
                        .read(selectedCategoryProvider.notifier)
                        .select(_draftCategory);
                  }
                  ref.read(mutedSourcesProvider.notifier).setMuted(_draftMuted);
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
