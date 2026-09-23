import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:headshorts/core/theme/hs_theme.dart';
import 'package:headshorts/core/tokens/accents.dart';
import 'package:headshorts/core/tokens/dimensions.dart';
import 'package:headshorts/core/tokens/motion.dart';
import 'package:headshorts/core/tokens/oklab.dart';
import 'package:headshorts/core/tokens/palette.dart';
import 'package:headshorts/core/tokens/typography.dart';
import 'package:headshorts/core/util/language.dart';
import 'package:headshorts/core/widgets/glyphs.dart';

export 'app_icon_button.dart';
export 'menu.dart';

/// A press state that dips opacity on motion-micro. The only feedback any
/// tappable surface in the app gives.
class Pressable extends StatefulWidget {
  const new({
    required this.child,
    this.onTap,
    this.onLongPress,
    this.semanticLabel,
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final String? semanticLabel;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null || widget.onLongPress != null;
    return Semantics(
      button: enabled,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        onTapDown: enabled ? (_) => setState(() => _down = true) : null,
        onTapUp: enabled ? (_) => setState(() => _down = false) : null,
        onTapCancel: enabled ? () => setState(() => _down = false) : null,
        child: AnimatedOpacity(
          opacity: _down ? 0.62 : 1,
          duration: HsMotion.micro,
          curve: HsMotion.microCurve,
          child: widget.child,
        ),
      ),
    );
  }
}

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
class HsButton extends StatelessWidget {
  const new(
    this.label, {
    required this.onPressed,
    this.kind = HsButtonKind.primary,
    this.height = HsSize.buttonLarge,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final HsButtonKind kind;
  final double height;

  @override
  Widget build(BuildContext context) {
    final palette = context.hs;
    final disabled = onPressed == null;
    final accent = AccentScope.of(context).resolve(isDark: palette.isDark);

    final (Color? fill, Color text, Border? border) = switch (kind) {
      _ when disabled => (
        null,
        palette.textMuted,
        Border.fromBorderSide(BorderSide(color: palette.divider)),
      ),
      HsButtonKind.primary => (palette.primary, palette.onPrimary, null),
      HsButtonKind.accent => (accent, palette.onPrimary, null),
      HsButtonKind.secondary => (
        null,
        palette.textPrimary,
        Border.fromBorderSide(BorderSide(color: palette.stroke)),
      ),
      HsButtonKind.tertiary => (null, palette.textSecondary, null),
    };

    final style = height >= HsSize.buttonMedium
        ? HsType.buttonLarge
        : HsType.buttonMedium;

    return Pressable(
      onTap: onPressed,
      semanticLabel: label,
      child: Container(
        height: height,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: fill,
          border: border,
          borderRadius: HsRadius.buttonBorder,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: (height <= HsSize.buttonCompact ? HsType.buttonSmall : style)
              .copyWith(color: text),
        ),
      ),
    );
  }
}

/// The pill toggle used on every source row and setting.
class HsToggle extends StatelessWidget {
  const new({required this.value, required this.onChanged, super.key});

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.hs;
    return Semantics(
      toggled: value,
      child: Pressable(
        onTap: onChanged == null ? null : () => onChanged!(!value),
        child: AnimatedContainer(
          duration: HsMotion.micro,
          curve: HsMotion.microCurve,
          width: HsSize.toggleWidth,
          height: HsSize.toggleHeight,
          padding: const EdgeInsets.symmetric(horizontal: 3),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          decoration: BoxDecoration(
            color: value ? palette.primary : null,
            border: value ? null : Border.all(color: palette.stroke),
            borderRadius: HsRadius.pillBorder,
          ),
          child: Container(
            width: HsSize.toggleKnob,
            height: HsSize.toggleKnob,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: value
                  ? palette.onPrimary
                  : (palette.isDark ? palette.surfaceVariant : palette.surface),
            ),
          ),
        ),
      ),
    );
  }
}

/// The square checkbox used by OPML import.
class HsCheckbox extends StatelessWidget {
  const new({required this.value, required this.onChanged, super.key});

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.hs;
    return Semantics(
      checked: value,
      child: Pressable(
        onTap: onChanged == null ? null : () => onChanged!(!value),
        child: Container(
          width: HsSize.checkbox,
          height: HsSize.checkbox,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: value ? palette.primary : null,
            border: value
                ? null
                : Border.all(color: palette.stroke, width: HsSize.glyphStroke),
            borderRadius: BorderRadius.circular(5),
          ),
          child: value ? HsGlyph.tick(palette.onPrimary) : null,
        ),
      ),
    );
  }
}

/// A category chip. Selected chips fill with ink; a source chip carries the
/// source accent as a wash with a dot, never as a saturated fill.
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

  @override
  Widget build(BuildContext context) {
    final palette = context.hs;
    final accent = AccentScope.of(context).resolve(isDark: palette.isDark);

    return Pressable(
      onTap: onTap == null
          ? null
          : () {
              unawaited(HapticFeedback.selectionClick());
              onTap!();
            },
      child: AnimatedContainer(
        duration: HsMotion.micro,
        curve: HsMotion.microCurve,
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: accentDot
              ? accentWash(accent, palette)
              : (selected ? palette.primary : null),
          border: (selected || accentDot)
              ? null
              : Border.all(color: palette.stroke),
          borderRadius: HsRadius.chipBorder,
        ),
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
            Text(
              label,
              style: (selected || accentDot ? HsType.chipSelected : HsType.chip)
                  .copyWith(
                    color: accentDot
                        ? accent
                        : (selected
                              ? palette.onPrimary
                              : palette.textSecondary),
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The accent wash: 15% over black, 7% over paper. Restrained by design — it
/// tints a ground, it never becomes one.
///
/// Mixed in oklab, as the design board writes it. In sRGB the same 15% comes
/// out about three times brighter on black, which is the difference between a
/// whisper of hue and a coloured card.
Color accentWash(Color accent, HsPalette palette) =>
    Oklab.mix(accent, palette.background, palette.isDark ? 0.15 : 0.07);

/// The softer wash, used where two accented surfaces sit next to each other.
Color accentWashSoft(Color accent, HsPalette palette) =>
    Oklab.mix(accent, palette.background, palette.isDark ? 0.08 : 0.04);

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
      height: 36,
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
              const SizedBox(width: HsSpace.x2),
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
