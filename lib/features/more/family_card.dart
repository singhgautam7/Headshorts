import 'package:flutter/material.dart';
import 'package:headshorts/core/motion/pressable.dart';
import 'package:headshorts/core/theme/hs_theme.dart';
import 'package:headshorts/core/tokens/dimensions.dart';
import 'package:headshorts/core/tokens/motion.dart';
import 'package:headshorts/core/tokens/palette.dart';
import 'package:headshorts/core/tokens/theme_family.dart';
import 'package:headshorts/core/tokens/typography.dart';

/// One theme family as a card: three dots, the name, the blurb (Kuber's
/// family card). [palette] is the family as it would look under the current
/// switches; the card itself is dressed in the theme in force.
///
/// Selected is a 2 dp primary border where the rest have a 1 dp stroke. The
/// padding gives back what the border takes, so the content never shifts.
class FamilyCard extends StatelessWidget {
  const new({
    required this.family,
    required this.palette,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final ThemeFamily family;
  final HsPalette palette;
  final bool selected;
  final VoidCallback onTap;

  static const _minHeight = 116.0;
  static const _inset = 15.0;
  static const _dot = 34.0;
  static const _dotGap = 6.0;
  static const _borderRest = 1.0;
  static const _borderSelected = 2.0;

  @override
  Widget build(BuildContext context) {
    final current = context.hs;
    final border = selected ? _borderSelected : _borderRest;
    return Pressable(
      onTap: onTap,
      haptic: true,
      selected: selected,
      semanticLabel: '${family.name} theme',
      child: ExcludeSemantics(
        child: AnimatedContainer(
          duration: HsMotion.of(context, HsMotion.micro),
          curve: HsMotion.microCurve,
          padding: EdgeInsets.all(_inset - border),
          constraints: const BoxConstraints(minHeight: _minHeight),
          decoration: BoxDecoration(
            color: current.surface,
            borderRadius: HsRadius.cardBorder,
            border: Border.all(
              color: selected ? current.primary : current.stroke,
              width: border,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                spacing: _dotGap,
                children: [
                  ThemeDot(palette.primary),
                  ThemeDot(palette.primaryContainer),
                  ThemeDot(palette.surfaceVariant, border: current.stroke),
                ],
              ),
              const SizedBox(height: HsSpace.x3),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    family.name,
                    style: HsMotion.weightStyle(
                      HsType.row,
                      600,
                    ).copyWith(color: current.textPrimary),
                  ),
                  Text(
                    family.blurb,
                    style: HsType.rowSub.copyWith(color: current.textSecondary),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A round swatch.
class ThemeDot extends StatelessWidget {
  const new(this.color, {this.size = FamilyCard._dot, this.border, super.key});

  final Color color;
  final double size;
  final Color? border;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: color,
      shape: BoxShape.circle,
      border: border == null ? null : Border.all(color: border!),
    ),
  );
}

/// Two columns whose rows are as tall as their taller card.
class TwoColumnGrid extends StatelessWidget {
  const new({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(
    spacing: HsSpace.x3,
    children: [
      for (var i = 0; i < children.length; i += 2)
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: HsSpace.x3,
            children: [
              Expanded(child: children[i]),
              Expanded(
                child: i + 1 < children.length
                    ? children[i + 1]
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
    ],
  );
}
