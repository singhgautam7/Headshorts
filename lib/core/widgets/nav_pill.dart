import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/widgets.dart';
import 'package:headshorts/core/motion/animated_weight.dart';
import 'package:headshorts/core/motion/haptics.dart';
import 'package:headshorts/core/motion/motion_level.dart';
import 'package:headshorts/core/motion/pressable.dart';
import 'package:headshorts/core/motion/spring_curve.dart';
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

  /// Space between items.
  static const _gap = 2.0;

  /// Padding either side of the selected item's icon and label.
  static const _padStart = 13.0;
  static const _padEnd = 16.0;

  final List<NavDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  /// Opaque-first. Blur is a setting, off by default, because it costs
  /// battery and buys nothing on a true-black ground.
  final bool blur;

  /// Width of a destination while selected: icon, label, and the padding.
  static double _selectedWidth(BuildContext context, NavDestination d) {
    final tp = TextPainter(
      text: TextSpan(
        text: d.label,
        style: HsMotion.weightStyle(HsType.buttonSmall, _activeWeight),
      ),
      maxLines: 1,
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final w = tp.width;
    tp.dispose();
    return _padStart + d.iconWidth + HsSpace.x2 + w + _padEnd;
  }

  /// The label's heavier weight, which [AnimatedWeight] also defaults to.
  static const _activeWeight = 700.0;

  @override
  Widget build(BuildContext context) {
    // The indicator's rest position: items before the selected one are 44
    // wide, so its left edge is a multiple of one step.
    final left = selectedIndex * (HsSize.navItem + _gap);
    final right = left + _selectedWidth(context, destinations[selectedIndex]);
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: HsSize.navPillPadding),
      child: SizedBox(
        height: HsSize.navPillHeight,
        child: Stack(
          children: [
            // One painter driven by two spring values: the items above never
            // repaint it, and it moves by paint, not layout.
            Positioned.fill(
              child: _NavIndicator(
                left: left,
                right: right,
                color: context.hs.primaryContainer,
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < destinations.length; i++) ...[
                  if (i > 0) const SizedBox(width: _gap),
                  // Only the selected item takes free space: flex 1 for it,
                  // flex 0 for the other four, which are 44 square and must
                  // stay that way. Making all five flexible splits the free
                  // space five ways and clips the one label to a third of
                  // itself. The wrapper is always there, never swapped in
                  // and out, so the label's morph animates rather than snaps.
                  Flexible(
                    flex: i == selectedIndex ? 1 : 0,
                    child: _NavItem(
                      destination: destinations[i],
                      selected: i == selectedIndex,
                      onTap: () {
                        // A tick for a change only; tapping the tab you are
                        // on scrolls it to the top and stays silent.
                        if (i != selectedIndex) HsHaptics.tick();
                        onSelected(i);
                      },
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );

    // One layer: the morph repaints inside it, nothing outside does.
    return NavPillSurface(
      blur: blur,
      child: RepaintBoundary(child: content),
    );
  }
}

/// The selected item's fill: one shape that slides under the items, its
/// leading edge on a quick spring and its trailing edge on a slower one, so it
/// stretches on the way. Subtle: both on the critically damped spring. Off:
/// it is simply there.
class _NavIndicator extends StatefulWidget {
  const new({required this.left, required this.right, required this.color});

  final double left;
  final double right;
  final Color color;

  @override
  State<_NavIndicator> createState() => _NavIndicatorState();
}

class _NavIndicatorState extends State<_NavIndicator>
    with TickerProviderStateMixin {
  late final AnimationController _l = AnimationController.unbounded(
    vsync: this,
    value: widget.left,
  );
  late final AnimationController _r = AnimationController.unbounded(
    vsync: this,
    value: widget.right,
  );

  @override
  void didUpdateWidget(_NavIndicator old) {
    super.didUpdateWidget(old);
    if (old.left == widget.left && old.right == widget.right) return;
    final level = HsMotion.levelOf(context);
    if (level == MotionLevel.off) {
      _l.value = widget.left;
      _r.value = widget.right;
      return;
    }
    final movingRight = widget.left > old.left;
    final fast = HsMotion.spatial(level, HsMotion.springFast);
    final slow = HsMotion.spatial(level, HsMotion.springDefault);
    unawaited(_l.springTo(widget.left, movingRight ? slow : fast));
    unawaited(_r.springTo(widget.right, movingRight ? fast : slow));
  }

  @override
  void dispose() {
    _l.dispose();
    _r.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: CustomPaint(painter: _IndicatorPainter(_l, _r, widget.color)),
  );
}

class _IndicatorPainter extends CustomPainter {
  new(this.l, this.r, this.color) : super(repaint: Listenable.merge([l, r]));

  final ValueListenable<double> l;
  final ValueListenable<double> r;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final left = l.value;
    final right = r.value;
    if (right <= left) return;
    final top = (size.height - HsSize.navItem) / 2;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(left, top, right, top + HsSize.navItem),
        const Radius.circular(HsSize.navItem / 2),
      ),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_IndicatorPainter o) =>
      o.color != color || o.l != l || o.r != r;
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
    final level = HsMotion.levelOf(context);
    final spring = HsMotion.spatialCurve(level, HsMotion.defaultCurve).clamped;

    return Semantics(
      button: true,
      selected: selected,
      label: destination.label,
      child: Pressable(
        kind: PressKind.chip,
        morphCorners: false,
        onTap: onTap,
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: selected ? 1 : 0),
          duration: level == MotionLevel.off ? Duration.zero : spring.settle,
          curve: spring,
          builder: (context, t, _) {
            // Padding, label width, label opacity and icon colour all follow
            // one value, so icon and label change together. Clamped: a width
            // never goes negative or past its target.
            final closedPad = (HsSize.navItem - destination.iconWidth) / 2;
            return Container(
              height: HsSize.navItem,
              padding: EdgeInsets.only(
                left: closedPad + (NavPill._padStart - closedPad) * t,
                right: closedPad + (NavPill._padEnd - closedPad) * t,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  destination.icon(
                    Oklab.mix(palette.onPrimaryContainer, palette.textMuted, t),
                  ),
                  // The label exists only while it is at least partly
                  // visible: an inactive destination is a glyph, full stop.
                  if (t > 0.001)
                    Flexible(
                      child: ClipRect(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          widthFactor: t,
                          child: Opacity(
                            opacity: t,
                            child: Padding(
                              padding: const EdgeInsets.only(left: HsSpace.x2),
                              // The Semantics above already says it.
                              child: ExcludeSemantics(
                                child: AnimatedWeight(
                                  destination.label,
                                  isActive: selected,
                                  style: HsType.buttonSmall.copyWith(
                                    color: palette.onPrimaryContainer,
                                  ),
                                  overflow: TextOverflow.clip,
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
