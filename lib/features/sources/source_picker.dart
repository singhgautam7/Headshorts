import 'package:flutter/widgets.dart';
import 'package:headshorts/core/theme/hs_theme.dart';
import 'package:headshorts/core/tokens/accents.dart';
import 'package:headshorts/core/tokens/dimensions.dart';
import 'package:headshorts/core/tokens/typography.dart';
import 'package:headshorts/core/widgets/controls.dart';
import 'package:headshorts/data/sources/source_catalog.dart';

/// The catalog as a picker, grouped by category with a Select all per group.
///
/// Shared by onboarding and by Sources, so both read identically. Rows are the
/// design board's source row — accent dot, title, toggle at 44dp — and the
/// group header gains one control rather than a new layout.
class SourcePicker extends StatelessWidget {
  const new({
    required this.grouped,
    required this.chosen,
    required this.onToggle,
    required this.onToggleCategory,
    this.alreadySubscribed = const {},
    this.padding = const EdgeInsets.symmetric(horizontal: HsSpace.x5),
    this.leading,
    super.key,
  });

  final Map<String, List<CatalogSource>> grouped;
  final Set<String> chosen;
  final Set<String> alreadySubscribed;
  final ValueChanged<String> onToggle;

  /// Selects or clears a whole category at once.
  final void Function(String category, {required bool selected})
  onToggleCategory;

  final EdgeInsets padding;

  /// Sits above the list and scrolls with it — the search field, in practice.
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final palette = context.hs;

    return ListView(
      padding: padding,
      children: [
        ?leading,
        if (grouped.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: HsSpace.x6),
            child: Text(
              'Nothing here matches. You can add any site by its address once '
              'you are in.',
              style: HsType.caughtUpBody.copyWith(color: palette.textSecondary),
            ),
          ),
        for (final entry in grouped.entries) ...[
          const SizedBox(height: 22),
          _GroupHeader(
            category: entry.key,
            sources: entry.value,
            chosen: chosen,
            alreadySubscribed: alreadySubscribed,
            onToggleCategory: onToggleCategory,
          ),
          for (var i = 0; i < entry.value.length; i++)
            _PickerRow(
              source: entry.value[i],
              selected:
                  chosen.contains(entry.value[i].feedUrl) ||
                  alreadySubscribed.contains(entry.value[i].feedUrl),
              locked: alreadySubscribed.contains(entry.value[i].feedUrl),
              showDivider: i < entry.value.length - 1,
              onToggle: () => onToggle(entry.value[i].feedUrl),
            ),
        ],
      ],
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const new({
    required this.category,
    required this.sources,
    required this.chosen,
    required this.alreadySubscribed,
    required this.onToggleCategory,
  });

  final String category;
  final List<CatalogSource> sources;
  final Set<String> chosen;
  final Set<String> alreadySubscribed;
  final void Function(String category, {required bool selected})
  onToggleCategory;

  @override
  Widget build(BuildContext context) {
    final palette = context.hs;
    final selectable = sources
        .where((s) => !alreadySubscribed.contains(s.feedUrl))
        .toList();
    final allChosen =
        selectable.isNotEmpty &&
        selectable.every((s) => chosen.contains(s.feedUrl));

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(child: SectionLabel(category)),
          if (selectable.isNotEmpty)
            Pressable(
              onTap: () => onToggleCategory(category, selected: !allChosen),
              semanticLabel: allChosen
                  ? 'Clear $category'
                  : 'Select all in $category',
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: HsSpace.x2,
                  vertical: HsSpace.x2,
                ),
                child: Text(
                  allChosen ? 'Clear' : 'Select all',
                  style: HsType.buttonSmall.copyWith(
                    color: palette.textSecondary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PickerRow extends StatelessWidget {
  const new({
    required this.source,
    required this.selected,
    required this.locked,
    required this.showDivider,
    required this.onToggle,
  });

  final CatalogSource source;
  final bool selected;
  final bool locked;
  final bool showDivider;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final palette = context.hs;
    return AccentScope(
      accent: source.accent,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: showDivider
              ? Border(bottom: BorderSide(color: palette.divider))
              : null,
        ),
        child: SizedBox(
          height: HsSize.rowHeight,
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: source.accent.resolve(isDark: palette.isDark),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  source.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: HsType.row.copyWith(
                    color: selected
                        ? palette.textPrimary
                        : palette.textSecondary,
                  ),
                ),
              ),
              HsToggle(
                value: selected,
                onChanged: locked ? null : (_) => onToggle(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
