import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:headshorts/app/settings_controller.dart';
import 'package:headshorts/core/motion/haptics.dart';
import 'package:headshorts/core/theme/hs_theme.dart';
import 'package:headshorts/core/tokens/dimensions.dart';
import 'package:headshorts/core/tokens/motion.dart';
import 'package:headshorts/core/tokens/typography.dart';
import 'package:headshorts/core/widgets/controls.dart';
import 'package:headshorts/core/widgets/header_preview.dart';
import 'package:headshorts/data/prefs/settings.dart';
import 'package:headshorts/features/more/settings_widgets.dart';

/// Header: the one on/off switch for the floating header and, under it, when
/// the pill shows. Each of the three choices carries a live [HeaderPreview] of
/// itself, so the choice is made on what it does rather than on its name.
///
/// Applies at once, like every setting here. The previews follow the Motion
/// level and only run while on screen; that is [HeaderPreview]'s job.
class HeaderScreen extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.hs;
    return SettingsScaffold(
      title: 'Header',
      children: [
        const _FloatingRow(),
        Padding(
          padding: const EdgeInsets.only(bottom: HsSpace.x2),
          child: Text(
            'SHOW THE PILL',
            style: HsType.lingerLabel.copyWith(
              fontSize: 11,
              letterSpacing: 1.2,
              color: palette.textMuted,
            ),
          ),
        ),
        for (final mode in PillMode.values) _PillOption(mode: mode),
      ],
    );
  }
}

/// The switch row. The whole row takes the tap, once.
class _FloatingRow extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final on = ref.watch(settingsProvider.select((s) => s.floatingHeader));
    return SettingsGroup(
      label: 'Header',
      children: [
        Semantics(
          toggled: on,
          child: SettingsRow(
            icon: Icons.vertical_align_top_rounded,
            label: 'Floating header',
            sub: on
                ? 'Becomes a pill as you scroll'
                : 'Scrolls away with the page',
            chevron: false,
            trailing: ExcludeSemantics(
              child: IgnorePointer(
                child: HsToggle(value: on, onChanged: (_) {}),
              ),
            ),
            onTap: () {
              HsHaptics.tick();
              unawaited(
                ref
                    .read(settingsProvider.notifier)
                    .setFloatingHeader(enabled: !on),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// One radio card: the choice's name, then its preview. Disabled, and not
/// selected, while the floating header is off, because there is no pill for
/// a mode to describe.
class _PillOption extends ConsumerWidget {
  const new({required this.mode});

  final PillMode mode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.hs;
    final on = ref.watch(settingsProvider.select((s) => s.floatingHeader));
    final chosen = ref.watch(settingsProvider.select((s) => s.pillMode));
    final selected = on && chosen == mode;

    void pick() {
      if (chosen != mode) HsHaptics.tick();
      unawaited(ref.read(settingsProvider.notifier).setPillMode(mode));
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: HsSpace.x2),
      child: Opacity(
        opacity: on ? 1 : 0.38,
        child: Semantics(
          container: true,
          excludeSemantics: true,
          button: true,
          enabled: on,
          selected: selected,
          inMutuallyExclusiveGroup: true,
          label: '${mode.label}, preview',
          onTap: on ? pick : null,
          child: Pressable(
            enabled: on,
            onTap: pick,
            child: AnimatedContainer(
              duration: HsMotion.of(context, HsMotion.micro),
              curve: HsMotion.curveOf(context, HsMotion.microCurve),
              padding: const EdgeInsets.all(HsSpace.x3),
              decoration: BoxDecoration(
                color: selected ? palette.primaryContainer : palette.surface,
                borderRadius: HsRadius.cardBorder,
                border: Border.all(
                  color: selected ? palette.primary : palette.stroke,
                  width: selected ? 1.5 : 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(
                      minHeight: HsSize.tapTarget - HsSpace.x4,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          selected
                              ? Icons.radio_button_checked_rounded
                              : Icons.radio_button_unchecked_rounded,
                          size: 22,
                          color: selected ? palette.primary : palette.textMuted,
                        ),
                        const SizedBox(width: HsSpace.x3),
                        Expanded(
                          child: Text(
                            mode.label,
                            style: HsType.row.copyWith(
                              color: selected
                                  ? palette.onPrimaryContainer
                                  : palette.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: HsSpace.x2),
                  HeaderPreview(floating: on, pill: mode),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
