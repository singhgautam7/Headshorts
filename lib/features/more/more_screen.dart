import 'dart:convert';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:headshorts/app/providers.dart';
import 'package:headshorts/app/settings_controller.dart';
import 'package:headshorts/core/theme/hs_theme.dart';
import 'package:headshorts/core/tokens/dimensions.dart';
import 'package:headshorts/core/tokens/typography.dart';
import 'package:headshorts/core/widgets/controls.dart';
import 'package:headshorts/core/widgets/glyphs.dart';
import 'package:headshorts/core/widgets/screen.dart';
import 'package:headshorts/data/prefs/settings.dart';
import 'package:headshorts/data/sources/opml.dart';

/// More — the settings hub.
class MoreScreen extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final controller = ref.read(settingsProvider.notifier);

    return HsScreen(
      title: 'More',
      titlePadding: const EdgeInsets.fromLTRB(HsSpace.x5, 6, HsSpace.x5, 20),
      child: ListView(
        padding: const EdgeInsets.only(bottom: HsSpace.navClearance),
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: HsSpace.x5),
            child: SectionLabel('Appearance'),
          ),
          const SizedBox(height: HsSpace.x3),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: HsSpace.x5),
            child: SegmentedControl<HsThemeChoice>(
              value: settings.theme,
              options: const {
                HsThemeChoice.amoled: 'AMOLED',
                HsThemeChoice.white: 'White',
                HsThemeChoice.system: 'System',
              },
              onChanged: controller.setTheme,
            ),
          ),
          const SizedBox(height: HsSpace.x3),
          SettingsRow(
            label: 'Blur behind the nav',
            sub: settings.blurBehindNav
                ? 'On — costs battery'
                : 'Off — costs battery, opaque by default',
            trailing: HsToggle(
              value: settings.blurBehindNav,
              onChanged: (v) => controller.setBlurBehindNav(enabled: v),
            ),
          ),
          const SizedBox(height: 26),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: HsSpace.x5),
            child: SectionLabel('Reading'),
          ),
          const SizedBox(height: HsSpace.x3),
          SettingsRow(
            label: 'Stats',
            chevron: true,
            onTap: () => context.push('/stats'),
          ),
          SettingsRow(
            label: 'Text size',
            value: settings.textSize.label,
            chevron: true,
            onTap: () => context.push('/more/text-size'),
          ),
          SettingsRow(
            label: 'AI summaries',
            sub: 'Later phase · bring your own key',
            chevron: true,
            onTap: () => context.push('/more/ai'),
          ),
          const SizedBox(height: 26),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: HsSpace.x5),
            child: SectionLabel('About'),
          ),
          const SizedBox(height: HsSpace.x3),
          SettingsRow(
            label: 'Privacy',
            chevron: true,
            onTap: () => context.push('/more/privacy'),
          ),
          SettingsRow(
            label: 'Export OPML',
            chevron: true,
            onTap: () => _exportOpml(context, ref),
          ),
          SettingsRow(
            label: 'About HeadShorts',
            value: '1.0',
            divider: false,
            onTap: () => context.push('/more/about'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportOpml(BuildContext context, WidgetRef ref) async {
    final sources = await ref.read(sourceRepositoryProvider).all();
    final location = await getSaveLocation(
      suggestedName: 'headshorts.opml',
      acceptedTypeGroups: const [
        XTypeGroup(label: 'OPML', extensions: ['opml']),
      ],
    );
    if (location == null) return;
    await XFile.fromData(
      Uint8List.fromList(utf8.encode(Opml.write(sources))),
      mimeType: 'text/xml',
    ).saveTo(location.path);
  }
}

/// A row on the More screen.
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
