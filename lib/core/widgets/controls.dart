import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart' show Material;
import 'package:flutter/widgets.dart';
import 'package:headshorts/core/motion/animated_weight.dart';
import 'package:headshorts/core/motion/motion_level.dart';
import 'package:headshorts/core/motion/pressable.dart';
import 'package:headshorts/core/motion/shape_loader.dart';
import 'package:headshorts/core/theme/hs_theme.dart';
import 'package:headshorts/core/tokens/accents.dart';
import 'package:headshorts/core/tokens/dimensions.dart';
import 'package:headshorts/core/tokens/motion.dart';
import 'package:headshorts/core/tokens/oklab.dart';
import 'package:headshorts/core/tokens/palette.dart';
import 'package:headshorts/core/tokens/typography.dart';
import 'package:headshorts/core/util/language.dart';
import 'package:headshorts/core/widgets/glyphs.dart';

export 'package:headshorts/core/motion/pressable.dart';

export 'app_icon_button.dart';
export 'menu.dart';

enum HsButtonKind {
  /// Ink on the primary fill.
  primary,

  /// The source accent as a fill — Linger only.
  accent,

  /// A hairline outline.
  secondary,

  /// Label only, no container.
  tertiary,
}

/// The button set from the component sheet. Height is the only variant beyond
/// [HsButtonKind]; everything else follows from the tokens.
///
/// A pill at rest; while held it relaxes to a 12 dp squircle (8 dp under 48
/// tall) on a spring, at Expressive only. [height] is a minimum, so a large
/// system font grows the button rather than clipping its label.
class HsButton extends StatelessWidget {
  const new(
    this.label, {
    required this.onPressed,
    this.kind = HsButtonKind.primary,
    this.height = HsSize.buttonLarge,
    this.loading = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final HsButtonKind kind;
  final double height;

  /// Swaps the label for the shape loader and ignores taps. The label stays
  /// in the layout, hidden, so the button keeps its width; it keeps its own
  /// fill rather than the disabled dress, because it is busy, not unusable.
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final palette = context.hs;
    final disabled = onPressed == null && !loading;
    final accent = AccentScope.of(context).resolve(isDark: palette.isDark);

    final (Color? fill, Color text, BorderSide? side) = switch (kind) {
      _ when disabled => (
        null,
        palette.textMuted,
        BorderSide(color: palette.divider),
      ),
      HsButtonKind.primary => (palette.primary, palette.onPrimary, null),
      // Accents sit in one lightness band per brightness, so the page
      // ground is the ink that reads on them whatever the family.
      HsButtonKind.accent => (accent, palette.lingerBackground, null),
      HsButtonKind.secondary => (
        null,
        palette.textPrimary,
        BorderSide(color: palette.stroke),
      ),
      HsButtonKind.tertiary => (null, palette.textSecondary, null),
    };

    final style = height >= HsSize.buttonMedium
        ? HsType.buttonLarge
        : HsType.buttonMedium;
    final off = HsMotion.levelOf(context) == MotionLevel.off;
    // A fill that is absent is the label colour at no alpha, never
    // `Colors.transparent`, so a fill never tweens through a grey.
    final fillTarget = fill ?? text.withValues(alpha: 0);

    return Pressable(
      kind: PressKind.button,
      enabled: !disabled && !loading,
      onTap: loading ? null : onPressed,
      semanticLabel: loading ? 'Loading' : label,
      restRadius: height / 2,
      pressedRadius: height >= HsSize.buttonMedium
          ? HsRadius.squircle
          : HsRadius.heldCompact,
      builder: (context, radius, pressed) {
        final shape = RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        );
        return TweenAnimationBuilder<Color?>(
          tween: ColorTween(end: fillTarget),
          duration: off ? HsMotion.fxInstant : HsMotion.fxFast,
          curve: HsMotion.curveEffects,
          builder: (context, color, child) => Container(
            constraints: BoxConstraints(minHeight: height),
            padding: const EdgeInsets.symmetric(
              horizontal: HsSpace.x4,
              vertical: HsSpace.x2,
            ),
            decoration: ShapeDecoration(
              color: color,
              shape: side == null ? shape : shape.copyWith(side: side),
            ),
            // The 10% state layer, ink over whatever the fill is.
            foregroundDecoration: ShapeDecoration(
              color: text.withValues(alpha: 0.1 * pressed.clamp(0.0, 1.0)),
              shape: shape,
            ),
            child: child,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  Opacity(
                    opacity: loading ? 0 : 1,
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style:
                          (height <= HsSize.buttonCompact
                                  ? HsType.buttonSmall
                                  : style)
                              .copyWith(color: text),
                    ),
                  ),
                  if (loading)
                    ExcludeSemantics(
                      child: ShapeLoader(
                        size: HsSize.buttonLoader,
                        color: text,
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

/// The M3 switch. Accent track with a check in the knob when on; when off a
/// visible outline and a smaller, mid-tone knob (it must not read as
/// disabled). The knob rides on springFast. The whole control is a 48 dp
/// target around the 44 x 26 track.
class HsToggle extends StatelessWidget {
  const new({required this.value, required this.onChanged, super.key});

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.hs;
    final level = HsMotion.levelOf(context);
    final curve = HsMotion.spatialCurve(level, HsMotion.fastCurve);
    final enabled = onChanged != null;
    const slot = HsSize.toggleKnob;

    return Semantics(
      toggled: value,
      enabled: enabled,
      child: Pressable(
        kind: PressKind.chip,
        haptic: true,
        enabled: enabled,
        onTap: enabled ? () => onChanged!(!value) : null,
        child: SizedBox(
          width: HsSize.tapTarget,
          height: HsSize.tapTarget,
          child: Center(
            child: Opacity(
              opacity: enabled ? 1 : 0.38,
              child: TweenAnimationBuilder<double>(
                tween: Tween(end: value ? 1 : 0),
                duration: level == MotionLevel.off
                    ? HsMotion.fxInstant
                    : curve.settle,
                curve: level == MotionLevel.off ? HsMotion.curveEffects : curve,
                builder: (context, k, _) {
                  final c = k.clamp(0.0, 1.0);
                  return Container(
                    width: HsSize.toggleWidth,
                    height: HsSize.toggleHeight,
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: palette.primary.withValues(alpha: c),
                      border: Border.all(
                        color: Color.lerp(
                          palette.textMuted,
                          palette.primary,
                          c,
                        )!,
                        width: 2,
                      ),
                      borderRadius: HsRadius.pillBorder,
                    ),
                    child: Align(
                      alignment: Alignment(-1 + 2 * k, 0),
                      child: SizedBox(
                        width: slot,
                        height: slot,
                        child: Center(
                          child: Container(
                            width: lerpDouble(HsSize.toggleKnobOff, slot, c),
                            height: lerpDouble(HsSize.toggleKnobOff, slot, c),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color.lerp(
                                palette.textMuted,
                                palette.onPrimary,
                                c,
                              ),
                            ),
                            child: Opacity(
                              opacity: c,
                              child: HsGlyph.tick(palette.primary),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The square checkbox used by OPML import. The fill and the tick spring in.
class HsCheckbox extends StatelessWidget {
  const new({required this.value, required this.onChanged, super.key});

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.hs;
    final level = HsMotion.levelOf(context);
    final curve = HsMotion.spatialCurve(level, HsMotion.fastCurve);
    final enabled = onChanged != null;
    return Semantics(
      checked: value,
      enabled: enabled,
      child: Pressable(
        kind: PressKind.chip,
        haptic: true,
        enabled: enabled,
        onTap: enabled ? () => onChanged!(!value) : null,
        child: SizedBox(
          width: HsSize.tapTarget,
          height: HsSize.tapTarget,
          child: Center(
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: value ? 1 : 0),
              duration: level == MotionLevel.off
                  ? HsMotion.fxInstant
                  : curve.settle,
              curve: level == MotionLevel.off ? HsMotion.curveEffects : curve,
              builder: (context, k, _) {
                final c = k.clamp(0.0, 1.0);
                return Container(
                  width: HsSize.checkbox,
                  height: HsSize.checkbox,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: palette.primary.withValues(alpha: c),
                    border: Border.all(
                      color: Color.lerp(palette.stroke, palette.primary, c)!,
                      width: HsSize.glyphStroke,
                    ),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Transform.scale(
                    scale: k.clamp(0.0, 1.3),
                    child: Opacity(
                      opacity: c,
                      child: HsGlyph.tick(palette.onPrimary),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// A category chip. Unselected is an outlined stadium; selected is a 12 dp
/// squircle in the selected container fill, as Kuber's filter chips are. A source chip carries the
/// source accent as a wash with a dot, never as a saturated fill.
///
/// The visual is 32 dp tall inside a 48 dp hit region, so a `Wrap` of chips
/// should take its `runSpacing` from [runSpacing].
class HsChip extends StatelessWidget {
  const new(
    this.label, {
    this.selected = false,
    this.onTap,
    this.accentDot = false,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final bool accentDot;

  /// A `Wrap.runSpacing` that leaves [gap] between the chips' visuals: the
  /// 48 dp hit region already carries 8 dp above and below each.
  static double runSpacing(double gap) => gap - 16;

  @override
  Widget build(BuildContext context) {
    final palette = context.hs;
    final accent = AccentScope.of(context).resolve(isDark: palette.isDark);
    final level = HsMotion.levelOf(context);
    final off = level == MotionLevel.off;
    final shape = HsMotion.spatialCurve(level, HsMotion.fastCurve);
    final active = selected || accentDot;
    final fillTarget = accentDot
        ? accentWash(accent, palette)
        : palette.primaryContainer.withValues(alpha: selected ? 1 : 0);
    final labelStyle = HsType.chipSelected.copyWith(
      color: accentDot ? accent : palette.onPrimaryContainer,
    );

    return Pressable(
      kind: PressKind.chip,
      morphCorners: false,
      haptic: true,
      enabled: onTap != null,
      onTap: onTap,
      selected: selected,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: HsSize.tapTarget),
        child: Align(
          widthFactor: 1,
          heightFactor: 1,
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: active ? 1 : 0),
            duration: off ? Duration.zero : shape.settle,
            curve: shape.clamped,
            builder: (context, sq, child) => TweenAnimationBuilder<Color?>(
              tween: ColorTween(end: fillTarget),
              duration: off ? HsMotion.fxInstant : HsMotion.fxFast,
              curve: HsMotion.curveEffects,
              builder: (context, fill, child) => Material(
                color: fill,
                animationDuration: Duration.zero,
                shape: _chipShape(sq, palette.stroke, hasOutline: !active),
                child: child,
              ),
              child: child,
            ),
            child: Container(
              constraints: const BoxConstraints(minHeight: HsSize.chipVisual),
              padding: const EdgeInsets.symmetric(horizontal: HsSpace.x4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (accentDot) ...[
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: accent,
                      ),
                    ),
                    const SizedBox(width: 7),
                  ],
                  Flexible(
                    child: AnimatedWeight(
                      label,
                      isActive: active,
                      active: 650,
                      style: labelStyle,
                      restColor: accentDot ? null : palette.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Stadium at 0, 12 dp squircle at 1; the outline goes with the stadium.
ShapeBorder _chipShape(double t, Color stroke, {required bool hasOutline}) {
  final side = hasOutline ? BorderSide(color: stroke) : BorderSide.none;
  const squircle = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(HsRadius.squircle)),
  );
  if (t >= 1) return squircle;
  if (t <= 0) return StadiumBorder(side: side);
  return ShapeBorder.lerp(StadiumBorder(side: side), squircle, t)!;
}

/// The accent wash: 15% over black, 7% over paper. Restrained by design — it
/// tints a ground, it never becomes one.
///
/// Mixed in oklab, as the design board writes it. In sRGB the same 15% comes
/// out about three times brighter on black, which is the difference between a
/// whisper of hue and a coloured card.
///
/// [on] is the surface under it when that is not the page.
Color accentWash(Color accent, HsPalette palette, {Color? on}) =>
    Oklab.mix(accent, on ?? palette.background, palette.isDark ? 0.15 : 0.07);

/// A hairline rule at divider strength.
class HsDivider extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) =>
      Container(height: HsSize.hairline, color: context.hs.divider);
}

/// The uppercase group label above a list section.
class SectionLabel extends StatelessWidget {
  const new(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: HsType.sectionLabel.copyWith(color: context.hs.textMuted),
  );
}

/// A footer that fades into the page behind it rather than cutting the
/// content off with a hard edge.
class FadingFooter extends StatelessWidget {
  const new({required this.child, this.stop = 0.62, super.key});

  final Widget child;

  /// Where the ground reaches full opacity, measured from the bottom.
  final double stop;

  @override
  Widget build(BuildContext context) {
    final ground = context.hs.background;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [ground, ground, ground.withValues(alpha: 0)],
          stops: [0, stop, 1],
        ),
      ),
      child: child,
    );
  }
}

/// The language filter: "All" and one chip per language, naming itself in its
/// own script.
///
/// A scrolling row rather than a segmented control. The board draws three
/// segments because that reader follows two languages; the **catalog** offers
/// eight, and eight equal-width segments wrap every label into a broken
/// stack. A row that scrolls holds any number and keeps each name whole.
///
/// It shows nothing at all when there is one language: a filter with a single
/// option is furniture.
class LanguageChips extends StatelessWidget {
  const new({
    required this.languages,
    required this.value,
    required this.onChanged,
    super.key,
  });

  final List<String> languages;

  /// Null is "all of them".
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    if (languages.length < 2) return const SizedBox.shrink();

    return SizedBox(
      height: HsSize.tapTarget,
      child: Semantics(
        label: 'Language',
        container: true,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            HsChip(
              'All',
              selected: value == null,
              onTap: () => onChanged(null),
            ),
            for (final tag in languages) ...[
              const SizedBox(width: HsSpace.x1),
              Semantics(
                label: HsLanguage.of(tag).englishName,
                child: HsChip(
                  HsLanguage.of(tag).endonym,
                  selected: value == tag,
                  onTap: () => onChanged(tag),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
