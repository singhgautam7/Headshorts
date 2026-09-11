import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:headshorts/app/providers.dart';
import 'package:headshorts/app/refresh_controller.dart';
import 'package:headshorts/core/theme/hs_theme.dart';
import 'package:headshorts/core/tokens/accents.dart';
import 'package:headshorts/core/tokens/dimensions.dart';
import 'package:headshorts/core/tokens/typography.dart';
import 'package:headshorts/core/util/relative_time.dart';
import 'package:headshorts/core/widgets/controls.dart';
import 'package:headshorts/core/widgets/screen.dart';
import 'package:headshorts/core/widgets/sheet.dart';
import 'package:headshorts/data/db/database.dart';
import 'package:headshorts/data/db/source_repository.dart';
import 'package:headshorts/features/today/today_controller.dart';

final sourceProvider = StreamProvider.family<SourceRow?, int>(
  (ref, id) => ref.watch(sourceRepositoryProvider).watchById(id),
);

/// One source: its feed address, its accent, and — when it has stopped
/// answering — a plain statement of that in words. A broken feed never
/// surfaces as a red dot in the nav.
class SourceDetailScreen extends ConsumerWidget {
  const new(this.sourceId, {super.key});

  final int sourceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.hs;
    final source = ref.watch(sourceProvider(sourceId)).value;
    if (source == null) {
      return ColoredBox(color: palette.background, child: const SizedBox());
    }

    final accent = source.accent.resolve(isDark: palette.isDark);
    final failingSince = source.failingSince;

    return AccentScope(
      accent: source.accent,
      child: PushedScreen(
        title: source.title,
        onBack: () => context.pop(),
        child: ListView(
          padding: const EdgeInsets.all(HsSpace.x5),
          children: [
            Row(
              children: [
                Container(
                  width: HsSize.accentBar,
                  height: 34,
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        source.title,
                        style: HsType.appBarTitle.copyWith(
                          color: palette.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '${source.category} · added '
                        '${articleDateline(source.addedAt).split(',').first}',
                        style: HsType.timestamp.copyWith(
                          color: palette.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (failingSince != null) ...[
              const SizedBox(height: 22),
              _NotResponding(source: source, since: failingSince),
            ],
            const SizedBox(height: 22),
            const SectionLabel('Feed'),
            const SizedBox(height: HsSpace.x3),
            _DetailRow(label: source.feedUrl, muted: true),
            _DetailRow(
              label: 'Category',
              trailing: Text(
                source.category,
                style: HsType.rowValue.copyWith(color: palette.textMuted),
              ),
              onTap: () => _editCategory(context, ref, source),
            ),
            _DetailRow(
              label: 'Show in Latest',
              trailing: HsToggle(
                value: !source.mutedInLatest,
                onChanged: (show) => ref
                    .read(sourceRepositoryProvider)
                    .setMutedInLatest(source.id, muted: !show),
              ),
            ),
            _DetailRow(
              label: 'Accent colour',
              trailing: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent,
                ),
              ),
              onTap: () => _editAccent(context, ref, source),
            ),
            _DetailRow(
              label: 'Unsubscribe',
              muted: true,
              divider: false,
              onTap: () async {
                await ref.read(sourceRepositoryProvider).remove(source.id);
                if (context.mounted) context.pop();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editCategory(
    BuildContext context,
    WidgetRef ref,
    SourceRow source,
  ) async {
    final existing = (await ref.read(sourceRepositoryProvider).all())
        .map((s) => s.category)
        .toSet();
    if (!context.mounted) return;

    await showHsSheet<void>(
      context,
      (context) => HsSheet(
        title: 'Category',
        children: [
          Wrap(
            spacing: HsSpace.x2,
            runSpacing: HsSpace.x2,
            children: [
              for (final category in {...existing, ...defaultCategories})
                HsChip(
                  category,
                  selected: category == source.category,
                  onTap: () async {
                    await ref
                        .read(sourceRepositoryProvider)
                        .setCategory(source.id, category);
                    if (context.mounted) Navigator.of(context).pop();
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _editAccent(
    BuildContext context,
    WidgetRef ref,
    SourceRow source,
  ) => showHsSheet<void>(
    context,
    (context) => HsSheet(
      title: 'Accent colour',
      subtitle:
          'A label, a hairline and — in Linger — a quiet wash. '
          'Never a full card.',
      children: [
        Wrap(
          spacing: HsSpace.x3,
          runSpacing: HsSpace.x3,
          children: [
            for (var hue = 0; hue < 360; hue += 30)
              _Swatch(
                accent: SourceAccent.fromSeed(
                  HSLColor.fromAHSL(1, hue.toDouble(), 0.45, 0.6).toColor(),
                ),
                onTap: (accent) async {
                  await ref
                      .read(sourceRepositoryProvider)
                      .setAccent(source.id, accent);
                  if (context.mounted) Navigator.of(context).pop();
                },
              ),
          ],
        ),
      ],
    ),
  );
}

class _Swatch extends StatelessWidget {
  const new({required this.accent, required this.onTap});

  final SourceAccent accent;
  final ValueChanged<SourceAccent> onTap;

  @override
  Widget build(BuildContext context) => Pressable(
    onTap: () => onTap(accent),
    child: Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: accent.resolve(isDark: context.hs.isDark),
      ),
    ),
  );
}

class _NotResponding extends ConsumerWidget {
  const new({required this.source, required this.since});

  final SourceRow source;
  final DateTime since;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.hs;
    final days = DateTime.now().difference(since).inDays;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border.all(color: palette.stroke),
        borderRadius: HsRadius.cardBorder,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            days < 1
                ? 'This feed did not respond on the last check'
                : 'This feed has not responded for '
                      '$days ${days == 1 ? 'day' : 'days'}',
            style: HsType.statTitle.copyWith(color: palette.textPrimary),
          ),
          const SizedBox(height: HsSpace.x3),
          Text(
            '${source.lastError ?? 'The address did not answer.'} '
            'The publisher may have moved it. Nothing from here appears in '
            'Today until it is fixed, and the app will stop retrying after '
            'fourteen days.',
            style: HsType.note.copyWith(color: palette.textSecondary),
          ),
          const SizedBox(height: HsSpace.x4),
          HsButton(
            'Look for a new feed address',
            onPressed: () => context.push('/sources/add-url'),
            height: HsSize.buttonSmall,
          ),
          const SizedBox(height: HsSpace.x2),
          HsButton(
            'Try again now',
            onPressed: () => ref.read(refreshProvider.notifier).refresh(),
            kind: HsButtonKind.secondary,
            height: HsSize.buttonSmall,
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const new({
    required this.label,
    this.trailing,
    this.onTap,
    this.muted = false,
    this.divider = true,
  });

  final String label;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool muted;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    final palette = context.hs;
    return Pressable(
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: divider
              ? Border(bottom: BorderSide(color: palette.divider))
              : null,
        ),
        child: SizedBox(
          height: 54,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: HsType.bodySans.copyWith(
                    height: 1,
                    color: muted ? palette.textSecondary : palette.textPrimary,
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
        ),
      ),
    );
  }
}
