import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:headshorts/app/settings_controller.dart';
import 'package:headshorts/core/motion/haptics.dart';
import 'package:headshorts/core/motion/motion_level.dart';
import 'package:headshorts/core/theme/hs_theme.dart';
import 'package:headshorts/core/tokens/dimensions.dart';
import 'package:headshorts/core/tokens/typography.dart';
import 'package:headshorts/core/widgets/app_header.dart';
import 'package:headshorts/core/widgets/controls.dart';
import 'package:headshorts/core/widgets/screen.dart';
import 'package:headshorts/core/widgets/sheet.dart';
import 'package:headshorts/data/prefs/settings.dart';
import 'package:headshorts/features/more/settings_widgets.dart';
import 'package:headshorts/features/more/stats_card.dart';
import 'package:package_info_plus/package_info_plus.dart';

export 'segmented_control.dart';
export 'settings_widgets.dart';

/// More: the stats card leads, then Kuber's groups (Saved, Look, Behaviour,
/// Your data, About), one list. Every setting lives on exactly one page: the
/// one-of-N ones here, colours on Theme, the floating header on Header. A row
/// is a tile, a title and what it holds beneath it; a one-of-N setting puts its
/// current value there and opens the shared option sheet. Nothing cycles in
/// place.
///
/// Every row is its own small widget watching only the setting it shows, so a
/// change rebuilds that row and nothing else.
class MoreScreen extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    return HsScreen(
      title: 'More',
      underHeader: true,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: HsSpace.x5),
        children: [
          HeaderPage.gap(),
          const Padding(
            padding: EdgeInsets.only(bottom: HsSpace.x5),
            child: StatsCard(),
          ),
          SettingsGroup(
            label: 'Saved',
            children: [
              SettingsRow(
                icon: Icons.bookmark_border_rounded,
                label: 'Bookmarks',
                sub: 'Articles you kept to read later',
                onTap: () => context.push('/bookmarks'),
              ),
            ],
          ),
          SettingsGroup(
            label: 'Look',
            children: [
              SettingsRow(
                icon: Icons.palette_outlined,
                label: 'Theme',
                sub: 'Colours, light and dark, pure black',
                onTap: () => context.push('/more/appearance'),
              ),
              SettingsRow(
                icon: Icons.vertical_align_top_rounded,
                label: 'Header',
                sub: 'Floating header and when it shows',
                onTap: () => context.push('/more/header'),
              ),
              _SettingRow<TextSizeStep>(
                icon: Icons.format_size_rounded,
                label: 'Text size',
                select: (s) => s.textSize,
                subtitle: (v) => v.label,
                onTap: (context, ref, current) async {
                  final picked = await showOptionSheet<TextSizeStep>(
                    context,
                    title: 'Text size',
                    description:
                        "The Reader's measure. It offsets the system setting "
                        'rather than overriding it.',
                    selected: current,
                    options: [
                      for (final step in TextSizeStep.values)
                        SheetOption(value: step, label: step.label),
                    ],
                  );
                  if (picked != null) {
                    await ref
                        .read(settingsProvider.notifier)
                        .setTextSize(picked);
                  }
                },
              ),
              _SettingRow<ListSize>(
                icon: Icons.view_agenda_outlined,
                label: 'List size',
                select: (s) => s.listSize,
                subtitle: (v) => v.label,
                onTap: (context, ref, current) async {
                  final picked = await showOptionSheet<ListSize>(
                    context,
                    title: 'List size',
                    description:
                        'How much of each item Headlines, Search and '
                        'Bookmarks show. Headlines also has this beside its '
                        'title.',
                    selected: current,
                    options: [
                      for (final size in ListSize.values)
                        SheetOption(
                          value: size,
                          label: size.label,
                          description: size.description,
                        ),
                    ],
                  );
                  if (picked != null) {
                    await ref
                        .read(settingsProvider.notifier)
                        .setListSize(picked);
                  }
                },
              ),
              const _MotionRow(),
            ],
          ),
          SettingsGroup(
            label: 'Behaviour',
            children: [
              const _ToggleRow(
                icon: Icons.vibration_rounded,
                label: 'Haptics',
                sub: 'A light tap when you pick something',
                kind: _Toggle.haptics,
              ),
              const _ToggleRow(
                icon: Icons.blur_on_rounded,
                label: 'Blur behind the nav',
                sub: 'Prettier, slightly heavier on battery',
                kind: _Toggle.blur,
              ),
              _SettingRow<LinkOpenMode>(
                icon: Icons.open_in_browser_rounded,
                label: 'Open links',
                select: (s) => s.linkOpenMode,
                subtitle: (v) => v.label,
                onTap: (context, ref, current) async {
                  final picked = await showOptionSheet<LinkOpenMode>(
                    context,
                    title: 'Open links',
                    description:
                        'Where an article opens when you leave the '
                        'Reader for the publisher.',
                    selected: current,
                    options: const [
                      SheetOption(
                        value: LinkOpenMode.inApp,
                        label: 'In the app',
                        description:
                            'A Custom Tab over HeadShorts, so you come '
                            'straight back',
                      ),
                      SheetOption(
                        value: LinkOpenMode.browser,
                        label: 'In your browser',
                        description:
                            'Your own browser, extensions and sign-ins',
                      ),
                    ],
                  );
                  if (picked != null) {
                    await ref
                        .read(settingsProvider.notifier)
                        .setLinkOpenMode(picked);
                  }
                },
              ),
              _SettingRow<(SpeechRate, bool)>(
                icon: Icons.volume_up_outlined,
                label: 'Read aloud',
                select: (s) => (s.speechRate, s.voiceByLanguage.isEmpty),
                subtitle: (v) =>
                    '${v.$1.label} \u00b7 ${v.$2 ? 'System voice' : 'Your voice'}',
                onTap: (context, ref, current) async {
                  final picked = await showOptionSheet<SpeechRate>(
                    context,
                    title: 'Read aloud',
                    description:
                        "Speed for the Reader's Listen. The voice is chosen "
                        'per language while it reads, and remembered.',
                    selected: current.$1,
                    options: [
                      for (final rate in SpeechRate.values)
                        SheetOption(value: rate, label: rate.label),
                    ],
                  );
                  if (picked != null) {
                    await ref
                        .read(settingsProvider.notifier)
                        .setSpeechRate(picked);
                  }
                },
              ),
              _SettingRow<bool>(
                icon: Icons.travel_explore_rounded,
                label: 'Search the web',
                select: (s) => s.searchTheWeb,
                subtitle: (v) => v ? 'Google News' : 'Off',
                onTap: (context, ref, current) async {
                  final picked = await showOptionSheet<bool>(
                    context,
                    title: 'Search the web',
                    description:
                        'Your own feeds carry only their most recent items, '
                        'so a search of them alone cannot reach far back. '
                        'With this on, Search also asks Google News and '
                        'shows what it finds under its own heading.',
                    selected: current,
                    options: const [
                      SheetOption(
                        value: true,
                        label: 'Also search Google News',
                        description:
                            'Your search term is sent to Google. Nothing '
                            'else is: not what you read, follow or save',
                      ),
                      SheetOption(
                        value: false,
                        label: 'Off',
                        description:
                            'Search only what is on this device. Nothing '
                            'leaves it',
                      ),
                    ],
                  );
                  if (picked != null) {
                    await ref
                        .read(settingsProvider.notifier)
                        .setSearchTheWeb(enabled: picked);
                  }
                },
              ),
              _SettingRow<int>(
                icon: Icons.balance_rounded,
                label: 'Reading fairness',
                select: (s) => s.maxConsecutivePerSource,
                subtitle: (v) => v == 0 ? 'Off' : '$v in a row',
                onTap: (context, ref, current) async {
                  final picked = await showOptionSheet<int>(
                    context,
                    title: 'Reading fairness',
                    description:
                        'Caps how many items in a row one source can take. '
                        'Nothing is dropped or scored. An item that would '
                        'exceed the run waits for something from elsewhere.',
                    selected: current,
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
                    await ref
                        .read(settingsProvider.notifier)
                        .setMaxConsecutivePerSource(picked);
                  }
                },
              ),
              _SettingRow<RefreshCadence>(
                icon: Icons.update_rounded,
                label: 'Check for new',
                select: (s) => s.refreshCadence,
                subtitle: (v) => v.label,
                onTap: (context, ref, current) async {
                  final picked = await showOptionSheet<RefreshCadence>(
                    context,
                    title: 'Check for new',
                    description:
                        'How stale the briefing may be before opening the app '
                        'or returning to it fetches again. A pull always does.',
                    selected: current,
                    options: [
                      for (final c in RefreshCadence.values)
                        SheetOption(value: c, label: c.label),
                    ],
                  );
                  if (picked != null) {
                    await ref
                        .read(settingsProvider.notifier)
                        .setRefreshCadence(picked);
                  }
                },
              ),
              SettingsRow(
                icon: Icons.widgets_outlined,
                label: 'Home screen widget',
                sub: 'Choose the sources it shows',
                onTap: () => context.push('/widget'),
              ),
            ],
          ),
          SettingsGroup(
            label: 'Your data',
            children: [
              SettingsRow(
                icon: Icons.swap_vert_rounded,
                label: 'Data',
                sub: 'Export, import and clear',
                onTap: () => context.push('/more/data'),
              ),
              SettingsRow(
                icon: Icons.key_outlined,
                label: 'Permissions',
                sub: 'What HeadShorts asks for',
                onTap: () => context.push('/more/permissions'),
              ),
            ],
          ),
          SettingsGroup(
            label: 'About HeadShorts',
            children: [
              SettingsRow(
                icon: Icons.mail_outline_rounded,
                label: 'Contact us',
                sub: 'singhgautam.dev@gmail.com',
                onTap: () => context.push('/more/contact'),
              ),
              SettingsRow(
                icon: Icons.shield_outlined,
                label: 'Privacy',
                sub: 'Everything stays on your phone',
                onTap: () => context.push('/more/privacy'),
              ),
              const _AboutRow(),
            ],
          ),
          const VersionLine(),
          const Padding(
            padding: EdgeInsets.only(
              top: HsSpace.x1,
              bottom: HsSpace.navClearance,
            ),
            child: MadeInIndia(),
          ),
        ],
      ),
    );
  }
}

/// A row showing one setting's current value under its title. It selects
/// only [select]'s result, so it rebuilds when that changes and not before.
class _SettingRow<T> extends ConsumerWidget {
  const new({
    required this.icon,
    required this.label,
    required this.select,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final T Function(Settings) select;
  final String Function(T) subtitle;
  final FutureOr<void> Function(BuildContext, WidgetRef, T) onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(settingsProvider.select(select));
    return SettingsRow(
      icon: icon,
      label: label,
      value: subtitle(value),
      onTap: () => unawaited(Future.sync(() => onTap(context, ref, value))),
    );
  }
}

/// Motion's row: the level in effect, or why it is Off. The phone's Remove
/// animations beats the choice, so the row says so instead of showing a
/// setting that is not being obeyed.
class _MotionRow extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final motion = ref.watch(
      settingsProvider.select((s) => s.motionPreference),
    );
    return SettingsRow(
      icon: Icons.animation_rounded,
      label: 'Motion',
      value: systemMotionOff(context)
          ? 'Off while your phone removes animations'
          : motion.label,
      onTap: () => unawaited(_pick(context, ref, motion)),
    );
  }

  Future<void> _pick(
    BuildContext context,
    WidgetRef ref,
    MotionPreference current,
  ) async {
    final picked = await showOptionSheet<MotionPreference>(
      context,
      title: 'Motion',
      selected: current,
      options: [
        for (final p in MotionPreference.values)
          SheetOption(value: p, label: p.label, description: p.description),
      ],
    );
    if (picked != null) {
      await ref.read(settingsProvider.notifier).setMotionPreference(picked);
    }
  }
}

enum _Toggle { haptics, blur }

/// An on/off row. The whole row takes the tap, once; the switch is drawn but
/// inert, so a press on it is not a second target.
class _ToggleRow extends ConsumerWidget {
  const new({
    required this.icon,
    required this.label,
    required this.sub,
    required this.kind,
  });

  final IconData icon;
  final String label;
  final String sub;
  final _Toggle kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final on = ref.watch(
      settingsProvider.select(
        (s) => kind == _Toggle.haptics ? s.haptics : s.blurBehindNav,
      ),
    );
    return Semantics(
      toggled: on,
      child: SettingsRow(
        icon: icon,
        label: label,
        sub: sub,
        chevron: false,
        trailing: ExcludeSemantics(
          child: IgnorePointer(
            child: HsToggle(value: on, onChanged: (_) {}),
          ),
        ),
        onTap: () {
          final controller = ref.read(settingsProvider.notifier);
          // Tick on the way to on only: turning haptics off must stay silent.
          if (!on || kind != _Toggle.haptics) HsHaptics.tick();
          unawaited(
            kind == _Toggle.haptics
                ? controller.setHaptics(enabled: !on)
                : controller.setBlurBehindNav(enabled: !on),
          );
        },
      ),
    );
  }
}

class _AboutRow extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final version = ref.watch(
      packageInfoProvider.select((v) => v.value?.version),
    );
    return SettingsRow(
      icon: Icons.info_outline_rounded,
      label: 'About',
      sub: version == null ? 'Why HeadShorts exists' : 'Version $version',
      onTap: () => context.push('/more/about'),
    );
  }
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

/// Made with love in India. Pinned at the foot of the hub and set between
/// the maker's note and the rest of About: muted, centred, and the only
/// decoration in the app that is not doing a job.
class MadeInIndia extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) => Text(
    'Made with \u2764\ufe0f in India',
    textAlign: TextAlign.center,
    style: HsType.note.copyWith(color: context.hs.textMuted),
  );
}
