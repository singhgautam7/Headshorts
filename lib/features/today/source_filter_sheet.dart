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

/// Narrows the current view to some of its sources.
///
/// A lens on the briefing, not a subscription change — nothing here alters
/// what is fetched, only what this list shows.
Future<void> showSourceFilterSheet(
  BuildContext context,
  List<SourceRow> sources,
) => showHsSheet<void>(
  context,
  (context) => _SourceFilterSheet(sources: sources),
);

class _SourceFilterSheet extends ConsumerWidget {
  const new({required this.sources});

  final List<SourceRow> sources;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.hs;
    final muted = ref.watch(mutedSourcesProvider);

    return HsSheet(
      title: 'Show in this list',
      subtitle: 'Hiding a source here does not unsubscribe from it.',
      children: [
        for (final source in sources)
          AccentScope(
            accent: source.accent,
            child: Padding(
              padding: const EdgeInsets.only(bottom: HsSpace.x1),
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
                        style: HsType.row.copyWith(color: palette.textPrimary),
                      ),
                    ),
                    HsToggle(
                      value: !muted.contains(source.id),
                      onChanged: (visible) => ref
                          .read(mutedSourcesProvider.notifier)
                          .toggle(source.id, visible: visible),
                    ),
                  ],
                ),
              ),
            ),
          ),
        const SizedBox(height: HsSpace.x4),
        HsButton(
          'Show all',
          onPressed: ref.read(mutedSourcesProvider.notifier).showAll,
          kind: HsButtonKind.secondary,
        ),
      ],
    );
  }
}
