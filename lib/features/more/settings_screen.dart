import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:headshorts/app/settings_controller.dart';
import 'package:headshorts/core/motion/haptics.dart';
import 'package:headshorts/core/tokens/dimensions.dart';
import 'package:headshorts/core/widgets/controls.dart';
import 'package:headshorts/core/widgets/sheet.dart';
import 'package:headshorts/data/prefs/settings.dart';
import 'package:headshorts/features/more/settings_widgets.dart';
import 'package:headshorts/features/more/text_size_sheet.dart';

/// Every setting, on one page behind More's Settings row. Colours live on
/// Theme and the floating header on Header; the rest are here. A one-of-N
/// setting shows its value under its title and opens a sheet. Nothing cycles
/// in place, and each row watches only the setting it shows.
class SettingsScreen extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) => SettingsScaffold(
    title: 'Settings',
    children: [
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
            onTap: (context, _, _) => showTextSizeSheet(context),
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
                await ref.read(settingsProvider.notifier).setListSize(picked);
              }
            },
          ),
        ],
      ),
      SettingsGroup(
        label: 'Reading',
        children: [
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
                    description: 'Your own browser, extensions and sign-ins',
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
                await ref.read(settingsProvider.notifier).setSpeechRate(picked);
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
        ],
      ),
      SettingsGroup(
        label: 'Phone',
        children: [
          const _HapticsRow(),
          SettingsRow(
            icon: Icons.widgets_outlined,
            label: 'Home screen widget',
            sub: 'Choose the sources it shows',
            onTap: () => context.push('/widget'),
          ),
        ],
      ),
      const SizedBox(height: HsSpace.x5),
    ],
  );
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

/// On or off. The whole row takes the tap, once; the switch is drawn but
/// inert, so a press on it is not a second target.
class _HapticsRow extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final on = ref.watch(settingsProvider.select((s) => s.haptics));
    return Semantics(
      toggled: on,
      child: SettingsRow(
        icon: Icons.vibration_rounded,
        label: 'Haptics',
        sub: 'A light tap when you pick something',
        chevron: false,
        trailing: ExcludeSemantics(
          child: IgnorePointer(
            child: HsToggle(value: on, onChanged: (_) {}),
          ),
        ),
        onTap: () {
          // Tick on the way to on only: turning haptics off stays silent.
          if (!on) HsHaptics.tick();
          unawaited(
            ref.read(settingsProvider.notifier).setHaptics(enabled: !on),
          );
        },
      ),
    );
  }
}
