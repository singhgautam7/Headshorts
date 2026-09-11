import 'package:flutter/widgets.dart';
import 'package:headshorts/core/theme/hs_theme.dart';
import 'package:headshorts/core/tokens/dimensions.dart';
import 'package:headshorts/core/tokens/motion.dart';
import 'package:headshorts/core/tokens/typography.dart';
import 'package:headshorts/core/widgets/controls.dart';
import 'package:headshorts/core/widgets/glyphs.dart';

/// A root destination: the serif screen title, an optional trailing control,
/// and the body beneath.
class HsScreen extends StatelessWidget {
  const new({
    required this.title,
    required this.child,
    this.trailing,
    this.titlePadding = const EdgeInsets.fromLTRB(
      HsSpace.x5,
      6,
      HsSpace.x5,
      HsSpace.x3,
    ),
    super.key,
  });

  final String title;
  final Widget child;
  final Widget? trailing;
  final EdgeInsets titlePadding;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: context.hs.background,
    child: SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: titlePadding,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: HsType.screenTitle.copyWith(
                      color: context.hs.textPrimary,
                    ),
                  ),
                ),
                ?trailing,
              ],
            ),
          ),
          Expanded(child: child),
        ],
      ),
    ),
  );
}

/// A pushed screen: a back arrow, a sans title, and the body.
class PushedScreen extends StatelessWidget {
  const new({
    required this.title,
    required this.child,
    this.onBack,
    this.trailing,
    this.divider = true,
    this.footer,
    super.key,
  });

  final String title;
  final Widget child;
  final VoidCallback? onBack;
  final Widget? trailing;
  final bool divider;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final palette = context.hs;
    return ColoredBox(
      color: palette.background,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                border: divider
                    ? Border(bottom: BorderSide(color: palette.divider))
                    : null,
              ),
              child: SizedBox(
                height: HsSize.appBarHeight,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Pressable(
                        onTap: onBack ?? () => Navigator.of(context).maybePop(),
                        semanticLabel: 'Back',
                        child: SizedBox(
                          width: HsSize.navItem,
                          height: HsSize.navItem,
                          child: Center(
                            child: HsGlyph.back(palette.textPrimary),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          title,
                          style: HsType.appBarTitle.copyWith(
                            color: palette.textPrimary,
                          ),
                        ),
                      ),
                      ?trailing,
                    ],
                  ),
                ),
              ),
            ),
            Expanded(child: child),
            ?footer,
          ],
        ),
      ),
    );
  }
}

/// The horizontal category sub-tabs above Today's list.
class SubTabs extends StatelessWidget {
  const new({
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
    super.key,
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final palette = context.hs;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: palette.divider)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: HsSpace.x5),
        child: Row(
          children: [
            for (var i = 0; i < labels.length; i++) ...[
              if (i > 0) const SizedBox(width: 22),
              _SubTab(
                label: labels[i],
                selected: i == selectedIndex,
                onTap: () => onSelected(i),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SubTab extends StatelessWidget {
  const new({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.hs;
    return Pressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: HsMotion.tabSlide,
        curve: HsMotion.tabSlideCurve,
        padding: const EdgeInsets.only(bottom: HsSpace.x3),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected ? palette.textPrimary : const Color(0x00000000),
              width: 2,
            ),
          ),
        ),
        child: Text(
          label,
          style: (selected ? HsType.subTabActive : HsType.subTab).copyWith(
            color: selected ? palette.textPrimary : palette.textMuted,
          ),
        ),
      ),
    );
  }
}
