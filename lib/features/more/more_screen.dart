import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:headshorts/app/settings_controller.dart';
import 'package:headshorts/core/theme/hs_theme.dart';
import 'package:headshorts/core/tokens/dimensions.dart';
import 'package:headshorts/core/tokens/typography.dart';
import 'package:headshorts/core/widgets/controls.dart';
import 'package:headshorts/core/widgets/screen.dart';
import 'package:headshorts/core/widgets/sheet.dart';
import 'package:headshorts/data/prefs/settings.dart';
import 'package:headshorts/features/more/settings_widgets.dart';
import 'package:package_info_plus/package_info_plus.dart';

export 'settings_widgets.dart';

/// More — three short groups in Perch's arrangement, each row showing its
/// current value on the right so most questions are answered without opening
/// anything. A one-of-N setting opens the shared option sheet; nothing here
/// cycles in place.
class MoreScreen extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final controller = ref.read(settingsProvider.notifier);
    final version = ref.watch(packageInfoProvider).value?.version;

    return HsScreen(
      title: 'More',
      titlePadding: const EdgeInsets.fromLTRB(HsSpace.x5, 6, HsSpace.x5, 18),
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: HsSpace.x5),
        children: [
          SettingsGroup(
            label: 'General',
            children: [
              SettingsRow(
                icon: Icons.palette_outlined,
                label: 'Appearance',
                value: '${s.family.name} · ${_modeLabel(s.themeMode)}',
                onTap: () => context.push('/more/appearance'),
              ),
              SettingsRow(
                icon: Icons.open_in_browser_rounded,
                label: 'Open links',
                value: s.linkOpenMode.label,
                onTap: () async {
                  final picked = await showOptionSheet<LinkOpenMode>(
                    context,
                    title: 'Open links',
                    description:
                        'Where an article opens when you leave the '
                        'Reader for the publisher.',
                    selected: s.linkOpenMode,
                    options: const [
                      SheetOption(
                        value: LinkOpenMode.inApp,
                        label: 'In the app',
                        description: 'A Custom Tab over HeadShorts — you come straight back',
                      ),
                      SheetOption(
                        value: LinkOpenMode.browser,
                        label: 'In your browser',
                        description:
                            'Your own browser, extensions and sign-ins',
                      ),
                    ],
                  );
                  if (picked != null) await controller.setLinkOpenMode(picked);
                },
              ),
              SettingsRow(
                icon: Icons.format_size_rounded,
                label: 'Text size',
                value: s.textSize.label,
                onTap: () async {
                  final picked = await showOptionSheet<TextSizeStep>(
                    context,
                    title: 'Text size',
                    description:
                        "The Reader's measure. It offsets the system setting "
                        'rather than overriding it.',
                    selected: s.textSize,
                    options: [
                      for (final step in TextSizeStep.values)
                        SheetOption(value: step, label: step.label),
                    ],
                  );
                  if (picked != null) await controller.setTextSize(picked);
                },
              ),
              SettingsRow(
                icon: Icons.balance_rounded,
                label: 'Reading fairness',
                value: s.maxConsecutivePerSource == 0
                    ? 'Off'
                    : '${s.maxConsecutivePerSource} in a row',
                onTap: () async {
                  final picked = await showOptionSheet<int>(
                    context,
                    title: 'Reading fairness',
                    description:
                        'Caps how many items in a row one source can take. '
                        'Nothing is dropped or scored — an item that would '
                        'exceed the run waits for something from elsewhere.',
                    selected: s.maxConsecutivePerSource,
                    options: const [
                      SheetOption(
                        value: 0,
                        label: 'Off',
                        description: 'Strictly newest first',
                      ),
                      SheetOption(value: 3, label: 'At most 3 in a row'),
                      SheetOption(value: 5, label: 'At most 5 in a row'),
                      SheetOption(value: 8, label: 'At most 8 in a row'),
                    ],
                  );
                  if (picked != null) {
                    await controller.setMaxConsecutivePerSource(picked);
                  }
                },
              ),
              SettingsRow(
                icon: Icons.update_rounded,
                label: 'Check for new',
                value: s.refreshCadence.label,
                onTap: () async {
                  final picked = await showOptionSheet<RefreshCadence>(
                    context,
                    title: 'Check for new',
                    description:
                        'How stale the briefing may be before opening the app '
                        'or returning to it fetches again. A pull always does.',
                    selected: s.refreshCadence,
                    options: [
                      for (final c in RefreshCadence.values)
                        SheetOption(value: c, label: c.label),
                    ],
                  );
                  if (picked != null) {
                    await controller.setRefreshCadence(picked);
                  }
                },
              ),
            ],
          ),
          SettingsGroup(
            label: 'Your data',
            children: [
              SettingsRow(
                icon: Icons.bar_chart_rounded,
                label: 'Stats',
                sub: 'What you have read, with nothing to beat',
                onTap: () => context.push('/stats'),
              ),
              SettingsRow(
                icon: Icons.swap_vert_rounded,
                label: 'Data',
                sub: 'Export, import and clear',
                onTap: () => context.push('/more/data'),
              ),
              SettingsRow(
                icon: Icons.key_outlined,
                label: 'Permissions',
                sub: 'What HeadShorts asks for, and what it does not',
                onTap: () => context.push('/more/permissions'),
              ),
            ],
          ),
          SettingsGroup(
            label: 'About HeadShorts',
            children: [
              SettingsRow(
                icon: Icons.shield_outlined,
                label: 'Privacy',
                value: 'Local only',
                onTap: () => context.push('/more/privacy'),
              ),
              SettingsRow(
                icon: Icons.auto_awesome_outlined,
                label: 'AI summaries',
                value: 'Coming soon',
                onTap: () => context.push('/more/ai'),
              ),
              SettingsRow(
                icon: Icons.info_outline_rounded,
                label: 'About',
                value: version,
                onTap: () => context.push('/more/about'),
              ),
            ],
          ),
          const VersionLine(),
          const _MadeIn(),
        ],
      ),
    );
  }

  static String _modeLabel(ThemeMode mode) => switch (mode) {
    ThemeMode.light => 'Light',
    ThemeMode.dark => 'Dark',
    ThemeMode.system => 'System',
  };
}

/// The installed package's version and build, resolved once and cached: a
/// `FutureBuilder` in `build` would re-read the platform on every rebuild.
final packageInfoProvider = FutureProvider<PackageInfo>(
  (ref) => PackageInfo.fromPlatform(),
);

/// `HeadShorts 0.1.0 · build 1` — never hardcoded.
class VersionLine extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = ref.watch(packageInfoProvider).value;
    return Text(
      info == null
          ? 'HeadShorts'
          : 'HeadShorts ${info.version} · build ${info.buildNumber}',
      textAlign: TextAlign.center,
      style: HsType.note.copyWith(color: context.hs.textMuted),
    );
  }
}

/// Pinned at the foot of the hub. Muted, centred, and the only decoration in
/// the app that is not doing a job.
class _MadeIn extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(
      top: HsSpace.x1,
      bottom: HsSpace.navClearance,
    ),
    child: Text(
      'Made with \u2764\ufe0f in India',
      textAlign: TextAlign.center,
      style: HsType.note.copyWith(color: context.hs.textMuted),
    ),
  );
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
