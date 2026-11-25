import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:headshorts/app/settings_controller.dart';
import 'package:headshorts/app/wallpaper_seed.dart';
import 'package:headshorts/core/motion/theme_ripple.dart';
import 'package:headshorts/core/theme/hs_theme.dart';
import 'package:headshorts/core/tokens/accents.dart';
import 'package:headshorts/core/tokens/dimensions.dart';
import 'package:headshorts/core/tokens/motion.dart';
import 'package:headshorts/core/tokens/palette.dart';
import 'package:headshorts/core/tokens/theme_family.dart';
import 'package:headshorts/core/tokens/typography.dart';
import 'package:headshorts/core/widgets/controls.dart';
import 'package:headshorts/features/more/family_card.dart';
import 'package:headshorts/features/more/segmented_control.dart';
import 'package:headshorts/features/more/settings_widgets.dart';

/// Theme, in Kuber's arrangement: Light / Dark / System, two option cards
/// (Expressive colours, Pure black), every family as a card previewed under
/// the current switches, the wallpaper colour, and a live preview.
///
/// Every control reveals its change from the finger through the theme
/// ripple; the pointer-down lives in state, because a local in `build` would
/// be reset by a rebuild between down and up.
class AppearanceScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<AppearanceScreen> createState() => _AppearanceScreenState();
}

class _AppearanceScreenState extends ConsumerState<AppearanceScreen> {
  Offset _down = Offset.zero;

  void _reveal(FutureOr<void> Function() apply) =>
      unawaited(ThemeRipple.of(context).run(_down, apply));

  @override
  Widget build(BuildContext context) {
    final (themeMode, amoled, familyId, expressive, wallpaperOn) = ref.watch(
      settingsProvider.select(
        (s) => (
          s.themeMode,
          s.amoled,
          s.familyId,
          s.expressiveColors,
          s.wallpaperColor,
        ),
      ),
    );
    final seed = ref.watch(wallpaperSeedProvider).value;
    final controller = ref.read(settingsProvider.notifier);
    final palette = context.hs;

    final light = themeMode == ThemeMode.light;
    final darkInEffect =
        themeMode == ThemeMode.dark ||
        (themeMode == ThemeMode.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.dark);
    // Pure black only acts while dark is in effect; the cards preview the
    // theme as it would actually be drawn.
    final tone = !darkInEffect
        ? Tone.light
        : amoled
        ? Tone.amoled
        : Tone.dark;
    final swatchTone = darkInEffect ? Tone.dark : Tone.light;
    final dynamicOn = wallpaperOn && seed != null;
    final active = ThemeFamily.byId(familyId);
    final lens = dynamicOn ? ThemeFamily.fromSeed(seed) : active;

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (e) => _down = e.position,
      child: SettingsScaffold(
        title: 'Theme',
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
          const SizedBox(height: HsSpace.x3),
          _OptionCard(
            leading: _SplitSwatch(
              // Never the pure-black ramp: both halves are near black there
              // and the swatch would say nothing.
              left: lens.colors(swatchTone).surfaceVariant,
              right: lens.colors(swatchTone, expressive: false).surfaceVariant,
            ),
            title: 'Expressive colours',
            subtitle: 'Backgrounds take a light tint of the theme',
            value: expressive,
            onChanged: (v) =>
                _reveal(() => controller.setExpressiveColors(enabled: v)),
          ),
          const SizedBox(height: HsSpace.x3),
          _OptionCard(
            enabled: !light,
            semanticsLabel: light
                ? 'Pure black, not available in light mode'
                : null,
            leading: Container(
              width: _OptionCard.swatch,
              height: _OptionCard.swatch,
              decoration: BoxDecoration(
                color: HsPalette.amoled.background,
                borderRadius: BorderRadius.circular(_OptionCard.swatchRadius),
                border: Border.all(color: palette.stroke),
              ),
            ),
            title: 'Pure black',
            subtitle:
                'Black background in dark mode. Saves battery on OLED '
                'screens.',
            value: amoled && !light,
            onChanged: (v) => _reveal(() => controller.setAmoled(value: v)),
          ),
          if (themeMode == ThemeMode.system)
            Padding(
              padding: const EdgeInsets.only(left: HsSpace.x4, top: HsSpace.x2),
              child: Row(
                spacing: _OptionCard.helperGap,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: _OptionCard.helperIcon,
                    color: palette.textSecondary,
                  ),
                  Expanded(
                    child: Text(
                      'Pure black applies when your phone is in dark mode',
                      style: HsType.rowSub.copyWith(
                        color: palette.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: HsSpace.x4),
          TwoColumnGrid(
            children: [
              for (final family in ThemeFamily.all)
                FamilyCard(
                  family: family,
                  palette: family.colors(tone, expressive: expressive),
                  selected: !dynamicOn && family == active,
                  onTap: () => _reveal(() async {
                    if (wallpaperOn) {
                      await controller.setWallpaperColor(enabled: false);
                    }
                    await controller.setFamily(family.id);
                  }),
                ),
            ],
          ),
          const SizedBox(height: HsSpace.x4),
          _OptionCard(
            highlighted: dynamicOn,
            enabled: seed != null,
            leading: seed == null
                ? Icon(
                    Icons.wallpaper_rounded,
                    size: _OptionCard.swatch,
                    color: palette.textSecondary,
                  )
                : Row(
                    spacing: HsSpace.x1,
                    children: [
                      ThemeDot(
                        ThemeFamily.fromSeed(seed)
                            .colors(tone, expressive: expressive)
                            .primary,
                        size: _OptionCard.dot,
                      ),
                      ThemeDot(
                        ThemeFamily.fromSeed(seed)
                            .colors(tone, expressive: expressive)
                            .primaryContainer,
                        size: _OptionCard.dot,
                      ),
                    ],
                  ),
            title: 'From your wallpaper',
            subtitle: 'Dynamic colour, Android 12+',
            value: dynamicOn,
            onChanged: seed == null
                ? null
                : (v) =>
                      _reveal(() => controller.setWallpaperColor(enabled: v)),
          ),
          const SizedBox(height: HsSpace.x5),
          const SettingsGroup(label: 'Preview', children: [_Preview()]),
        ],
      ),
    );
  }
}

/// A card with a leading tile, a title and subtitle, and a toggle: Kuber's
/// option row. A disabled one dims its words by 0.38; the toggle dims
/// itself, so the two do not stack.
class _OptionCard extends StatelessWidget {
  const new({
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.enabled = true,
    this.highlighted = false,
    this.semanticsLabel,
  });

  static const swatch = 30.0;
  static const swatchRadius = 9.0;
  static const dot = 26.0;
  static const helperIcon = 14.0;
  static const helperGap = 6.0;
  static const _insetX = 14.0;
  static const _insetY = 12.0;

  final Widget leading;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool enabled;
  final bool highlighted;

  /// Spoken in place of the parts while the card is off limits.
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final palette = context.hs;
    final dim = AnimatedOpacity(
      opacity: enabled ? 1 : 0.38,
      duration: HsMotion.of(context, HsMotion.micro),
      child: Row(
        spacing: HsSpace.x3,
        children: [
          leading,
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: HsType.row.copyWith(color: palette.textPrimary),
                ),
                Text(
                  subtitle,
                  style: HsType.rowSub.copyWith(color: palette.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    final card = Container(
      padding: const EdgeInsets.symmetric(
        horizontal: _insetX,
        vertical: _insetY,
      ),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: HsRadius.cardBorder,
        border: Border.all(
          color: highlighted ? palette.primary : palette.stroke,
          width: highlighted ? 2 : 1,
        ),
      ),
      child: Row(
        spacing: HsSpace.x3,
        children: [
          Expanded(child: dim),
          HsToggle(value: value, onChanged: enabled ? onChanged : null),
        ],
      ),
    );
    if (semanticsLabel == null) return card;
    return Semantics(
      enabled: false,
      label: semanticsLabel,
      excludeSemantics: true,
      child: card,
    );
  }
}

/// A square tile split in two: the same surface with and without the tint.
class _SplitSwatch extends StatelessWidget {
  const new({required this.left, required this.right});

  final Color left;
  final Color right;

  @override
  Widget build(BuildContext context) => Container(
    width: _OptionCard.swatch,
    height: _OptionCard.swatch,
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(_OptionCard.swatchRadius),
      border: Border.all(color: context.hs.stroke),
    ),
    child: Row(
      children: [
        Expanded(child: ColoredBox(color: left)),
        Expanded(child: ColoredBox(color: right)),
      ],
    ),
  );
}

/// The theme as a reader will meet it: a source label, a headline, a line
/// of copy and the two buttons. The buttons do nothing.
class _Preview extends StatelessWidget {
  const new();

  /// A fixed sample accent, so the label shows the per-source rule under
  /// every family.
  static final _accent = SourceAccent.fromKey('headshorts.sample');

  @override
  Widget build(BuildContext context) {
    final palette = context.hs;
    return Padding(
      padding: const EdgeInsets.all(HsSpace.x4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SAMPLE SOURCE',
            style: HsType.sourceLabel.copyWith(
              color: _accent.resolve(isDark: palette.isDark),
            ),
          ),
          const SizedBox(height: HsSpace.x1),
          Text(
            'The news, and then it ends.',
            style: HsType.headline.copyWith(color: palette.textPrimary),
          ),
          const SizedBox(height: HsSpace.x1),
          Text(
            'A calm, finite briefing from the feeds you choose.',
            style: HsType.rowValue.copyWith(color: palette.textSecondary),
          ),
          const SizedBox(height: HsSpace.x4),
          Wrap(
            spacing: HsSpace.x2,
            runSpacing: HsSpace.x2,
            children: [
              HsButton(
                'Primary',
                height: HsSize.buttonCompact,
                onPressed: () {},
              ),
              HsButton(
                'Outlined',
                kind: HsButtonKind.secondary,
                height: HsSize.buttonCompact,
                onPressed: () {},
              ),
            ],
          ),
        ],
      ),
    );
  }
}
