import 'dart:async';

import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:headshorts/app/settings_controller.dart';
import 'package:headshorts/core/motion/motion_level.dart';
import 'package:headshorts/core/motion/theme_ripple.dart';
import 'package:headshorts/core/theme/hs_theme.dart';
import 'package:headshorts/core/tokens/dimensions.dart';
import 'package:headshorts/core/tokens/motion.dart';
import 'package:headshorts/core/tokens/palette.dart';
import 'package:headshorts/core/tokens/theme_family.dart';
import 'package:headshorts/core/tokens/typography.dart';
import 'package:headshorts/core/widgets/controls.dart';
import 'package:headshorts/core/widgets/glyphs.dart';
import 'package:headshorts/core/widgets/sheet.dart';
import 'package:headshorts/features/more/more_screen.dart';

/// Appearance, in Perch's arrangement: Light / Dark / System is the mode
/// switch, AMOLED is a true-black toggle that appears only while dark is in
/// effect, and every family is drawn as a miniature of the app so the choice
/// is made on the thing itself rather than on swatches.
class AppearanceScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<AppearanceScreen> createState() => _AppearanceScreenState();
}

class _AppearanceScreenState extends ConsumerState<AppearanceScreen> {
  /// Where the last pointer went down: the theme ripple grows from there.
  Offset _down = Offset.zero;

  /// Every theme control goes through here, so the change is revealed from
  /// the finger rather than swapped under it.
  void _reveal(FutureOr<void> Function() apply) =>
      unawaited(ThemeRipple.of(context).run(_down, apply));

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(settingsProvider.select((s) => s.themeMode));
    final amoled = ref.watch(settingsProvider.select((s) => s.amoled));
    final familyId = ref.watch(settingsProvider.select((s) => s.familyId));
    final blur = ref.watch(settingsProvider.select((s) => s.blurBehindNav));
    final motion = ref.watch(
      settingsProvider.select((s) => s.motionPreference),
    );
    final haptics = ref.watch(settingsProvider.select((s) => s.haptics));
    final controller = ref.read(settingsProvider.notifier);
    final darkInEffect =
        themeMode == ThemeMode.dark ||
        (themeMode == ThemeMode.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.dark);
    final tone = !darkInEffect
        ? Tone.light
        : amoled
        ? Tone.amoled
        : Tone.dark;

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (e) => _down = e.position,
      child: SettingsScaffold(
        title: 'Appearance',
        children: [
          SegmentedControl<ThemeMode>(
            value: themeMode,
            options: const {
              ThemeMode.light: 'Light',
              ThemeMode.dark: 'Dark',
              ThemeMode.system: 'System',
            },
            onChanged: (m) => _reveal(() => controller.setThemeMode(m)),
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
                    value: amoled,
                    onChanged: (v) =>
                        _reveal(() => controller.setAmoled(value: v)),
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
                  selected: family.id == familyId,
                  onTap: () => _reveal(() => controller.setFamily(family.id)),
                ),
            ],
          ),
          SettingsGroup(
            label: 'Motion',
            children: [
              SettingsRow(
                label: 'Motion',
                sub: systemMotionOff(context)
                    ? 'Off while your phone removes animations'
                    : null,
                value: motion.label,
                onTap: () async {
                  final picked = await showOptionSheet<MotionPreference>(
                    context,
                    title: 'Motion',
                    selected: motion,
                    options: [
                      for (final p in MotionPreference.values)
                        SheetOption(
                          value: p,
                          label: p.label,
                          description: p.description,
                        ),
                    ],
                  );
                  if (picked != null) {
                    await controller.setMotionPreference(picked);
                  }
                },
              ),
              SettingsRow(
                label: 'Haptics',
                sub: 'A light tap when you pick something',
                trailing: HsToggle(
                  value: haptics,
                  onChanged: (v) =>
                      unawaited(controller.setHaptics(enabled: v)),
                ),
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
                  value: blur,
                  onChanged: (v) => controller.setBlurBehindNav(enabled: v),
                ),
              ),
            ],
          ),
        ],
      ),
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
