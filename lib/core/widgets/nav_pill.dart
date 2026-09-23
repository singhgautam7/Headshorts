import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:headshorts/core/theme/hs_theme.dart';
import 'package:headshorts/core/tokens/dimensions.dart';
import 'package:headshorts/core/tokens/motion.dart';
import 'package:headshorts/core/tokens/oklab.dart';
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
/// It does not span the screen or divide into equal segments: it hugs its five
/// items, centred, [HsSize.navPillInset] from the bottom, so it reads as an
/// object floating over content rather than a footer. Only the selected
/// destination carries text. There is no action button, and never a badge.
///
/// Five destinations is the widest the pill is designed to go: four inactive
/// 44s, the active item, four 2dp gaps and a 7dp inset come to about 316 on
/// the longest label, inside a 360 screen with room each side.
class NavPill extends StatelessWidget {
  const new({
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
    this.blur = false,
    super.key,
  });

  static const destinationsForApp = [
    NavDestination(label: 'Headlines', icon: HsGlyph.today, iconWidth: 16),
    NavDestination(label: 'Linger', icon: HsGlyph.linger, iconWidth: 13),
    NavDestination(label: 'Sources', icon: HsGlyph.sources, iconWidth: 16),
    NavDestination(label: 'Search', icon: HsGlyph.search, iconWidth: 16),
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
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: HsSize.navPillPadding),
      child: SizedBox(
        height: HsSize.navPillHeight,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < destinations.length; i++) ...[
              if (i > 0) const SizedBox(width: 2),
              // Only the selected item takes free space: flex 1 for it,
              // flex 0 — laid out rigid, exactly like a bare child — for the
              // other four, which are 44 square and must stay that way.
              // Making all five flexible splits the free space five ways and
              // clips the one label to a third of itself.
              //
              // The wrapper is always there, never swapped in and out: a
              // child that changes shape between builds loses its element,
              // and the label's morph would snap rather than animate.
              //
              // Loose, so on any real phone the label takes the room it
              // needs, and at a large font scale it gives way rather than
              // pushing the pill off the screen — the board's note, with
              // TalkBack keeping the full name either way.
              Flexible(
                flex: i == selectedIndex ? 1 : 0,
                child: _NavItem(
                  destination: destinations[i],
                  selected: i == selectedIndex,
                  onTap: () {
                    unawaited(HapticFeedback.selectionClick());
                    onSelected(i);
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );

    return NavPillSurface(blur: blur, child: content);
  }
}

/// The pill's dress, on its own so the Reader's floating actions can wear it:
/// the nav tone, a hairline, the one soft shadow, and the optional blur.
class NavPillSurface extends StatelessWidget {
  const new({required this.child, this.blur = false, super.key});

  final Widget child;
  final bool blur;

  @override
  Widget build(BuildContext context) {
    final palette = context.hs;
    final inner = blur
        ? ClipRRect(
            borderRadius: HsRadius.pillBorder,
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: palette.nav.withValues(alpha: 0.86),
                  borderRadius: HsRadius.pillBorder,
                  border: Border.all(color: palette.stroke),
                ),
                child: child,
              ),
            ),
          )
        : DecoratedBox(
            decoration: BoxDecoration(
              color: palette.nav,
              borderRadius: HsRadius.pillBorder,
              border: Border.all(color: palette.stroke),
            ),
            child: child,
          );

    return Padding(
      padding: const EdgeInsets.only(bottom: HsSize.navPillInset),
      child: Semantics(
        container: true,
        explicitChildNodes: true,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: HsRadius.pillBorder,
            boxShadow: [palette.navShadow],
          ),
          child: inner,
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
          duration: HsMotion.of(context, HsMotion.navMorph),
          curve: HsMotion.curveOf(context, HsMotion.navMorphCurve),
          builder: (context, t, _) {
            // The container width and the label opacity animate together; the
            // icon itself never scales or bounces. The spring overshoots, so
            // the width may briefly pass 1; colour and opacity never do.
            final open = t.clamp(0.0, 1.0);
            final width = t.clamp(0.0, 1.2);
            // Closed, the item is exactly 44 square. Open, it carries the
            // specified 13/16 padding around icon and label.
            final closedPad = (HsSize.navItem - destination.iconWidth) / 2;
            return Container(
              height: HsSize.navItem,
              padding: EdgeInsets.only(
                left: closedPad + (13 - closedPad) * width,
                right: closedPad + (16 - closedPad) * width,
              ),
              decoration: BoxDecoration(
                color: Oklab.mix(palette.primaryContainer, palette.nav, open),
                borderRadius: HsRadius.pillBorder,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  destination.icon(
                    Oklab.mix(
                      palette.onPrimaryContainer,
                      palette.textMuted,
                      open,
                    ),
                  ),
                  // The label exists only while it is at least partly
                  // visible: an inactive destination is a glyph, full stop.
                  if (open > 0)
                    Flexible(
                      child: ClipRect(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          widthFactor: width,
                          child: Opacity(
                            opacity: open,
                            child: Padding(
                              padding: const EdgeInsets.only(left: HsSpace.x2),
                              child: Text(
                                destination.label,
                                maxLines: 1,
                                softWrap: false,
                                overflow: TextOverflow.clip,
                                style: HsType.buttonSmall.copyWith(
                                  color: palette.onPrimaryContainer,
                                ),
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
