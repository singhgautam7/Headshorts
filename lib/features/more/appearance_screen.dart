import 'dart:async';

import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:headshorts/app/settings_controller.dart';
import 'package:headshorts/core/theme/hs_theme.dart';
import 'package:headshorts/core/tokens/dimensions.dart';
import 'package:headshorts/core/tokens/motion.dart';
import 'package:headshorts/core/tokens/palette.dart';
import 'package:headshorts/core/tokens/theme_family.dart';
import 'package:headshorts/core/tokens/typography.dart';
import 'package:headshorts/core/widgets/controls.dart';
import 'package:headshorts/core/widgets/glyphs.dart';
import 'package:headshorts/features/more/more_screen.dart';

/// Appearance, in Perch's arrangement: Light / Dark / System is the mode
/// switch, AMOLED is a true-black toggle that appears only while dark is in
/// effect, and every family is drawn as a miniature of the app so the choice
/// is made on the thing itself rather than on swatches.
class AppearanceScreen extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final controller = ref.read(settingsProvider.notifier);
    final darkInEffect =
        s.themeMode == ThemeMode.dark ||
        (s.themeMode == ThemeMode.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.dark);
    final tone = !darkInEffect
        ? Tone.light
        : s.amoled
        ? Tone.amoled
        : Tone.dark;

    return SettingsScaffold(
      title: 'Appearance',
      children: [
        SegmentedControl<ThemeMode>(
          value: s.themeMode,
          options: const {
            ThemeMode.light: 'Light',
            ThemeMode.dark: 'Dark',
            ThemeMode.system: 'System',
          },
          onChanged: controller.setThemeMode,
        ),
        const SizedBox(height: HsSpace.x4),
        if (darkInEffect)
          SettingsGroup(
            label: 'Dark',
            children: [
              SettingsRow(
                label: 'True black',
                sub: 'AMOLED: the page ground goes to pure black',
                trailing: HsToggle(
                  value: s.amoled,
                  onChanged: (v) => unawaited(controller.setAmoled(value: v)),
                ),
              ),
            ],
          ),
        SettingsGroup(
          label: 'Theme',
          children: [
            for (final family in ThemeFamily.all)
              _FamilyRow(
                family: family,
                palette: family.colors(tone),
                selected: family.id == s.familyId,
                onTap: () => unawaited(controller.setFamily(family.id)),
              ),
          ],
        ),
        SettingsGroup(
          label: 'Rendering',
          children: [
            SettingsRow(
              label: 'Blur behind the nav',
              sub: 'Prettier, slightly heavier on battery',
              trailing: HsToggle(
                value: s.blurBehindNav,
                onChanged: (v) => controller.setBlurBehindNav(enabled: v),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// One family: a miniature of the app in that theme, its name, and a tick.
class _FamilyRow extends StatelessWidget {
  const new({
    required this.family,
    required this.palette,
    required this.selected,
    required this.onTap,
  });

  final ThemeFamily family;
  final HsPalette palette;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final current = context.hs;
    return Semantics(
      button: true,
      selected: selected,
      label: '${family.name} theme',
      child: Pressable(
        onTap: onTap,
        child: AnimatedContainer(
          duration: HsMotion.micro,
          curve: HsMotion.microCurve,
          color: selected ? current.primaryContainer : null,
          padding: const EdgeInsets.symmetric(
            horizontal: HsSpace.x4,
            vertical: HsSpace.x3,
          ),
          child: Row(
            children: [
              _Miniature(palette: palette),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      family.name,
                      style: HsType.row.copyWith(
                        color: selected
                            ? current.onPrimaryContainer
                            : current.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      family.blurb,
                      style: HsType.rowSub.copyWith(
                        color: selected
                            ? current.onPrimaryContainer
                            : current.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected) HsGlyph.tick(current.onPrimaryContainer),
            ],
          ),
        ),
      ),
    );
  }
}

/// A miniature of the app in a palette: title bar, a row, the nav pill.
class _Miniature extends StatelessWidget {
  const new({required this.palette});

  final HsPalette palette;

  @override
  Widget build(BuildContext context) {
    final p = palette;
    Widget bar(double width, double height, Color color) => Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(2),
      ),
    );

    return Container(
      width: 78,
      height: 62,
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: p.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: p.stroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          bar(26, 5, p.textPrimary),
          const SizedBox(height: 6),
          Container(
            height: 18,
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: p.stroke),
            ),
          ),
          const Spacer(),
          Row(
            children: [
              Container(
                height: 10,
                width: 22,
                decoration: BoxDecoration(
                  color: p.primaryContainer,
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
              const SizedBox(width: 3),
              bar(6, 6, p.textMuted),
              const SizedBox(width: 3),
              bar(6, 6, p.textMuted),
              const Spacer(),
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: p.primary,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
