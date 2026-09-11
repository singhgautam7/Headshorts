import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:headshorts/core/theme/hs_theme.dart';
import 'package:headshorts/core/tokens/dimensions.dart';
import 'package:headshorts/core/tokens/typography.dart';
import 'package:headshorts/core/widgets/controls.dart';
import 'package:headshorts/core/widgets/glyphs.dart';
import 'package:headshorts/core/widgets/screen.dart';
import 'package:headshorts/features/today/today_controller.dart';

/// More — a hub, not a settings page.
///
/// Five destinations and a sign-off. Settings is one of them rather than the
/// whole tab, so Stats, AI summaries and the two text pages are not buried
/// under a heading that does not describe them.
class MoreScreen extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => HsScreen(
    title: 'More',
    titlePadding: const EdgeInsets.fromLTRB(HsSpace.x5, 6, HsSpace.x5, 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(bottom: HsSpace.x5),
            children: [
              SettingsRow(
                label: 'Stats',
                sub: 'What you have read, with nothing to beat',
                chevron: true,
                onTap: () => context.push('/stats'),
              ),
              SettingsRow(
                label: 'Settings',
                sub: _settingsSummary(ref),
                chevron: true,
                onTap: () => context.push('/more/settings'),
              ),
              SettingsRow(
                label: 'AI summaries',
                sub: 'Beta · bring your own key',
                chevron: true,
                onTap: () => context.push('/more/ai'),
              ),
              SettingsRow(
                label: 'About',
                value: '1.0',
                chevron: true,
                onTap: () => context.push('/more/about'),
              ),
              SettingsRow(
                label: 'Privacy',
                sub: 'No account, no analytics, no server',
                chevron: true,
                divider: false,
                onTap: () => context.push('/more/privacy'),
              ),
            ],
          ),
        ),
        const _MadeIn(),
      ],
    ),
  );

  /// One line of what Settings currently holds, so the row says something
  /// rather than only pointing somewhere.
  static String _settingsSummary(WidgetRef ref) {
    final sources = ref.watch(sourcesProvider).value ?? const [];
    final enabled = sources.where((s) => s.enabled).length;
    return enabled == 0
        ? 'Appearance, reading, sources and data'
        : 'Appearance, reading, data · $enabled '
              '${enabled == 1 ? 'source' : 'sources'} on';
  }
}

/// Pinned at the foot of the hub. Muted, centred, and the only decoration in
/// the app that is not doing a job.
class _MadeIn extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(
      top: HsSpace.x4,
      bottom: HsSpace.navClearance,
    ),
    child: Text(
      'Made with \u2764\ufe0f in India',
      textAlign: TextAlign.center,
      style: HsType.note.copyWith(color: context.hs.textMuted),
    ),
  );
}

const clearCacheExplainer =
    'Every article currently stored on the device is removed, along with what '
    'you have read. Your sources and settings stay exactly as they are, and '
    'the next refresh fills the briefing again.';

class SettingsRow extends StatelessWidget {
  const new({
    required this.label,
    this.sub,
    this.value,
    this.trailing,
    this.onTap,
    this.chevron = false,
    this.divider = true,
    super.key,
  });

  final String label;
  final String? sub;
  final String? value;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool chevron;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    final palette = context.hs;
    final subtitle = sub;
    final trailingValue = value;

    return Pressable(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: HsSpace.x5),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: divider
                ? Border(bottom: BorderSide(color: palette.divider))
                : null,
          ),
          child: SizedBox(
            height: HsSize.settingsRowHeight,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        label,
                        style: HsType.row.copyWith(color: palette.textPrimary),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          style: HsType.rowSub.copyWith(
                            color: palette.textMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailingValue != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: Text(
                      trailingValue,
                      style: HsType.rowValue.copyWith(color: palette.textMuted),
                    ),
                  ),
                ?trailing,
                if (chevron)
                  HsGlyph.chevron(
                    palette.textMuted,
                    direction: AxisDirection.right,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The three-way segmented control used for theme and AI provider.
class SegmentedControl<T> extends StatelessWidget {
  const new({
    required this.value,
    required this.options,
    required this.onChanged,
    super.key,
  });

  final T value;
  final Map<T, String> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.hs;
    return Container(
      padding: const EdgeInsets.all(HsSpace.x1),
      decoration: BoxDecoration(
        color: palette.isDark ? palette.surface : palette.surfaceVariant,
        borderRadius: HsRadius.buttonBorder,
      ),
      child: Row(
        children: [
          for (final entry in options.entries)
            Expanded(
              child: Pressable(
                onTap: () => onChanged(entry.key),
                child: Container(
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: entry.key == value
                        ? (palette.isDark ? palette.navActive : palette.nav)
                        : null,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    entry.value,
                    style:
                        (entry.key == value ? HsType.chipSelected : HsType.chip)
                            .copyWith(
                              color: entry.key == value
                                  ? palette.textPrimary
                                  : palette.textMuted,
                            ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
