import 'package:flutter/widgets.dart';
import 'package:headshorts/core/theme/hs_theme.dart';
import 'package:headshorts/core/tokens/dimensions.dart';
import 'package:headshorts/core/tokens/motion.dart';
import 'package:headshorts/core/tokens/typography.dart';
import 'package:headshorts/core/widgets/glyphs.dart';

/// One destination in the pill.
class NavDestination {
  const new({required this.label, required this.icon, required this.iconWidth});

  final String label;
  final Widget Function(Color color) icon;

  /// The glyph's drawn width, so an inactive item is exactly
  /// [HsSize.navItem] square and an active one carries the specified padding.
  final double iconWidth;
}

/// The floating, detached nav pill.
///
/// It does not span the screen or divide into equal segments: it hugs its four
/// items, centred, [HsSize.navPillInset] from the bottom, so it reads as an
/// object floating over content rather than a footer. Only the selected
/// destination carries text. There is no action button, and never a badge.
class NavPill extends StatelessWidget {
  const new({
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
    this.blur = false,
    super.key,
  });

  static const destinationsForApp = [
    NavDestination(label: 'Today', icon: HsGlyph.today, iconWidth: 16),
    NavDestination(label: 'Linger', icon: HsGlyph.linger, iconWidth: 13),
    NavDestination(label: 'Sources', icon: HsGlyph.sources, iconWidth: 16),
    NavDestination(label: 'More', icon: HsGlyph.more, iconWidth: 16),
  ];

  final List<NavDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  /// Opaque-first. Blur is a setting, off by default, because it costs
  /// battery and buys nothing on a true-black ground.
  final bool blur;

  @override
  Widget build(BuildContext context) {
    final palette = context.hs;

    return Padding(
      padding: const EdgeInsets.only(bottom: HsSize.navPillInset),
      child: Semantics(
        container: true,
        explicitChildNodes: true,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: blur ? palette.nav.withValues(alpha: 0.86) : palette.nav,
            borderRadius: HsRadius.pillBorder,
            boxShadow: [palette.navShadow],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: HsSize.navPillPadding,
            ),
            child: SizedBox(
              height: HsSize.navPillHeight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < destinations.length; i++) ...[
                    if (i > 0) const SizedBox(width: 2),
                    _NavItem(
                      destination: destinations[i],
                      selected: i == selectedIndex,
                      onTap: () => onSelected(i),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const new({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final NavDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.hs;

    return Semantics(
      button: true,
      selected: selected,
      label: destination.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: selected ? 1 : 0),
          duration: HsMotion.navMorph,
          curve: HsMotion.navMorphCurve,
          builder: (context, t, _) {
            // The container width and the label opacity animate together; the
            // icon itself never scales or bounces.
            final open = t.clamp(0.0, 1.0);
            // Closed, the item is exactly 44 square. Open, it carries the
            // specified 13/16 padding around icon and label.
            final closedPad = (HsSize.navItem - destination.iconWidth) / 2;
            return Container(
              height: HsSize.navItem,
              padding: EdgeInsets.only(
                left: closedPad + (13 - closedPad) * open,
                right: closedPad + (16 - closedPad) * open,
              ),
              decoration: BoxDecoration(
                color: Color.lerp(palette.nav, palette.navActive, open),
                borderRadius: HsRadius.pillBorder,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  destination.icon(
                    Color.lerp(palette.textMuted, palette.textPrimary, open)!,
                  ),
                  // The label exists only while it is at least partly
                  // visible: an inactive destination is a glyph, full stop.
                  if (open > 0)
                    ClipRect(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        widthFactor: open,
                        child: Opacity(
                          opacity: open,
                          child: Padding(
                            padding: const EdgeInsets.only(left: HsSpace.x2),
                            child: Text(
                              destination.label,
                              maxLines: 1,
                              softWrap: false,
                              style: HsType.buttonSmall.copyWith(
                                color: palette.textPrimary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
