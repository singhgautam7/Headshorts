import 'package:flutter/widgets.dart';
import 'package:headshorts/core/theme/hs_theme.dart';
import 'package:headshorts/core/tokens/accents.dart';
import 'package:headshorts/core/tokens/dimensions.dart';
import 'package:headshorts/core/tokens/typography.dart';
import 'package:headshorts/core/widgets/controls.dart';
import 'package:headshorts/data/sources/starter_set.dart';

/// The starter-set list, grouped by category with a toggle per source.
///
/// Shared by onboarding and by the Sources screen, so both read identically.
class SourcePicker extends StatelessWidget {
  const new({
    required this.sources,
    required this.chosen,
    required this.onToggle,
    this.alreadySubscribed = const {},
    this.padding = const EdgeInsets.symmetric(horizontal: HsSpace.x5),
    super.key,
  });

  final List<StarterSource> sources;
  final Set<String> chosen;
  final Set<String> alreadySubscribed;
  final ValueChanged<String> onToggle;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final grouped = <String, List<StarterSource>>{};
    for (final source in sources) {
      grouped.putIfAbsent(source.category, () => []).add(source);
    }

    return ListView(
      padding: padding,
      children: [
        for (final entry in grouped.entries) ...[
          const SizedBox(height: 22),
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: SectionLabel(entry.key),
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

class _PickerRow extends StatelessWidget {
  const new({
    required this.source,
    required this.selected,
    required this.locked,
    required this.showDivider,
    required this.onToggle,
  });

  final StarterSource source;
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
