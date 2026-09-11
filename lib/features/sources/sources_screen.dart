import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:headshorts/app/providers.dart';
import 'package:headshorts/core/theme/hs_theme.dart';
import 'package:headshorts/core/tokens/accents.dart';
import 'package:headshorts/core/tokens/dimensions.dart';
import 'package:headshorts/core/tokens/typography.dart';
import 'package:headshorts/core/widgets/controls.dart';
import 'package:headshorts/core/widgets/screen.dart';
import 'package:headshorts/data/db/database.dart';
import 'package:headshorts/data/db/source_repository.dart';
import 'package:headshorts/features/today/today_controller.dart';

final unseenBySourceProvider = StreamProvider<Map<int, int>>(
  (ref) => ref.watch(articleRepositoryProvider).watchUnseenBySource(),
);

/// Sources — the subscription list, grouped by category.
///
/// Each row carries an accent rule, a quiet state line and an enable toggle.
/// The state line is a state, not a score: "4 new" disappears the moment they
/// have been seen, and never appears on the nav or the app icon.
class SourcesScreen extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.hs;
    final sources = ref.watch(sourcesProvider).value ?? const [];
    final unseen = ref.watch(unseenBySourceProvider).value ?? const {};

    if (sources.isEmpty) return const _Empty();

    final grouped = <String, List<SourceRow>>{};
    for (final source in sources) {
      grouped.putIfAbsent(source.category, () => []).add(source);
    }

    return HsScreen(
      title: 'Sources',
      titlePadding: const EdgeInsets.fromLTRB(HsSpace.x5, 6, HsSpace.x5, 18),
      trailing: Pressable(
        onTap: () => context.push('/sources/add'),
        semanticLabel: 'Add a source',
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
      child: ListView(
        padding: const EdgeInsets.only(
          left: HsSpace.x5,
          right: HsSpace.x5,
          bottom: HsSpace.navClearance,
        ),
        children: [
          for (final entry in grouped.entries) ...[
            Padding(
              padding: const EdgeInsets.only(
                bottom: HsSpace.x3,
                top: HsSpace.x5,
              ),
              child: SectionLabel('${entry.key} · ${entry.value.length}'),
            ),
            for (var i = 0; i < entry.value.length; i++)
              SourceRowTile(
                source: entry.value[i],
                unseen: unseen[entry.value[i].id] ?? 0,
                showDivider: i < entry.value.length - 1,
                onTap: () => context.push('/sources/${entry.value[i].id}'),
                onToggle: (enabled) => ref
                    .read(sourceRepositoryProvider)
                    .setEnabled(entry.value[i].id, enabled: enabled),
              ),
          ],
        ],
      ),
    );
  }
}

/// A source row: accent rule, title, quiet state, toggle.
class SourceRowTile extends StatelessWidget {
  const new({
    required this.source,
    required this.unseen,
    required this.onTap,
    required this.onToggle,
    this.showDivider = true,
    super.key,
  });

  final SourceRow source;
  final int unseen;
  final VoidCallback onTap;
  final ValueChanged<bool> onToggle;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final palette = context.hs;
    final accent = source.accent.resolve(isDark: palette.isDark);

    final state = switch (source) {
      _ when !source.enabled => 'paused',
      _ when source.failingSince != null => 'not responding',
      _ when unseen > 0 => '$unseen new',
      _ => 'caught up',
    };

    return AccentScope(
      accent: source.accent,
      child: Opacity(
        opacity: source.enabled ? 1 : 0.55,
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
                    onTap: onTap,
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
                                source.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: HsType.row.copyWith(
                                  color: palette.textPrimary,
                                ),
                              ),
                              const SizedBox(height: HsSpace.x1),
                              Text(
                                state,
                                style: HsType.rowSub.copyWith(
                                  color: palette.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                HsToggle(value: source.enabled, onChanged: onToggle),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final palette = context.hs;
    return HsScreen(
      title: 'Sources',
      titlePadding: const EdgeInsets.fromLTRB(HsSpace.x5, 6, HsSpace.x5, 18),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(HsSpace.x6, 0, HsSpace.x6, 96),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                for (var i = 0; i < 3; i++) ...[
                  if (i > 0) const SizedBox(width: 6),
                  Container(
                    width: HsSize.accentBar,
                    height: 26,
                    decoration: BoxDecoration(
                      color: palette.divider,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: HsSpace.x5),
            Text(
              'Nothing subscribed yet',
              style: HsType.screenTitle.copyWith(color: palette.textPrimary),
            ),
            const SizedBox(height: 14),
            Text(
              'Add a site and the briefing starts filling. Two or three good '
              'ones beat twenty you skim.',
              style: HsType.caughtUpBody.copyWith(color: palette.textSecondary),
            ),
            const SizedBox(height: HsSpace.x6),
            HsButton(
              'Paste a site address',
              onPressed: () => context.push('/sources/add'),
              height: 50,
            ),
            const SizedBox(height: 10),
            HsButton(
              'Browse the starter set',
              onPressed: () => context.push('/sources/starter'),
              kind: HsButtonKind.secondary,
              height: 50,
            ),
            const SizedBox(height: 10),
            HsButton(
              'Import OPML',
              onPressed: () => context.push('/sources/opml'),
              kind: HsButtonKind.tertiary,
              height: 50,
            ),
          ],
        ),
      ),
    );
  }
}
