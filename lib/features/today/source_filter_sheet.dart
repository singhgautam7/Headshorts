import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:headshorts/core/motion/expand_collapse.dart';
import 'package:headshorts/core/theme/hs_theme.dart';
import 'package:headshorts/core/tokens/accents.dart';
import 'package:headshorts/core/tokens/dimensions.dart';
import 'package:headshorts/core/tokens/typography.dart';
import 'package:headshorts/core/util/language.dart';
import 'package:headshorts/core/widgets/controls.dart';
import 'package:headshorts/core/widgets/sheet.dart';
import 'package:headshorts/data/db/database.dart';
import 'package:headshorts/data/db/source_repository.dart';
import 'package:headshorts/features/today/today_controller.dart';

/// A chip's hit region adds half of (48 - 32) above and below its visual, so
/// the spacers around a chip run are shortened to keep the sheet as drawn.
const _hitPad = (HsSize.tapTarget - HsSize.chipVisual) / 2;
const _chipLead = HsSpace.x3 - _hitPad;
const _section = 26 - _hitPad;

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
  List<SourceRow> _last = const [];

  List<SourceRow> _shown(List<SourceRow> scope) =>
      scope.isEmpty ? _last : (_last = scope);

  late String _draftCategory = ref.read(activeCategoryProvider);
  late String? _draftLanguage = ref.read(briefingLanguageProvider);
  late final Set<int> _draftMuted = {...ref.read(mutedSourcesProvider)};

  /// Language narrows the list rather than greying it out: with English
  /// chosen, the two Hindi sources drop out of the chips altogether, because
  /// a chip you cannot usefully turn on is noise.
  List<SourceRow> _inScope(List<SourceRow> sources) => sources
      .where(
        (s) =>
            s.enabled &&
            (_draftLanguage == null || s.language == _draftLanguage) &&
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
    final languages = ref.watch(briefingLanguagesProvider);
    final scope = _inScope(sources);
    final visibleCount = scope.where((s) => !_draftMuted.contains(s.id)).length;

    return HsSheet(
      title: 'Filter',
      subtitle:
          'Narrows this briefing. It does not change what you subscribe to.',
      children: [
        if (languages.length > 1) ...[
          const SectionLabel('Language'),
          const SizedBox(height: _chipLead),
          Wrap(
            spacing: HsSpace.x2,
            runSpacing: HsChip.runSpacing(HsSpace.x2),
            children: [
              HsChip(
                'All',
                selected: _draftLanguage == null,
                onTap: () => setState(() => _draftLanguage = null),
              ),
              for (final tag in languages)
                HsChip(
                  HsLanguage.of(tag).endonym,
                  selected: _draftLanguage == tag,
                  onTap: () => setState(() => _draftLanguage = tag),
                ),
            ],
          ),
          const SizedBox(height: _section),
        ],
        const SectionLabel('Category'),
        const SizedBox(height: _chipLead),
        Wrap(
          spacing: HsSpace.x2,
          runSpacing: HsChip.runSpacing(HsSpace.x2),
          children: [
            for (final category in categories)
              HsChip(
                category,
                selected: category == _draftCategory,
                onTap: () => _selectCategory(category),
              ),
          ],
        ),
        const SizedBox(height: _section),
        SectionLabel(
          scope.isEmpty
              ? 'Sources'
              : 'Sources · $visibleCount of ${scope.length}',
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
              // Keyed by feed so a chip that stays morphs rather than
              // being rebuilt; the last non-empty set shows while it
              // collapses.
              for (final source in _shown(scope))
                AccentScope(
                  key: ValueKey(source.feedUrl),
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
        const SizedBox(height: _section),
        Row(
          children: [
            Expanded(
              child: HsButton(
                'Clear filter',
                onPressed:
                    _draftCategory == latestScope &&
                        _draftLanguage == null &&
                        _draftMuted.isEmpty &&
                        ref.read(activeCategoryProvider) == latestScope &&
                        ref.read(briefingLanguageProvider) == null &&
                        ref.read(mutedSourcesProvider).isEmpty
                    ? null
                    : () {
                        ref
                            .read(selectedCategoryProvider.notifier)
                            .select(latestScope);
                        ref
                            .read(briefingLanguageProvider.notifier)
                            .select(null);
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
                  ref
                      .read(briefingLanguageProvider.notifier)
                      .select(_draftLanguage);
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
